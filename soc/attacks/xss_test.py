#!/usr/bin/env python3
"""
Test XSS — SEDAD BANK PFE
Usage: python xss_test.py [--url http://localhost:8000] [--token JWT]
"""
import requests
import argparse

XSS_PAYLOADS = [
    ('<script>alert("xss")</script>',      "Script tag basique"),
    ('<img src=x onerror=alert(1)>',        "Img onerror"),
    ('javascript:alert(document.cookie)',  "javascript: URI"),
    ('"><script>alert(1)</script>',         "Tag injection"),
    ('<svg onload=alert(1)>',               "SVG onload"),
    ('<iframe src=javascript:alert(1)>',    "Iframe javascript"),
]

def run(base_url: str, token: str):
    headers = {"Authorization": f"Bearer {token}"} if token else {}

    print("=" * 60)
    print("  TEST XSS — SEDAD BANK PFE")
    print("=" * 60)

    endpoints_get = [
        f"{base_url}/api/accounts/",
        f"{base_url}/api/transactions/",
    ]

    for url in endpoints_get:
        print(f"\n[ENDPOINT] GET {url}")
        for payload, name in XSS_PAYLOADS:
            try:
                r = requests.get(url, params={"search": payload},
                                 headers=headers, timeout=5)
                # Si le payload est réfléchi dans la réponse → vulnérable
                reflected = payload in r.text
                if r.status_code == 500:
                    result = "POTENTIELLEMENT VULNERABLE (500)"
                elif reflected:
                    result = f"PAYLOAD REFLECHI (code {r.status_code})"
                else:
                    result = f"Protege ({r.status_code})"
                print(f"  {name:<28} -> {result}")
            except Exception as e:
                print(f"  {name:<28} -> Erreur: {e}")

    print("\n[FIN] Test XSS terminé.")
    print("Vérifier les logs SOC : http://localhost:3000/d/sedad-bank-soc")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--url",   default="http://localhost:8000")
    p.add_argument("--token", default="")
    args = p.parse_args()
    run(args.url, args.token)
