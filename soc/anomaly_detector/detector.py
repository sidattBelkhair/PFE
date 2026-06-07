"""
RSS BANK — SOC Anomaly Detector
Détection d'anomalies par Machine Learning (scikit-learn IsolationForest)

Fonctionnement :
  1. Lit access.log en temps réel
  2. Toutes les 60 secondes, analyse les requêtes par IP
  3. Extrait des features comportementales
  4. IsolationForest détecte les IPs anormales
  5. Écrit les anomalies dans security.log → Loki → Grafana
"""

import json
import logging
import os
import time
from collections import defaultdict
from datetime import datetime

import numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

# ── Configuration ────────────────────────────────────────────────────────────
ACCESS_LOG  = os.getenv('ACCESS_LOG',  '/var/log/django/access.log')
SECURITY_LOG = os.getenv('SECURITY_LOG', '/var/log/django/security.log')
WINDOW_SEC  = int(os.getenv('WINDOW_SEC', '60'))    # analyse toutes les 60s
MIN_REQUESTS = int(os.getenv('MIN_REQUESTS', '5'))   # minimum requêtes pour analyser
CONTAMINATION = float(os.getenv('CONTAMINATION', '0.1'))  # 10% d'anomalies attendues

# ── Logging vers security.log ─────────────────────────────────────────────────
handler = logging.FileHandler(SECURITY_LOG)
handler.setFormatter(logging.Formatter('%(message)s'))
sec_logger = logging.getLogger('anomaly')
sec_logger.addHandler(handler)
sec_logger.setLevel(logging.WARNING)


def log_anomaly(ip: str, features: dict, score: float):
    """Écrit une anomalie ML dans security.log au format JSON."""
    event = {
        'ts':    datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
        'event': 'ML_ANOMALY',
        'ip':    ip,
        'anomaly_score': round(float(score), 4),
        'features': {
            'req_count':       int(features['req_count']),
            'error_rate':      round(features['error_rate'], 3),
            'unique_paths':    int(features['unique_paths']),
            'avg_duration_ms': round(features['avg_duration_ms'], 1),
            'post_ratio':      round(features['post_ratio'], 3),
            'hour':            int(features['hour']),
            'status_4xx_rate': round(features['status_4xx_rate'], 3),
            'status_5xx_rate': round(features['status_5xx_rate'], 3),
        }
    }
    sec_logger.warning(json.dumps(event))
    print(f"[ANOMALY] IP={ip} score={score:.4f} reqs={int(features['req_count'])}")


def extract_features(requests: list) -> dict:
    """
    Extrait 8 features comportementales à partir des requêtes d'une IP.

    Features :
      1. req_count       — nombre total de requêtes dans la fenêtre
      2. error_rate      — taux de réponses erreur (4xx + 5xx)
      3. unique_paths    — nombre de chemins distincts accédés
      4. avg_duration_ms — durée moyenne des requêtes (ms)
      5. post_ratio      — proportion de requêtes POST
      6. hour            — heure de la journée (0–23)
      7. status_4xx_rate — taux de réponses 4xx
      8. status_5xx_rate — taux de réponses 5xx
    """
    n = len(requests)
    statuses  = [r.get('status', 200) for r in requests]
    methods   = [r.get('method', 'GET') for r in requests]
    paths     = [r.get('path', '/') for r in requests]
    durations = [r.get('duration_ms', 0) for r in requests]

    s4xx = sum(1 for s in statuses if 400 <= s < 500)
    s5xx = sum(1 for s in statuses if s >= 500)

    # Heure extraite du premier log de la fenêtre
    try:
        ts = requests[-1].get('ts', '')
        hour = int(ts[11:13]) if len(ts) >= 13 else datetime.utcnow().hour
    except Exception:
        hour = datetime.utcnow().hour

    return {
        'req_count':       n,
        'error_rate':      (s4xx + s5xx) / n,
        'unique_paths':    len(set(paths)),
        'avg_duration_ms': sum(durations) / n if durations else 0,
        'post_ratio':      sum(1 for m in methods if m == 'POST') / n,
        'hour':            hour,
        'status_4xx_rate': s4xx / n,
        'status_5xx_rate': s5xx / n,
    }


def features_to_vector(f: dict) -> list:
    """Convertit le dict de features en vecteur numpy."""
    return [
        f['req_count'],
        f['error_rate'],
        f['unique_paths'],
        f['avg_duration_ms'],
        f['post_ratio'],
        f['hour'],
        f['status_4xx_rate'],
        f['status_5xx_rate'],
    ]


def analyze_window(ip_requests: dict):
    """
    Analyse une fenêtre temporelle.
    - Filtre les IPs avec assez de requêtes
    - Entraîne IsolationForest
    - Détecte et logue les anomalies
    """
    # Filtrer les IPs avec suffisamment de requêtes
    active_ips = {
        ip: reqs for ip, reqs in ip_requests.items()
        if len(reqs) >= MIN_REQUESTS
    }

    if len(active_ips) < 2:
        print(f"[INFO] Pas assez d'IPs actives ({len(active_ips)}) pour analyser.")
        return

    # Extraire features pour chaque IP
    ip_features = {}
    for ip, reqs in active_ips.items():
        ip_features[ip] = extract_features(reqs)

    # Construire la matrice X
    ips    = list(ip_features.keys())
    X_raw  = np.array([features_to_vector(ip_features[ip]) for ip in ips])

    # Normalisation
    scaler = StandardScaler()
    X      = scaler.fit_transform(X_raw)

    # ── IsolationForest ───────────────────────────────────────────────────────
    # contamination = proportion d'anomalies attendues dans les données
    # n_estimators  = nombre d'arbres dans la forêt
    # random_state  = reproductibilité
    clf = IsolationForest(
        n_estimators=100,
        contamination=CONTAMINATION,
        random_state=42,
    )
    clf.fit(X)

    # scores : valeur négative → plus anormal
    scores = clf.score_samples(X)   # entre -0.5 et 0.5 environ
    preds  = clf.predict(X)         # -1 = anomalie, 1 = normal

    print(f"[INFO] Fenêtre analysée — {len(ips)} IPs, {sum(p==-1 for p in preds)} anomalie(s)")

    for i, ip in enumerate(ips):
        if preds[i] == -1:
            log_anomaly(ip, ip_features[ip], scores[i])


def tail_log(filepath: str):
    """Lit le fichier log ligne par ligne, attend les nouvelles lignes."""
    # Attendre que le fichier existe
    while not os.path.exists(filepath):
        print(f"[WAIT] En attente de {filepath}...")
        time.sleep(5)

    print(f"[START] Lecture de {filepath}")
    with open(filepath, 'r') as f:
        f.seek(0, 2)  # aller à la fin du fichier
        while True:
            line = f.readline()
            if line:
                yield line.strip()
            else:
                time.sleep(0.1)


def main():
    print("=" * 60)
    print("  RSS BANK — Anomaly Detector (scikit-learn IsolationForest)")
    print(f"  Fenêtre d'analyse : {WINDOW_SEC}s")
    print(f"  Minimum requêtes  : {MIN_REQUESTS}")
    print(f"  Contamination     : {CONTAMINATION*100:.0f}%")
    print("=" * 60)

    ip_requests: dict = defaultdict(list)
    last_analysis = time.time()

    for line in tail_log(ACCESS_LOG):
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue

        ip = entry.get('ip', 'unknown')
        if ip in ('127.0.0.1', '::1'):
            continue  # ignorer localhost

        ip_requests[ip].append(entry)

        # Analyser toutes les WINDOW_SEC secondes
        now = time.time()
        if now - last_analysis >= WINDOW_SEC:
            print(f"\n[WINDOW] Analyse à {datetime.utcnow().strftime('%H:%M:%S')} "
                  f"— {sum(len(v) for v in ip_requests.values())} requêtes")
            analyze_window(ip_requests)
            ip_requests.clear()
            last_analysis = now


if __name__ == '__main__':
    main()
