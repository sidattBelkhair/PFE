#!/bin/bash
# ================================================================
# Scan de reconnaissance — SEDAD BANK PFE
# Usage: ./scan.sh [ip_cible]
# ================================================================

TARGET=${1:-localhost}
API="http://$TARGET:8000"

echo "================================================================"
echo "  SCAN DE RECONNAISSANCE — SEDAD BANK PFE"
echo "================================================================"
echo "  Cible : $TARGET"
echo ""

# ── 1. Scan de ports ─────────────────────────────────────────────
echo "[1] Scan des ports ouverts..."
for port in 80 8000 3000 3100 5432; do
    result=$(timeout 2 bash -c "echo >/dev/tcp/$TARGET/$port" 2>/dev/null && echo "OUVERT" || echo "ferme")
    printf "  Port %-5s : %s\n" "$port" "$result"
done

# ── 2. Test des endpoints publics ────────────────────────────────
echo ""
echo "[2] Test des endpoints API (sans authentification)..."
ENDPOINTS=(
    "GET /api/auth/login/"
    "GET /api/auth/register/"
    "GET /api/accounts/"
    "GET /api/transactions/"
    "GET /api/users/me/"
    "GET /api/admin/"
)

for ep in "${ENDPOINTS[@]}"; do
    method=$(echo $ep | cut -d' ' -f1)
    path=$(echo $ep | cut -d' ' -f2)
    code=$(curl -s -o /dev/null -w "%{http_code}" -X $method "$API$path" --max-time 3)
    printf "  %-6s %-35s -> HTTP %s\n" "$method" "$path" "$code"
done

# ── 3. Test XSS via query params ─────────────────────────────────
echo ""
echo "[3] Test XSS dans les paramètres..."
XSS_PAYLOAD='<script>alert(1)</script>'
code=$(curl -s -o /dev/null -w "%{http_code}" \
    "$API/api/accounts/?search=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$XSS_PAYLOAD'))")" \
    --max-time 3)
echo "  XSS payload dans ?search -> HTTP $code"

# ── 4. Test Path Traversal ────────────────────────────────────────
echo ""
echo "[4] Test Path Traversal..."
TRAVERSAL_PAYLOADS=("../../../etc/passwd" "..%2F..%2F..%2Fetc%2Fpasswd")
for pl in "${TRAVERSAL_PAYLOADS[@]}"; do
    code=$(curl -s -o /dev/null -w "%{http_code}" "$API/api/$pl" --max-time 3)
    printf "  %-40s -> HTTP %s\n" "$pl" "$code"
done

# ── 5. Résumé ─────────────────────────────────────────────────────
echo ""
echo "================================================================"
echo "  RESULTATS"
echo "  - Codes 401/403 : Protection active (bon signe)"
echo "  - Codes 200 sans auth : Endpoint public ou vulnérable"
echo "  - Codes 500 : Potentielle vulnérabilité applicative"
echo "================================================================"
echo "  Dashboard SOC : http://localhost:3000/d/sedad-bank-soc"
echo "================================================================"
