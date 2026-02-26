FROM python:3.11-slim

WORKDIR /app

# Dépendances système
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY . .

# Créer les dossiers et collecter les fichiers statiques
RUN mkdir -p logs media staticfiles && \
    python manage.py collectstatic --noinput

EXPOSE 8000

# run.sh gère migrations (au démarrage, quand la DB est dispo) + gunicorn
CMD ["bash", "run.sh"]
