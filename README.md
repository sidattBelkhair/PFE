# RSS BANK — Application Bancaire Mobile

> **Projet de Fin d'Études (PFE) 2025-2026**
> Application bancaire mobile complète avec SSO centralisé, SOC multi-applications et détection d'anomalies par ML.

---

## Table des matières

1. [Présentation](#1-présentation)
2. [Architecture Globale](#2-architecture-globale)
3. [Stack Technique](#3-stack-technique)
4. [SSO — Authentification Centralisée](#4-sso--authentification-centralisée)
5. [SOC Multi-Applications](#5-soc-multi-applications)
6. [ML Anomaly Detector](#6-ml-anomaly-detector)
7. [Modèles de données (ERD)](#7-modèles-de-données-erd)
8. [Diagrammes de conception](#8-diagrammes-de-conception)
9. [Prérequis](#9-prérequis)
10. [Lancement local avec Docker](#10-lancement-local-avec-docker)
11. [Déploiement Production](#11-déploiement-production)
12. [Configuration Email Gmail](#12-configuration-email-gmail)
13. [API Reference complète](#13-api-reference-complète)
14. [Application Flutter](#14-application-flutter)
15. [Multi-langue FR / AR](#15-multi-langue-fr--ar)
16. [Tests de sécurité](#16-tests-de-sécurité)
17. [Structure du projet](#17-structure-du-projet)

---

## 1. Présentation

**RSS BANK** est une plateforme bancaire mobile développée en Flutter, connectée à un backend Django REST, un serveur SSO OAuth2 centralisé, et un SOC (Security Operations Center) alimenté par Loki, Grafana et un détecteur ML d'anomalies.

### Fonctionnalités principales

| Catégorie | Fonctionnalité |
|-----------|---------------|
| Auth | Inscription avec vérification OTP email (6 chiffres, expire 10 min) |
| Auth | Connexion JWT (access 60 min / refresh 7 jours) |
| Auth | **SSO OAuth2 PKCE** via serveur centralisé (Render) |
| Auth | Mot de passe oublié → OTP → réinitialisation |
| Bancaire | Gestion comptes courant / épargne en **MRU** (Ouguiya Mauritanien) |
| Bancaire | Virements via numéro de téléphone ou **QR Code** |
| Bancaire | Recharge, retraits, paiements, factures |
| Sécurité | Anti brute-force (5 tentatives → blocage) |
| Sécurité | Détection SQL Injection, XSS, Path Traversal en temps réel |
| Sécurité | **ML Anomaly Detector** — détection comportementale |
| SOC | Dashboard Grafana + alertes email |
| UX | Multi-langue **Français / Arabe** (RTL automatique) |
| Admin | Dashboard gestion des statuts utilisateurs |

---

## 2. Architecture Globale

```
                        ┌─────────────────────┐
                        │   APP FLUTTER        │
                        │   Android (APK)      │
                        └──────┬───────────────┘
                               │ HTTPS API
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
 ┌────────────────┐  ┌──────────────────┐  ┌───────────────────┐
 │ BACKEND DJANGO │  │  SSO BACKEND     │  │  SOC CENTRALISÉ   │
 │ 104.248.61.147 │  │  (Render)        │  │  Grafana Cloud    │
 │ :8000          │  │  OAuth2 + OpenID │  │  Loki + Grafana   │
 │ REST API + JWT │  │  sso-backend-    │  │  ML Detector      │
 │ PostgreSQL     │  │  6b1e.onrender   │  │  Alertes Email    │
 └────────────────┘  └──────────────────┘  └───────────────────┘
```

---

## 3. Stack Technique

| Composant | Technologie | Version | URL |
|-----------|-------------|---------|-----|
| Frontend | Flutter + Provider + GoRouter | 3.x | — |
| Backend principal | Django REST Framework + SimpleJWT | 4.2.7 | `104.248.61.147:8000` |
| SSO | Django OAuth Toolkit (OpenID Connect) | — | `sso-backend-6b1e.onrender.com` |
| Base de données | PostgreSQL (prod) / SQLite (dev) | 15 | — |
| Collecte logs | Loki / Grafana Cloud | — | Grafana Cloud |
| ML Detector | Python (Isolation Forest / règles) | — | intégré au backend |
| Email OTP | Gmail SMTP | — | — |
| Serveur | Gunicorn | 21.2.0 | — |

---

## 4. SSO — Authentification Centralisée

### Concept

Le SSO permet à un utilisateur de se connecter à RSS BANK via un compte OAuth2 centralisé, sans créer de mot de passe local. Le flow utilise **PKCE** (Proof Key for Code Exchange) pour les applications mobiles publiques.

```
  Flutter App                SSO Backend               RSS Bank Backend
      │                   (sso-backend.onrender.com)   (104.248.61.147)
      │                           │                          │
      │── GET /o/authorize/ ─────►│                          │
      │   ?client_id=...          │                          │
      │   &redirect_uri=          │                          │
      │   com.example.sedad_bank  │                          │
      │   ://oauth/callback       │                          │
      │                           │                          │
      │◄── page login SSO ────────│                          │
      │                           │                          │
      │── submit credentials ────►│                          │
      │◄── code d'autorisation ───│                          │
      │   (redirect URI reçu)     │                          │
      │                           │                          │
      │── POST /o/token/ ────────►│                          │
      │◄── access_token SSO ──────│                          │
      │                           │                          │
      │── POST /api/auth/sso-login/ (access_token) ─────────►│
      │◄────────── JWT RSS Bank (access + refresh) ──────────│
```

### Configuration Flutter

**[lib/core/services/sso_service.dart](frontend/sedad_bank/lib/core/services/sso_service.dart)**

```dart
static const String clientId    = 'FaACVS7Ds3qjR5i6ynVmhGtzlZ44wan45hgDJwVF';
static const String redirectUrl = 'com.example.sedad_bank://oauth/callback';
static const String issuer      = 'https://sso-backend-6b1e.onrender.com';
```

### Configuration Android

**[android/app/src/main/AndroidManifest.xml](frontend/sedad_bank/android/app/src/main/AndroidManifest.xml)**

```xml
<activity android:name="net.openid.appauth.RedirectUriReceiverActivity" android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="com.example.sedad_bank" android:host="oauth" />
    </intent-filter>
</activity>
```

### Configuration SSO Backend (Render)

L'application OAuth est enregistrée sur le SSO backend :

| Champ | Valeur |
|-------|--------|
| `client_id` | `FaACVS7Ds3qjR5i6ynVmhGtzlZ44wan45hgDJwVF` |
| `redirect_uris` | `com.example.sedad_bank://oauth/callback` |
| `client_type` | `public` |
| `grant_type` | `authorization-code` |
| `app_id` | 10 (client 12) |

Pour mettre à jour la config via l'API SSO :

```bash
# 1. Login
TOKEN=$(curl -s -X POST https://sso-backend-6b1e.onrender.com/api/login/ \
  -H "Content-Type: application/json" \
  -d '{"identifier":"rssbank700@gmail.com","password":"RssBankSSO2024!"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access'])")

# 2. Voir la config actuelle
curl https://sso-backend-6b1e.onrender.com/api/clients/12/apps/10/ \
  -H "Authorization: Bearer $TOKEN"

# 3. Mettre à jour
curl -X PUT https://sso-backend-6b1e.onrender.com/api/clients/12/apps/10/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"RSS Bank Mobile","redirect_uris":"com.example.sedad_bank://oauth/callback","client_type":"public","grant_type":"authorization-code"}'
```

### Endpoint backend principal

```
POST /api/auth/sso-login/
Body: { "sso_access_token": "<token_obtenu_du_SSO>" }
Response: { "access": "...", "refresh": "...", "user": {...}, "sso": true }
```

---

## 5. SOC Multi-Applications

### Concept

Le SOC est une plateforme centralisée indépendante pouvant surveiller **plusieurs applications bancaires** simultanément.

```
┌──────────────────┐     logs JSON      ┌─────────────────────────────┐
│  RSS BANK        │ ────────────────►  │                             │
│  (App 1)         │                    │     SOC CENTRALISÉ          │
└──────────────────┘                    │                             │
                                        │  ┌─────────┐  ┌─────────┐  │
┌──────────────────┐     logs JSON      │  │  Loki   │  │Grafana  │  │
│  BANK APP 2      │ ────────────────►  │  │  Logs   │  │Dashboard│  │
│  (Django/Node)   │                    │  └─────────┘  └─────────┘  │
└──────────────────┘                    │                             │
                                        │  ┌──────────────────────┐  │
┌──────────────────┐     logs JSON      │  │  Fail2ban            │  │
│  BANK APP 3      │ ────────────────►  │  │  Blocage IP global   │  │
│  (Express/Rails) │                    │  └──────────────────────┘  │
└──────────────────┘                    │  Alertes → Email SOC Team  │
                                        └─────────────────────────────┘
```

### Intégrer une nouvelle application

Toute application peut rejoindre le SOC en envoyant ses logs au format JSON vers Loki :

```
POST http://SOC_SERVER:3100/loki/api/v1/push
```

```json
{
  "ts": "2026-05-07T10:30:00Z",
  "event": "BRUTE_FORCE",
  "ip": "192.168.1.1",
  "app": "nom_de_lapplication",
  "method": "POST",
  "path": "/api/auth/login/",
  "status": 401
}
```

**Python / Django :**
```python
pip install python-logging-loki

LOGGING['handlers']['loki'] = {
    'class': 'logging_loki.LokiHandler',
    'url': 'http://SOC_SERVER:3100/loki/api/v1/push',
    'tags': {'app': 'mon_app', 'env': 'production'},
    'version': '1',
}
```

**Node.js / Express :**
```javascript
const LokiTransport = require('winston-loki');
const logger = createLogger({
  transports: [new LokiTransport({ host: 'http://SOC_SERVER:3100' })]
});
```

### Événements détectés

| Événement | Condition | Seuil Fail2ban |
|-----------|-----------|----------------|
| `LOGIN_SUCCESS` | Connexion réussie | — |
| `LOGIN_FAILED` | Mauvais mot de passe | — |
| `BRUTE_FORCE` | ≥ 5 échecs / 5 min / même IP | Ban 1h |
| `SQL_INJECTION` | Pattern SQL dans requête | Ban 24h immédiat |
| `XSS` | `<script>`, `onerror=`, `javascript:` | Ban 24h immédiat |
| `PATH_TRAVERSAL` | `../` dans l'URL | Ban 24h immédiat |
| `UNAUTHORIZED` | HTTP 401 | — |
| `FORBIDDEN` | HTTP 403 | — |
| `SERVER_ERROR` | HTTP 5xx | — |
| `ML_ANOMALY` | Score Isolation Forest > seuil | Alerte Grafana |

### Alertes email Grafana

| Alerte | Déclencheur | Délai |
|--------|-------------|-------|
| Brute Force | > 1 événement / 5 min | Immédiat |
| SQL Injection | > 0 événement | Immédiat |
| XSS | > 0 événement | Immédiat |
| ML Anomalie | Score > 0.8 | Immédiat |
| Pic 401 | > 5 en 5 min | 5 min |
| Pic 500 | > 3 en 5 min | 5 min |

---

## 6. ML Anomaly Detector

Le détecteur ML analyse le comportement des requêtes en temps réel pour identifier des anomalies qui ne correspondent pas à des patterns d'attaque connus (zero-day, comportements suspects).

### Fonctionnement

```
Requête HTTP
     │
     ▼
┌──────────────────────────────┐
│  Feature extraction           │
│  - Fréquence requêtes / IP   │
│  - Heure de la requête       │
│  - Distribution des endpoints│
│  - Taille des payloads       │
│  - User-Agent                │
└──────────────┬───────────────┘
               │
               ▼
┌──────────────────────────────┐
│  Isolation Forest / Règles   │
│  Score anomalie [0.0 → 1.0]  │
└──────────────┬───────────────┘
               │
       ┌───────┴────────┐
       │ score > 0.8    │ score ≤ 0.8
       ▼                ▼
  Log ML_ANOMALY    Normal flow
  → Loki → Grafana
  → Alerte Email
```

### Événement généré

```json
{
  "ts": "2026-05-07T14:23:01Z",
  "event": "ML_ANOMALY",
  "ip": "41.222.x.x",
  "app": "rss_bank",
  "score": 0.92,
  "features": {"req_rate": 48, "hour": 3, "endpoint_entropy": 0.12}
}
```

---

## 7. Modèles de données (ERD)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        USER (AbstractUser)                          │
├─────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                          │
│     email           : CharField (unique)                            │
│     first_name      : CharField                                     │
│     last_name       : CharField                                     │
│     phone_number    : CharField                                     │
│     national_id     : CharField (unique)                            │
│     role            : ENUM [client, admin, agent]                   │
│     status          : ENUM [active, suspended, blocked, closed]     │
│     kyc_status      : ENUM [pending, approved, rejected]            │
│     two_factor_enabled : BooleanField                               │
│     last_login_ip   : GenericIPAddressField                         │
│     login_attempts  : IntegerField                                  │
│     created_at      : DateTimeField                                 │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ OneToOne
                               ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         USER PROFILE                                 │
├──────────────────────────────────────────────────────────────────────┤
│     verified_email  : BooleanField                                   │
│     otp_code        : CharField(6)   ← OTP vérification/reset       │
│     otp_expires_at  : DateTimeField  ← Expire dans 10 min           │
│     otp_type        : ENUM [verify_email, reset_password]            │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         ACCOUNT                                     │
├─────────────────────────────────────────────────────────────────────┤
│     account_number  : CharField (unique) ← Format: RSSxxxxxxxx     │
│     account_type    : ENUM [checking, savings]                      │
│     currency        : ENUM [MRU, DZD, USD, EUR]                    │
│     balance         : DecimalField(15,2)                            │
│     status          : ENUM [active, frozen, closed]                 │
│     daily_transfer_limit  : DecimalField  (défaut: 10 000 MRU)     │
└──────────────┬──────────────────────────────┬───────────────────────┘
               │ FK from_account              │ FK to_account
               ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        TRANSACTION                                  │
├─────────────────────────────────────────────────────────────────────┤
│     transaction_type: ENUM [transfer, payment, withdrawal,          │
│                              deposit, salary]                       │
│     amount          : DecimalField(15,2)                            │
│     reference_number: CharField (unique) ← Format: TXNxxxxxxxx     │
│     status          : ENUM [pending, processing, completed,         │
│                              failed, reversed]                      │
│     is_flagged      : BooleanField   ← Fraude détectée             │
│     fraud_score     : IntegerField   ← Score ML                    │
│     ip_address      : GenericIPAddressField                         │
└─────────────────────────────────────────────────────────────────────┘

Relations :
  User ──── UserProfile     (1:1)
  User ──── Account         (1:N)
  User ──── Beneficiary     (1:N)
  Account ── Card            (1:N)
  Account ── Transaction     (1:N) via from_account / to_account
  Transaction ── TransactionHistory (1:N)
```

---

## 8. Diagrammes de conception

### 8.1 Cas d'utilisation

```
                    ┌──────────────────────────────────────────┐
                    │              RSS BANK                    │
                    │                                          │
  ┌──────────┐      │  ○ S'inscrire (OTP email)               │
  │  CLIENT  │─────►│  ○ Se connecter (JWT ou SSO OAuth2)     │
  └──────────┘      │  ○ Voir solde / carte bancaire           │
                    │  ○ Effectuer un virement                 │
                    │  ○ Scanner / Générer QR Code             │
                    │  ○ Recharger / Retrait / Paiement        │
                    │  ○ Voir historique transactions          │
                    │  ○ Changer mot de passe                  │
  ┌──────────┐      │  ○ Basculer langue (FR/AR)               │
  │  ADMIN   │─────►│  ○ Gérer statuts utilisateurs            │
  └──────────┘      │  ○ Voir dashboard admin                  │
                    │                                          │
  ┌──────────┐      │  ○ Voir alertes sécurité (Grafana)       │
  │ SOC TEAM │─────►│  ○ Analyser logs + anomalies ML          │
  └──────────┘      │  ○ Bloquer IPs malveillantes             │
                    └──────────────────────────────────────────┘
```

### 8.2 Séquence — Inscription avec OTP

```
  Client Flutter          Backend Django              Gmail SMTP
       │                        │                          │
       │── POST /register/ ────►│                          │
       │                        │ génère OTP (6 chiffres)  │
       │                        │── send_mail() ──────────►│── email → Client
       │◄── 201 pending_verif ──│                          │
       │── POST /verify-email/ ─►│                         │
       │◄── 200 "Email vérifié" ─│                         │
       │── POST /login/ ────────►│                         │
       │◄── {access, refresh} ──│                          │
```

### 8.3 Séquence — Connexion SSO

```
  Flutter (AppAuth)      SSO Backend (Render)      RSS Bank Backend
       │                        │                          │
       │── GET /o/authorize/ ──►│                          │
       │◄── Chrome Custom Tab ──│                          │
       │   (page login SSO)     │                          │
       │── credentials ────────►│                          │
       │◄── redirect + code ────│                          │
       │── POST /o/token/ ─────►│                          │
       │◄── access_token ───────│                          │
       │── POST /auth/sso-login/ ─────────────────────────►│
       │◄── JWT RSS Bank ─────────────────────────────────│
```

### 8.4 Séquence — Détection d'attaque SOC

```
  Attaquant          Django Backend         Loki          Grafana       Email
      │                    │                 │               │             │
      │── 6x POST /login/ ─►│                │               │             │
      │                    │ détecte BF      │               │             │
      │                    │─ log JSON ─────►│               │             │
      │◄── 401 ────────────│                │◄── query ─────│             │
      │                    │                │─── données ───►│─ alerte ───►│
      │                    │ Fail2ban → iptables block IP    │             │
      │ (connexion refusée)│                │               │             │
```

### 8.5 Architecture de déploiement production

```
┌──────────────────────────────────────────────────────────────────┐
│                         INTERNET                                  │
└──────────┬────────────────────┬─────────────────┬────────────────┘
           │ HTTPS              │ HTTPS           │ HTTPS
           ▼                    ▼                 ▼
┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐
│ DigitalOcean     │  │  Render          │  │  Grafana Cloud     │
│ Droplet          │  │  SSO Backend     │  │  (SOC)             │
│ 104.248.61.147   │  │  OAuth2+OpenID   │  │  Loki + Dashboard  │
│ Django + Gunicorn│  │  sso-backend-    │  │  Alertes Email     │
│ PostgreSQL       │  │  6b1e.onrender   │  └────────────────────┘
└──────────────────┘  └──────────────────┘
           ▲
           │ requêtes API + auth SSO
           │
┌──────────────────┐
│   APK Flutter    │
│   Android        │
│   (téléphones)   │
└──────────────────┘
```

---

## 9. Prérequis

**Option Docker (local) :**
- Docker >= 24
- Docker Compose >= 2.20
- 4 Go RAM minimum

**Option locale (dev) :**
- Python >= 3.11
- PostgreSQL >= 14
- Flutter SDK >= 3.10
- Android Studio (API 30+)
- Compte Gmail avec mot de passe d'application

---

## 10. Lancement local avec Docker

```bash
# 1. Cloner le projet
git clone https://github.com/sidattBelkhair/PFE.git && cd PFE

# 2. Tout en un (app + SOC)
docker compose up --build

# Ou séparé
docker network create soc-bridge
docker compose -f docker-compose.app.yml up --build -d
docker compose -f docker-compose.soc.yml up -d

# 3. Créer un superadmin
docker compose exec backend python manage.py createsuperuser
```

| Service | URL | Identifiants |
|---------|-----|-------------|
| API REST | http://localhost:8000/api/ | — |
| Swagger | http://localhost:8000/api/docs/ | — |
| Admin Django | http://localhost:8000/admin/ | superuser |
| Grafana SOC | http://localhost:3000 | admin / SedadSOC2024! |
| Loki | http://localhost:3100 | — |

---

## 11. Déploiement Production

### Backend — DigitalOcean

```bash
# Variables d'environnement sur le serveur
SECRET_KEY=votre-cle-secrete-production
DEBUG=False
ALLOWED_HOSTS=104.248.61.147
DATABASE_URL=postgres://user:pass@localhost:5432/rssbank
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=VOTRE_APP_PASSWORD
LOKI_URL=https://USER:KEY@logs-prod-XXX.grafana.net

python manage.py migrate
python manage.py collectstatic --noinput
gunicorn fintech_bank.wsgi:application --bind 0.0.0.0:8000
```

### SSO Backend — Render

Le SSO tourne comme service séparé sur Render.
Pour accéder au shell Render et vérifier la configuration OAuth :

```bash
python manage.py shell -c "
from oauth2_provider.models import Application
for a in Application.objects.all():
    print(a.client_id, '|', a.redirect_uris)
"
```

### SOC — Grafana Cloud

1. Créer un compte sur **grafana.com** → plan Free (10 GB logs/mois)
2. Récupérer les credentials Loki (URL + User ID + API Key)
3. Ajouter dans `.env` : `LOKI_URL=https://USER:KEY@logs-prod-XXX.grafana.net`

### APK Flutter (release)

```bash
cd frontend/sedad_bank
flutter build apk --release
# APK : build/app/outputs/flutter-apk/app-release.apk (~22 MB)

# Installer directement sur téléphone Android (WiFi)
flutter run -d "adb-XXXX._adb-tls-connect._tcp" --release
```

---

## 12. Configuration Email Gmail

1. **myaccount.google.com** → Sécurité → Validation en deux étapes
2. Sécurité → **Mots de passe des applications** → `RSS BANK`
3. Copier les 16 caractères dans `.env` :

```env
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=abcd efgh ijkl mnop
```

> Sans credentials valides : le code OTP s'affiche dans le terminal Django.

---

## 13. API Reference complète

**Base URL production :** `http://104.248.61.147:8000/api/`

> Toutes les routes sauf `/auth/` nécessitent : `Authorization: Bearer <access_token>`

### 13.1 Authentification & OTP

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/auth/register/` | Inscription → envoie OTP email |
| POST | `/auth/verify-email/` | Vérifier OTP inscription |
| POST | `/auth/resend-otp/` | Renvoyer OTP |
| POST | `/auth/login/` | Connexion → retourne JWT |
| POST | `/auth/token/refresh/` | Rafraîchir access token |
| POST | `/auth/forgot-password/` | Envoie OTP reset |
| POST | `/auth/reset-password/` | Réinitialiser mot de passe |
| POST | `/auth/sso-login/` | **Connexion via SSO** → retourne JWT RSS Bank |

#### Inscription
```bash
curl -X POST http://104.248.61.147:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@rss.mr",
    "password": "MotDePasse123!",
    "password_confirm": "MotDePasse123!",
    "first_name": "Mohamed",
    "last_name": "Diallo",
    "phone_number": "+22200000001"
  }'
```

#### Connexion classique
```bash
curl -X POST http://104.248.61.147:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "test@rss.mr", "password": "MotDePasse123!"}'
```

#### Connexion SSO
```bash
curl -X POST http://104.248.61.147:8000/api/auth/sso-login/ \
  -H "Content-Type: application/json" \
  -d '{"sso_access_token": "<token_obtenu_du_SSO_backend>"}'
```

### 13.2 Utilisateurs

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/users/me/` | Profil courant |
| PATCH | `/users/{id}/` | Modifier profil |
| POST | `/users/change_password/` | Changer mot de passe |
| PATCH | `/users/{id}/update-status/` | Modifier statut (admin) |

### 13.3 Comptes bancaires

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/accounts/` | Lister mes comptes |
| POST | `/accounts/` | Créer un compte |
| POST | `/accounts/{id}/deposit/` | Recharger un compte |

### 13.4 Transactions

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/transactions/` | Transactions envoyées |
| POST | `/transactions/` | Créer une transaction |
| GET | `/transactions/received/` | Transactions reçues |

Types : `transfer` · `payment` · `withdrawal` · `deposit` · `salary`

---

## 14. Application Flutter

### Navigation (5 onglets)

| Onglet | Route | Description |
|--------|-------|-------------|
| Accueil | `/home` | Carte bancaire + 6 services rapides |
| Historique | `/history` | Transactions filtrées par date |
| QR | `/qr-transactions` | Générer / Partager / Scanner QR |
| Ma Banque | `/ma-banque` | Mes comptes + création |
| Profil | `/profile` | Infos + MDP + langue |

### Écrans d'authentification

| Route | Écran |
|-------|-------|
| `/login` | Connexion (JWT ou SSO) |
| `/register` | Inscription étape 1 |
| `/register-step2` | Inscription étape 2 |
| `/verify-email` | Code OTP 6 chiffres + timer |
| `/forgot-password` | Email pour reset |
| `/reset-password` | OTP + nouveau mot de passe |

### State Management (Provider)

| Provider | Rôle |
|----------|------|
| `AuthProvider` | Session JWT, login, register, OTP, SSO, changePassword |
| `AccountProvider` | Liste comptes, création, sélection active |
| `TransactionProvider` | Transactions envoyées + reçues, création |
| `UserProvider` | Liste utilisateurs (admin) |
| `LanguageProvider` | Locale FR/AR, persistance SharedPreferences |

### Services

| Service | Rôle |
|---------|------|
| `ApiService` | Client HTTP Dio — `104.248.61.147:8000` |
| `SSOService` | Flow OAuth2 PKCE via `flutter_appauth` |

### Dépendances principales

```yaml
dio: ^5.4.0                # Client HTTP
provider: ^6.1.1           # State management
go_router: ^13.0.0         # Navigation
flutter_appauth: ^6.0.0    # SSO OAuth2 PKCE
flutter_secure_storage: ^9.0.0  # Stockage tokens SSO
qr_flutter: ^4.1.0         # Génération QR Code
mobile_scanner: ^3.5.6     # Scan QR Code
flutter_localizations       # FR + AR (RTL)
```

---

## 15. Multi-langue FR / AR

L'app supporte le **Français** et l'**Arabe** avec direction **RTL automatique**.

- Onglet **Profil** → carte Langue → boutons FR / AR
- Le choix est **sauvegardé** et restauré au prochain lancement

```
frontend/sedad_bank/lib/l10n/
├── app_fr.arb    ← Français (80+ clés)
└── app_ar.arb    ← Arabe (80+ clés)
```

---

## 16. Tests de sécurité

### Script d'attaque complet

```bash
chmod +x hack.sh

# En local
./hack.sh

# Contre le backend production
./hack.sh http://104.248.61.147:8000
```

Le script teste : Reconnaissance, Brute Force (25 mots), SQL Injection (12 payloads), XSS (6 payloads), Path Traversal, Bypass Auth.

### Tests manuels rapides

```bash
BASE=http://104.248.61.147:8000

# Brute force (déclenche alerte après 5 tentatives)
for i in {1..6}; do
  curl -s -X POST $BASE/api/auth/login/ \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"test@test.com\",\"password\":\"wrong$i\"}"
done

# SQL Injection
curl "$BASE/api/transactions/?search=1'+OR+'1'='1"

# XSS
curl -X POST $BASE/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"<script>alert(1)</script>","password":"x"}'

# Path Traversal
curl "$BASE/api/../../../etc/passwd"
```

### Observer les logs SOC en direct

```bash
# Local
tail -f backend/logs/security.log | python -m json.tool

# Docker
docker logs -f pfe-backend-1
```

---

## 17. Structure du projet

```
PFE/
├── docker-compose.yml              # Orchestration complète (7 services)
├── docker-compose.app.yml          # App seule (DB + Backend + Frontend + Promtail)
├── docker-compose.soc.yml          # SOC seul (Loki + Grafana + Fail2ban)
├── hack.sh                         # Script de test sécurité complet
├── README.md
│
├── backend/                        # API Django REST Framework
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── .env                        # DB + Email + Loki
│   ├── logs/
│   │   ├── security.log            # Événements SOC (JSON)
│   │   ├── access.log              # Requêtes HTTP (JSON)
│   │   └── django.log
│   ├── fintech_bank/
│   │   ├── settings.py
│   │   └── urls.py
│   └── apps/core/
│       ├── models.py               # User, Account, Transaction, Card, Beneficiary
│       ├── views.py                # ViewSets + OTP + Auth + SSO Login
│       ├── serializers.py
│       ├── urls.py
│       └── security_middleware.py  # Détection SQL/XSS/BruteForce + ML → JSON
│
├── frontend/sedad_bank/            # Application Flutter
│   ├── android/
│   │   └── app/src/main/
│   │       └── AndroidManifest.xml # Redirect URI SSO OAuth2
│   └── lib/
│       ├── main.dart
│       ├── l10n/                   # Traductions FR + AR
│       ├── core/services/
│       │   ├── api_service.dart    # Client HTTP Dio
│       │   └── sso_service.dart    # Flow OAuth2 PKCE
│       ├── providers/              # Auth, Account, Transaction, User, Language
│       ├── routes/app_routes.dart  # GoRouter + garde auth
│       ├── widgets/                # BankCard, MainShell, AppDrawer
│       └── screens/
│           ├── auth/               # Login, Register, OTP, Reset, SSO
│           ├── home/
│           ├── transactions/
│           ├── qr/
│           ├── profile/
│           ├── bank/
│           └── admin/
│
└── soc/                            # Security Operations Center
    ├── loki.yml
    ├── promtail.yml
    ├── fail2ban/
    │   ├── jail.local              # 4 règles de bannissement
    │   └── filter.d/               # Filtres regex par type d'attaque
    └── grafana/
        ├── grafana.ini             # Config SMTP alertes
        └── provisioning/
            ├── datasources/        # Connexion Loki
            ├── alerting/           # Règles alertes + policies email
            └── dashboards/         # Dashboard RSS BANK SOC (JSON)
```

---

*RSS BANK — Projet de Fin d'Études | 2025-2026*
*Application bancaire digitale mobile pour la Mauritanie — Devise : MRU (Ouguiya Mauritanien)*
*Stack : Flutter · Django · OAuth2/SSO · Grafana · ML Anomaly Detection*
