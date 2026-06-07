#!/bin/bash
# ============================================================
#  RSS BANK — Script de test SOC complet
#  Usage : ./hack.sh [BASE_URL]
#  Défaut: http://localhost:8000
# ============================================================

BASE=${1:-http://localhost:8000}
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[✓] $1${NC}"; }
info() { echo -e "${BLUE}[→] $1${NC}"; }
warn() { echo -e "${YELLOW}[!] $1${NC}"; }
sep()  { echo -e "${BLUE}══════════════════════════════════════════${NC}"; }

sep
echo -e "${YELLOW}  RSS BANK SOC — Test d'attaques complet"
echo -e "  Target : $BASE${NC}"
sep

# ── PHASE 1 : Vérification backend ──────────────────────────
echo ""; warn "PHASE 1 — Vérification backend"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" $BASE/api/)
ok "Backend répond → HTTP $STATUS"

# ── PHASE 2 : Brute Force ────────────────────────────────────
echo ""; warn "PHASE 2 — Brute Force (6 tentatives)"
for i in $(seq 1 6); do
    S=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE/api/auth/login/ \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"victim@test.com\",\"password\":\"wrong$i\"}")
    echo "  Tentative $i → HTTP $S"; sleep 0.3
done
ok "→ BRUTE_FORCE dans security.log"

# ── PHASE 3 : SQL Injection ──────────────────────────────────
echo ""; warn "PHASE 3 — SQL Injection (10 payloads)"
for p in "' OR 1=1--" "' UNION SELECT 1,2--" "'; DROP TABLE users;--" \
         "admin'--" "1' AND SLEEP(5)--" "' OR 'x'='x" \
         "EXEC xp_cmdshell('id')" "1; SELECT @@version" \
         "' AND 1=CONVERT(int,@@version)--" "1' BENCHMARK(5000000,MD5(1))--"; do
    S=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE/api/auth/login/ \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$p\",\"password\":\"x\"}" 2>/dev/null)
    echo "  SQLi: ${p:0:35}... → $S"; sleep 0.15
done
ok "→ SQL_INJECTION dans security.log"

# ── PHASE 4 : XSS ────────────────────────────────────────────
echo ""; warn "PHASE 4 — XSS (6 payloads)"
for p in "<script>alert(1)</script>" "<img src=x onerror=alert(1)>" \
         "javascript:alert(document.cookie)" "<iframe src='javascript:alert(1)'>" \
         "<svg onload=alert(1)>" "<body onload=alert(document.cookie)>"; do
    S=$(curl -s -o /dev/null -w "%{http_code}" -X POST $BASE/api/auth/login/ \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$p\",\"password\":\"x\"}" 2>/dev/null)
    echo "  XSS: ${p:0:40}... → $S"; sleep 0.15
done
ok "→ XSS dans security.log"

# ── PHASE 5 : Path Traversal ─────────────────────────────────
echo ""; warn "PHASE 5 — Path Traversal (6 payloads)"
for p in "/../../../etc/passwd" "/../../../etc/shadow" \
         "/%2e%2e%2fetc%2fpasswd" "/../../../proc/self/environ" \
         "/..\..\..\windows\system32" "/../../../var/log/auth.log"; do
    S=$(curl -s -o /dev/null -w "%{http_code}" "$BASE/api$p" 2>/dev/null)
    echo "  Traversal: $p → $S"; sleep 0.1
done
ok "→ PATH_TRAVERSAL dans security.log"

# ── PHASE 6 : Reconnaissance ─────────────────────────────────
echo ""; warn "PHASE 6 — Scan endpoints cachés"
for ep in "/admin/" "/.env" "/wp-login.php" "/phpmyadmin/" "/.git/config" \
          "/api/admin/" "/api/debug/" "/config.php" "/api/internal/"; do
    S=$(curl -s -o /dev/null -w "%{http_code}" "$BASE$ep" 2>/dev/null)
    echo "  Scan: $ep → $S"; sleep 0.1
done
ok "→ UNAUTHORIZED/FORBIDDEN dans security.log"

# ── PHASE 7 : Flood pour ML IsolationForest ──────────────────
echo ""; warn "PHASE 7 — Flood 100 requêtes (déclenche ML_ANOMALY dans ~60s)"
for i in $(seq 1 100); do
    curl -s -o /dev/null -X POST $BASE/api/auth/login/ \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"flood$i@x.com\",\"password\":\"x\"}" &
    [ $((i % 25)) -eq 0 ] && wait && echo "  $i/100..."
done
wait
ok "→ ML_ANOMALY détecté dans ~60s par IsolationForest"

# ── RÉSULTAT ─────────────────────────────────────────────────
sep
echo -e "\n${GREEN}  TOUTES LES ATTAQUES ENVOYÉES${NC}\n"
echo -e "${YELLOW}  Vérifie maintenant :${NC}"
echo -e "  1. Logs sécurité :"
echo -e "     cat backend/logs/security.log | python -m json.tool | tail -30"
echo -e "\n  2. Anomaly Detector ML :"
echo -e "     docker logs -f pfe-anomaly-detector-1"
echo -e "\n  3. IPs bannies par Fail2ban :"
echo -e "     docker exec pfe-fail2ban-1 fail2ban-client status"
echo -e "\n  4. Grafana → http://localhost:3000  (admin / SedadSOC2024!)"
sep
