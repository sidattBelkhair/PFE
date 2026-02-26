"""
Security Middleware — RSS BANK SOC
Logs all requests and detects suspicious patterns.
"""
import json
import logging
import re
import time
from datetime import datetime
from django.core.cache import cache

security_logger = logging.getLogger('security')
access_logger = logging.getLogger('access')

# Patterns malveillants à détecter
SQL_PATTERNS = re.compile(
    r"(\b(SELECT|INSERT|UPDATE|DELETE|DROP|CREATE|ALTER|EXEC|UNION|CAST|CONVERT)\b"
    r"|('|\")(\s)*(OR|AND)(\s)*(('|\")|\d)"
    r"|--(\s*$|\s+\w)"
    r"|\bOR\s+1\s*=\s*1\b"
    r"|SLEEP\s*\("
    r"|BENCHMARK\s*\()",
    re.IGNORECASE
)

XSS_PATTERNS = re.compile(
    r"(<script|</script|javascript:|on\w+\s*=|<iframe|<object|<embed"
    r"|<img[^>]+onerror|alert\s*\(|document\.cookie|window\.location)",
    re.IGNORECASE
)

PATH_TRAVERSAL = re.compile(r"\.\./|\.\.\\")

# IPs whelist (ne pas logger en sécurité)
WHITELIST_IPS = ['127.0.0.1', '::1']

# Nombre max de tentatives avant brute-force alert
BRUTE_FORCE_THRESHOLD = 5
BRUTE_FORCE_WINDOW = 300  # 5 minutes (secondes)


def get_client_ip(request):
    x_forwarded = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded:
        return x_forwarded.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR', 'unknown')


def detect_threats(value: str) -> list:
    threats = []
    if SQL_PATTERNS.search(value):
        threats.append('SQL_INJECTION')
    if XSS_PATTERNS.search(value):
        threats.append('XSS')
    if PATH_TRAVERSAL.search(value):
        threats.append('PATH_TRAVERSAL')
    return threats


def scan_request(request) -> list:
    """Scanne la requête entière pour détecter des patterns malveillants."""
    threats = []

    # Query string
    for key, val in request.GET.items():
        threats += detect_threats(f"{key}={val}")

    # Body (JSON ou form)
    try:
        if request.content_type and 'json' in request.content_type:
            body = request.body.decode('utf-8', errors='ignore')
            threats += detect_threats(body)
        else:
            for key, val in request.POST.items():
                threats += detect_threats(f"{key}={val}")
    except Exception:
        pass

    # Path
    threats += detect_threats(request.path)

    return list(set(threats))


def log_security_event(event: str, ip: str, request=None, extra: dict = None):
    """Écrit un événement dans security.log au format JSON."""
    log_data = {
        'ts': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'event': event,
        'ip': ip,
    }
    if request:
        log_data['method'] = request.method
        log_data['path'] = request.path
        user = getattr(request, 'user', None)
        if user and hasattr(user, 'email') and user.is_authenticated:
            log_data['user'] = user.email
    if extra:
        log_data.update(extra)
    security_logger.warning(json.dumps(log_data))


class SecurityMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        start = time.time()
        ip = get_client_ip(request)

        # ── Détection de menaces avant traitement ──────────────────
        threats = scan_request(request)
        for threat in threats:
            log_security_event(threat, ip, request)

        # ── Traitement de la requête ────────────────────────────────
        response = self.get_response(request)
        duration_ms = int((time.time() - start) * 1000)

        # ── Log d'accès ─────────────────────────────────────────────
        user = getattr(request, 'user', None)
        user_email = user.email if (user and hasattr(user, 'email') and user.is_authenticated) else 'anonymous'

        access_data = {
            'ts': datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
            'method': request.method,
            'path': request.path,
            'status': response.status_code,
            'ip': ip,
            'user': user_email,
            'duration_ms': duration_ms,
        }
        access_logger.info(json.dumps(access_data))

        # ── Alertes sur codes d'erreur ──────────────────────────────
        if response.status_code == 401:
            log_security_event('UNAUTHORIZED', ip, request)
        elif response.status_code == 403:
            log_security_event('FORBIDDEN', ip, request, {'user': user_email})

        return response
