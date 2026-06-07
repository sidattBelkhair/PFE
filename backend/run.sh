#!/bin/bash
set -e

echo "[INIT] Waiting for database..."
until pg_isready -h "${DB_HOST:-db}" -p "${DB_PORT:-5432}" -U "${DB_USER:-postgres}" 2>/dev/null; do
  sleep 2
done
echo "[INIT] Database ready"

echo "[INIT] Running migrations..."
python manage.py migrate --noinput

echo "[INIT] Collecting static files..."
python manage.py collectstatic --noinput 2>/dev/null || true

echo "[INIT] Creating superuser..."
python manage.py shell <<'PYEOF' || true
from django.contrib.auth import get_user_model
User = get_user_model()
try:
    if not User.objects.filter(email='admin@rss.com').exists():
        try:
            User.objects.create_superuser(email='admin@rss.com', password='Admin2024!', first_name='Admin', last_name='RSS')
            print('Admin created: admin@rss.com / Admin2024!')
        except Exception:
            User.objects.create_superuser(username='admin', email='admin@rss.com', password='Admin2024!')
            print('Admin created (with username): admin / Admin2024!')
    else:
        print('Admin already exists')
except Exception as e:
    print(f'Admin creation skipped: {e}')
PYEOF

echo "[INIT] Starting Gunicorn..."
exec gunicorn fintech_bank.wsgi:application \
    --bind 0.0.0.0:8000 \
    --workers 3 \
    --timeout 60 \
    --forwarded-allow-ips="*" \
    --access-logfile - \
    --error-logfile -
