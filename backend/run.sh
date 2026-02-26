#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  RSS BANK — Script de démarrage backend
#  - Local   : active le venv + runserver
#  - Docker  : gunicorn directement (pas de venv)
# ─────────────────────────────────────────────────────────────
PORT=${1:-8000}
cd "$(dirname "$0")"

# Activer le venv uniquement si on est en LOCAL (pas dans Docker)
if [ -d "venv" ]; then
  source venv/bin/activate
  echo "[RSS BANK] Venv activé (mode local)"
fi

# Appliquer les migrations
echo "[RSS BANK] Application des migrations..."
python manage.py migrate --run-syncdb
echo "[RSS BANK] Migrations OK"

# Démarrer le serveur
if [ -d "venv" ]; then
  # LOCAL : serveur de développement Django
  echo "[RSS BANK] Démarrage local sur http://0.0.0.0:$PORT"
  python manage.py runserver 0.0.0.0:$PORT
else
  # DOCKER / PRODUCTION : gunicorn
  echo "[RSS BANK] Démarrage production sur http://0.0.0.0:$PORT"
  exec gunicorn fintech_bank.wsgi:application \
    --bind "0.0.0.0:$PORT" \
    --workers 2 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile -
fi
