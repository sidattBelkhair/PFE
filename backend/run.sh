#!/bin/bash
# Script de démarrage du backend SEDAD BANK
# Usage: bash run.sh [port]
PORT=${1:-8000}
cd "$(dirname "$0")"
source venv/bin/activate
echo "✓ Venv activé"
python manage.py migrate --run-syncdb 2>&1
echo "✓ Migrations OK"
echo "🚀 Démarrage sur http://127.0.0.1:$PORT"
python manage.py runserver 0.0.0.0:$PORT
