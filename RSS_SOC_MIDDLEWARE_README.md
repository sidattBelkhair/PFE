# RSS SOC Security Middleware — Guide d'installation

Ce middleware Django envoie automatiquement les logs de sécurité de ton app
vers le SOC central RSS Bank. Tu n'as rien à configurer côté Grafana.

---

## Ce que tu reçois

| Événement          | Déclencheur                                      |
|--------------------|--------------------------------------------------|
| `SQL_INJECTION`    | Paramètre GET/POST contient une payload SQL      |
| `XSS`              | Paramètre contient du HTML/JS malveillant        |
| `PATH_TRAVERSAL`   | URL contient `../`, `/etc/passwd`, etc.          |
| `LOGIN_FAILURE`    | POST login avec réponse 400/401/403              |
| `BRUTE_FORCE`      | 5+ échecs de login depuis la même IP en 5 min   |
| `LOGIN_SUCCESS`    | POST login avec réponse 200/201                  |
| `UNAUTHORIZED`     | Réponse 401 hors login                           |
| `ACCESS`           | Chaque requête (ip, chemin, durée, statut)       |

---

## Installation en 3 étapes

### 1. Copier le fichier

```
apps/core/security_middleware.py   ← copier ce fichier dans ton projet
```

### 2. Ajouter dans `settings.py`

```python
MIDDLEWARE = [
    'apps.core.security_middleware.SecurityMiddleware',  # ← en premier
    'django.middleware.security.SecurityMiddleware',
    # ... reste de ta config
]
```

### 3. Configurer `.env`

```env
# Seule variable obligatoire : ton nom d'app (apparaîtra dans Grafana)
RSS_SOC_APP_NAME=nom-de-ton-app

# Ne pas changer — pointe vers le SOC central
RSS_SOC_URL=http://198.199.70.48:3100
RSS_SOC_TOKEN=rssbank-token-2024
RSS_SOC_ENV=production

# Dossier local pour les logs (doit être accessible en écriture)
RSS_SOC_LOCAL_LOGS=/app/logs

# Email désactivé — le SOC Grafana gère déjà les alertes
RSS_SOC_EMAIL_ALERTS=false
```

### 4. Redémarrer ton app Django

```bash
docker-compose restart   # ou systemctl restart gunicorn
```

---

## Vérification

Regarde les logs de démarrage de Django, tu dois voir :

```
[rss-soc] v4 active | app=nom-de-ton-app env=production soc=http://198.199.70.48:3100 email_alerts=False
```

Pour tester que les logs arrivent sur le SOC :

```bash
# Déclenche une alerte SQL (depuis n'importe quelle machine)
curl "http://ton-serveur:8000/api/" -G --data-urlencode "q=' OR 1=1"

# Vérifie côté SOC
curl -s "http://198.199.70.48:3100/loki/api/v1/query" \
  -H "X-Scope-OrgID: rssbank-token-2024" \
  --data-urlencode 'query={app="nom-de-ton-app"}'
```

---

## Notes

- Aucune dépendance externe sauf `requests` (déjà dans Django en général)
- Compatible Python 3.8+, Django 3.2+
- La table `rss_soc_login_failures` est créée automatiquement dans ta base PostgreSQL
- Les logs sont aussi écrits localement dans `RSS_SOC_LOCAL_LOGS/security.log`

---

Contact : belkhairtaleb@gmail.com
