
BACKEND_IP="${1:-localhost}"
BASE_URL="http://${BACKEND_IP}:8000"

echo "==============================================="
echo "  RSS BANK - Test d'attaques sur ${BASE_URL}"
echo "==============================================="

# ── 1. Brute Force (6 tentatives de login) ───────────────────
echo ""
echo "[1/5] 🔑 Brute Force sur /api/auth/login/"
for i in {1..6}; do
  curl -s -X POST "${BASE_URL}/api/auth/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@rss.com\",\"password\":\"wrong${i}\"}" \
    -o /dev/null -w "  Tentative $i : HTTP %{http_code}\n"
  sleep 0.5
done

# ── 2. SQL Injection ─────────────────────────────────────────
echo ""
echo "[2/5] 💉 SQL Injection"
curl -s "${BASE_URL}/api/users/?search=' OR '1'='1" \
  -o /dev/null -w "  HTTP %{http_code}\n"
curl -s "${BASE_URL}/api/users/?id=1; DROP TABLE users--" \
  -o /dev/null -w "  HTTP %{http_code}\n"

# ── 3. XSS ────────────────────────────────────────────────────
echo ""
echo "[3/5] ⚡ XSS"
curl -s "${BASE_URL}/api/search/?q=<script>alert('xss')</script>" \
  -o /dev/null -w "  HTTP %{http_code}\n"
curl -s -X POST "${BASE_URL}/api/comments/" \
  -H "Content-Type: application/json" \
  -d '{"text":"<img src=x onerror=alert(1)>"}' \
  -o /dev/null -w "  HTTP %{http_code}\n"

# ── 4. Path Traversal ────────────────────────────────────────
echo ""
echo "[4/5] 📂 Path Traversal"
curl -s "${BASE_URL}/api/files/?path=../../../etc/passwd" \
  -o /dev/null -w "  HTTP %{http_code}\n"
curl -s "${BASE_URL}/media/../../../etc/shadow" \
  -o /dev/null -w "  HTTP %{http_code}\n"

# ── 5. Comportement anormal (pour déclencher ML) ─────────────
echo ""
echo "[5/5] 🤖 Comportement anormal (scan rapide)"
for path in /api/users /api/accounts /api/admin /api/debug /api/config \
            /api/internal /api/test /api/dev /wp-admin /phpmyadmin; do
  curl -s "${BASE_URL}${path}/" -o /dev/null -w "  ${path} → HTTP %{http_code}\n"
done

echo ""
echo "==============================================="
echo "  ✅ Tests terminés !"
echo "  Consulte le dashboard : http://142.93.104.129:3000"
echo "==============================================="