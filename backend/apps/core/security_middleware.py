"""
RSS SOC Security Middleware v5 — Distributable + Blocking
==========================================================
Detects, BLOCKS and logs security attacks in any Django app.
Blocked requests never reach your views. Logs go to the RSS Bank central SOC.

QUICK INSTALL (2 minutes):
  1. Copy this file to your app:  apps/core/security_middleware.py
  2. Add to settings.py MIDDLEWARE as the FIRST entry:
       'apps.core.security_middleware.SecurityMiddleware'
  3. Set in your .env (only RSS_SOC_APP_NAME is required):

       RSS_SOC_APP_NAME=your-app-name      # unique name — shows in Grafana
       RSS_SOC_URL=http://198.199.70.48:3100
       RSS_SOC_TOKEN=rssbank-token-2024
       RSS_SOC_ENV=production
       RSS_SOC_LOCAL_LOGS=/app/logs
       RSS_SOC_BLOCK_ATTACKS=true          # false = log only (no block)
       RSS_SOC_BAN_DURATION=3600           # seconds an IP stays banned (default 1h)
       RSS_SOC_EMAIL_ALERTS=false          # keep false — SOC Grafana handles alerts

How blocking works (no Suricata needed):
  - SQL_INJECTION / XSS / PATH_TRAVERSAL → HTTP 403 before the view runs
  - BRUTE_FORCE (5+ failed logins in 5 min) → IP banned in memory → HTTP 429
  - Banned IPs are blocked on every subsequent request until ban expires
"""
import json
import os
import re
import smtplib
import threading
import time
from datetime import datetime, timezone
from email.mime.text import MIMEText
from queue import Empty, Queue

import requests

try:
    from django.db import connection, transaction
    from django.http import HttpResponse, HttpResponseForbidden
except ImportError:
    connection = None
    transaction = None
    HttpResponse = None
    HttpResponseForbidden = None

# ── Configuration ─────────────────────────────────────────────────────────────
APP_NAME       = os.getenv('RSS_SOC_APP_NAME',    'my-app')
SOC_URL        = os.getenv('RSS_SOC_URL',         'http://198.199.70.48:3100')
SOC_TOKEN      = os.getenv('RSS_SOC_TOKEN',       'rssbank-token-2024')
ENV_NAME       = os.getenv('RSS_SOC_ENV',         'production')
LOCAL_LOGS     = os.getenv('RSS_SOC_LOCAL_LOGS',  '/app/logs')
BLOCK_ATTACKS  = os.getenv('RSS_SOC_BLOCK_ATTACKS', 'true').lower() == 'true'
BAN_DURATION   = int(os.getenv('RSS_SOC_BAN_DURATION', '3600'))  # seconds

# Email — disabled by default (Grafana SOC handles alerting)
SEND_EMAIL    = os.getenv('RSS_SOC_EMAIL_ALERTS', 'false').lower() == 'true'
ALERT_EMAIL   = os.getenv('RSS_SOC_ALERT_EMAIL',  '')
SMTP_HOST     = os.getenv('RSS_SOC_SMTP_HOST',    'smtp.gmail.com')
SMTP_PORT     = int(os.getenv('RSS_SOC_SMTP_PORT','587'))
SMTP_USER     = os.getenv('EMAIL_HOST_USER',      '')
SMTP_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD',  '')

# ── Threat detection patterns ─────────────────────────────────────────────────
SQL_RE = re.compile(
    r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|CAST|CONVERT)\b"
    r"|('|\")(\s)*(OR|AND)(\s)*(('|\")|\d)"
    r"|--(\s*$|\s+\w)|\bOR\s+1\s*=\s*1\b|SLEEP\s*\(|BENCHMARK\s*\()",
    re.IGNORECASE,
)
XSS_RE = re.compile(
    r"(<script|</script|javascript:|(?<![a-zA-Z0-9_])on\w+\s*=|<iframe|<object|<embed"
    r"|<img[^>]+onerror|alert\s*\(|document\.cookie)",
    re.IGNORECASE,
)
TRAVERSAL_RE = re.compile(r"\.\./|\.\.\\|/etc/passwd|%2e%2e", re.IGNORECASE)

# ── In-memory IP ban table (brute-force, no Suricata needed) ──────────────────
# {ip: expiry_timestamp}  — thread-safe via _ban_lock
_banned_ips  = {}
_ban_lock    = threading.Lock()

def _ban_ip(ip):
    with _ban_lock:
        _banned_ips[ip] = time.time() + BAN_DURATION

def _is_banned(ip):
    with _ban_lock:
        expiry = _banned_ips.get(ip)
        if expiry is None:
            return False
        if time.time() > expiry:
            del _banned_ips[ip]   # auto-expire
            return False
        return True

# ── Internal state ────────────────────────────────────────────────────────────
_log_queue      = Queue(maxsize=2000)
_worker_started = False
_worker_lock    = threading.Lock()
_table_ready    = False
_table_lock     = threading.Lock()


def _now_iso():
    return datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


# ── HTTP block responses ──────────────────────────────────────────────────────
def _block_403(threat):
    body = json.dumps({'error': 'Request blocked', 'reason': threat, 'code': 403})
    resp = HttpResponseForbidden(body, content_type='application/json')
    return resp

def _block_429(ip):
    body = json.dumps({
        'error': 'Too many failed attempts. Try again later.',
        'code': 429,
        'retry_after': BAN_DURATION,
    })
    resp = HttpResponse(body, content_type='application/json', status=429)
    resp['Retry-After'] = str(BAN_DURATION)
    return resp


# ── Optional email alert ──────────────────────────────────────────────────────
def _send_email_alert(subject, body):
    if not SEND_EMAIL or not SMTP_USER or not SMTP_PASSWORD or not ALERT_EMAIL:
        return

    def _send():
        try:
            msg = MIMEText(body, 'plain', 'utf-8')
            msg['Subject'] = f"[RSS SOC] {subject}"
            msg['From']    = SMTP_USER
            msg['To']      = ALERT_EMAIL
            with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=10) as s:
                s.starttls()
                s.login(SMTP_USER, SMTP_PASSWORD)
                s.send_message(msg)
        except Exception as e:
            print(f"[rss-soc] email failed: {e}")

    threading.Thread(target=_send, daemon=True).start()


# ── Brute-force counter (PostgreSQL, multi-worker safe) ───────────────────────
def _ensure_bf_table():
    global _table_ready
    if _table_ready or connection is None:
        return
    with _table_lock:
        if _table_ready:
            return
        try:
            with transaction.atomic():
                with connection.cursor() as cur:
                    cur.execute("""
                        CREATE TABLE IF NOT EXISTS rss_soc_login_failures (
                            id SERIAL PRIMARY KEY,
                            ip VARCHAR(64) NOT NULL,
                            ts TIMESTAMPTZ NOT NULL DEFAULT NOW()
                        )
                    """)
                    cur.execute("""
                        CREATE INDEX IF NOT EXISTS idx_rss_soc_lf_ip_ts
                        ON rss_soc_login_failures(ip, ts)
                    """)
            _table_ready = True
        except Exception as e:
            print(f"[rss-soc] brute-force table init failed: {e}")


def _record_login_failure(ip):
    """Insert failure + return count in last 5 min. Falls back to 0 if no DB."""
    if connection is None:
        return 0
    _ensure_bf_table()
    if not _table_ready:
        return 0
    try:
        with transaction.atomic():
            with connection.cursor() as cur:
                cur.execute(
                    "INSERT INTO rss_soc_login_failures (ip) VALUES (%s)", [ip]
                )
                cur.execute("""
                    SELECT COUNT(*) FROM rss_soc_login_failures
                    WHERE ip = %s AND ts > NOW() - INTERVAL '5 minutes'
                """, [ip])
                return cur.fetchone()[0]
    except Exception as e:
        print(f"[rss-soc] brute-force DB error: {e}")
        return 0


# ── Loki push worker (background thread) ─────────────────────────────────────
def _loki_worker():
    session  = requests.Session()
    endpoint = f"{SOC_URL.rstrip('/')}/loki/api/v1/push"
    headers  = {'Content-Type': 'application/json', 'X-Scope-OrgID': SOC_TOKEN}

    while True:
        batch = []
        try:
            batch.append(_log_queue.get(timeout=5))
            for _ in range(99):
                try:
                    batch.append(_log_queue.get_nowait())
                except Empty:
                    break
        except Empty:
            continue

        streams_by_labels = {}
        for ev in batch:
            key = tuple(sorted(ev['labels'].items()))
            streams_by_labels.setdefault(key, []).append(ev)

        streams = [
            {
                'stream': dict(key),
                'values': [
                    [str(int(ev['ts_unix'] * 1e9)), json.dumps(ev['data'])]
                    for ev in events
                ],
            }
            for key, events in streams_by_labels.items()
        ]
        try:
            session.post(endpoint, json={'streams': streams},
                         headers=headers, timeout=5)
        except Exception:
            pass


def _ensure_worker():
    global _worker_started
    with _worker_lock:
        if not _worker_started:
            t = threading.Thread(target=_loki_worker, daemon=True,
                                 name='rss-soc-loki-pusher')
            t.start()
            _worker_started = True


def _push_event(event_type, data, job, alert=False):
    _ensure_worker()
    labels = {'app': APP_NAME, 'env': ENV_NAME, 'job': job}
    if event_type and job == 'django-security':
        labels['event'] = event_type

    try:
        _log_queue.put_nowait({'ts_unix': time.time(), 'data': data, 'labels': labels})
    except Exception:
        pass

    try:
        os.makedirs(LOCAL_LOGS, exist_ok=True)
        fname = 'security.log' if job == 'django-security' else 'access.log'
        with open(os.path.join(LOCAL_LOGS, fname), 'a') as f:
            f.write(json.dumps(data) + '\n')
            f.flush()
            os.fsync(f.fileno())
    except Exception:
        pass

    if alert and SEND_EMAIL:
        _send_email_alert(
            subject=f"{event_type} — {data.get('ip', '?')}",
            body=(
                f"Security alert on {APP_NAME}\n\n"
                f"Event : {event_type}\n"
                f"IP    : {data.get('ip', '?')}\n"
                f"Path  : {data.get('path', '?')}\n"
                f"Time  : {data.get('ts', '?')}\n\n"
                f"Details:\n{json.dumps(data, indent=2)}\n\n"
                f"SOC Dashboard: {SOC_URL.replace(':3100', ':3000')}"
            ),
        )


# ── Request helpers ───────────────────────────────────────────────────────────
def _get_client_ip(request):
    xff = request.META.get('HTTP_X_FORWARDED_FOR')
    if xff:
        return xff.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', 'unknown')


def _detect(value):
    if not isinstance(value, str):
        return []
    threats = []
    if SQL_RE.search(value):
        threats.append('SQL_INJECTION')
    if XSS_RE.search(value):
        threats.append('XSS')
    if TRAVERSAL_RE.search(value):
        threats.append('PATH_TRAVERSAL')
    return threats


def _scan_request(request):
    threats = []
    try:
        for k, v in request.GET.items():
            threats += _detect(f"{k}={v}")
        if request.content_type and 'json' in request.content_type:
            try:
                body = request.body.decode('utf-8', errors='ignore')
                threats += _detect(body)
            except Exception:
                pass
        else:
            try:
                for k, v in request.POST.items():
                    threats += _detect(f"{k}={v}")
            except Exception:
                pass
        threats += _detect(request.path)
    except Exception:
        pass
    return list(set(threats))


# ── Middleware class ──────────────────────────────────────────────────────────
class SecurityMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response
        print(
            f"[rss-soc] v5 active | app={APP_NAME} env={ENV_NAME} "
            f"soc={SOC_URL} block={BLOCK_ATTACKS} ban={BAN_DURATION}s "
            f"email={SEND_EMAIL}"
        )

    def __call__(self, request):
        start = time.time()
        ip    = _get_client_ip(request)

        # ── 1. Banned IP check (brute-force ban, no Suricata needed) ──────────
        if BLOCK_ATTACKS and _is_banned(ip):
            _push_event('BANNED_IP', {
                'ts': _now_iso(), 'event': 'BANNED_IP',
                'ip': ip, 'path': request.path,
                'method': request.method, 'app': APP_NAME,
            }, job='django-security')
            return _block_429(ip)

        # ── 2. Attack pattern scan — block BEFORE the view runs ───────────────
        threats = _scan_request(request)
        if threats:
            ts = _now_iso()
            for threat in threats:
                _push_event(threat, {
                    'ts': ts, 'event': threat, 'ip': ip,
                    'method': request.method, 'path': request.path,
                    'app': APP_NAME, 'blocked': BLOCK_ATTACKS,
                }, job='django-security', alert=True)

            if BLOCK_ATTACKS:
                # Return 403 — view never executes
                return _block_403(threats[0])

        # ── 3. Normal request processing ──────────────────────────────────────
        response    = self.get_response(request)
        duration_ms = int((time.time() - start) * 1000)

        user_email = 'anonymous'
        try:
            u = getattr(request, 'user', None)
            if u and hasattr(u, 'email') and u.is_authenticated:
                user_email = u.email
        except Exception:
            pass

        # Access log
        _push_event('', {
            'ts': _now_iso(), 'method': request.method,
            'path': request.path, 'status': response.status_code,
            'ip': ip, 'user': user_email,
            'duration_ms': duration_ms, 'app': APP_NAME,
        }, job='django-access')

        # ── 4. Auth events + brute-force ban ──────────────────────────────────
        is_login = (
            ('login' in request.path.lower() or 'auth' in request.path.lower())
            and request.method == 'POST'
        )

        if is_login:
            if response.status_code in (200, 201):
                _push_event('LOGIN_SUCCESS', {
                    'ts': _now_iso(), 'event': 'LOGIN_SUCCESS',
                    'ip': ip, 'user': user_email, 'app': APP_NAME,
                }, job='django-security')

            elif response.status_code in (400, 401, 403):
                _push_event('LOGIN_FAILURE', {
                    'ts': _now_iso(), 'event': 'LOGIN_FAILURE',
                    'ip': ip, 'status': response.status_code,
                    'path': request.path, 'app': APP_NAME,
                }, job='django-security')

                count = _record_login_failure(ip)
                if count >= 5:
                    _push_event('BRUTE_FORCE', {
                        'ts': _now_iso(), 'event': 'BRUTE_FORCE',
                        'ip': ip, 'attempts': count,
                        'path': request.path, 'app': APP_NAME,
                    }, job='django-security', alert=True)

                    if BLOCK_ATTACKS:
                        _ban_ip(ip)   # next requests from this IP → 429

        elif response.status_code == 401:
            _push_event('UNAUTHORIZED', {
                'ts': _now_iso(), 'event': 'UNAUTHORIZED',
                'ip': ip, 'path': request.path, 'app': APP_NAME,
            }, job='django-security')

        return response


# ── Public helpers (usable from views) ───────────────────────────────────────
def get_client_ip(request):
    return _get_client_ip(request)


def log_security_event(event, ip, request=None, extra=None):
    data = {'ts': _now_iso(), 'event': event, 'ip': ip, 'app': APP_NAME}
    if request is not None:
        data['method'] = request.method
        data['path']   = request.path
    if extra:
        data.update(extra)
    _push_event(event, data, job='django-security')
