# RSS BANK — Application Bancaire Mobile + SOC Multi-App

> Projet de Fin d'Études (PFE) — Application bancaire mobile complète avec système SOC centralisé multi-applications

---

## Table des matières

1. [Présentation](#1-présentation)
2. [Architecture Globale](#2-architecture-globale)
3. [SOC Multi-Applications](#3-soc-multi-applications)
4. [Modèles de données (ERD)](#4-modèles-de-données-erd)
5. [Diagrammes de conception](#5-diagrammes-de-conception)
6. [Prérequis](#6-prérequis)
7. [Lancement local avec Docker](#7-lancement-local-avec-docker)
8. [Déploiement Production](#8-déploiement-production)
9. [Configuration Email Gmail](#9-configuration-email-gmail)
10. [API Reference complète](#10-api-reference-complète)
11. [Application Flutter](#11-application-flutter)
12. [Multi-langue FR / AR](#12-multi-langue-fr--ar)
13. [Tests de sécurité](#13-tests-de-sécurité)
14. [Structure du projet](#14-structure-du-projet)

---

## 1. Présentation

**RSS BANK** est une plateforme bancaire mobile développée dans le cadre d'un Projet de Fin d'Études. Elle est couplée à un **SOC (Security Operations Center) centralisé** capable de surveiller plusieurs applications bancaires simultanément.

### Fonctionnalités principales

- **Inscription** avec vérification email par code OTP (6 chiffres, expire en 10 min)
- **Mot de passe oublié** → OTP par email → réinitialisation
- Gestion de comptes bancaires (courant / épargne) en **MRU** (Ouguiya Mauritanien)
- Virements via numéro de téléphone ou **QR Code**
- Services : recharge, retraits, paiements, factures
- Authentification **JWT** avec protection anti brute-force
- **Multi-langue Français / Arabe** (RTL automatique)
- **SOC** : Loki + Promtail + Grafana + Fail2ban
- Détection automatique : SQL Injection, XSS, Path Traversal, Brute Force
- Dashboard administrateur (gestion des statuts utilisateurs)

---

## 2. Architecture Globale

```
┌─────────────────────────────────────────────────────────────────────┐
│                        RSS BANK — PFE                             │
├─────────────────────┬──────────────────────┬────────────────────────┤
│   Frontend Flutter  │   Backend Django     │   SOC / Monitoring     │
│   Android / iOS     │   REST API + JWT     │   Loki + Grafana       │
│   Port 80           │   Port 8000          │   Port 3000 / 3100     │
├─────────────────────┴──────────────────────┤                        │
│           PostgreSQL / SQLite              │   Fail2ban             │
│           Port 5432                        │   iptables             │
└────────────────────────────────────────────┴────────────────────────┘
```

### Stack technique

| Composant | Technologie | Version |
|-----------|-------------|---------|
| Frontend | Flutter + Provider + GoRouter | 3.x |
| Backend | Django REST Framework | 4.2.7 |
| Base de données | PostgreSQL (prod) / SQLite (dev) | 15 / builtin |
| Auth | JWT (SimpleJWT) | 60min access / 1j refresh |
| Email OTP | Gmail SMTP | — |
| Collecte logs | Promtail | 2.9.0 |
| Stockage logs | Loki | 2.9.0 |
| Dashboard SOC | Grafana | 10.2.0 |
| Blocage IP | Fail2ban | latest |
| Serveur | Gunicorn | 21.2.0 |

---

## 3. SOC Multi-Applications

### Concept

Le SOC est conçu comme une **plateforme centralisée** indépendante des applications qu'il surveille. Il peut recevoir les logs de **plusieurs applications bancaires** différentes simultanément.

```
┌──────────────────┐     logs JSON      ┌─────────────────────────────┐
│  RSS BANK      │ ────────────────►  │                             │
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
└──────────────────┘                    │                             │
                                        │  Alertes → Email SOC Team  │
                                        └─────────────────────────────┘
```

### Comment ajouter une nouvelle application au SOC

Chaque application doit simplement envoyer ses logs au format JSON vers le endpoint Loki :

```
POST http://SOC_SERVER:3100/loki/api/v1/push
```

**Format du log requis :**
```json
{
  "ts": "2026-04-02T10:30:00Z",
  "event": "BRUTE_FORCE",
  "ip": "192.168.1.1",
  "app": "nom_de_lapplication",
  "method": "POST",
  "path": "/api/auth/login/",
  "status": 401
}
```

**En Python (Django) :**
```python
pip install python-logging-loki

# Dans settings.py
LOGGING['handlers']['loki'] = {
    'class': 'logging_loki.LokiHandler',
    'url': 'http://SOC_SERVER:3100/loki/api/v1/push',
    'tags': {'app': 'mon_app', 'env': 'production'},
    'version': '1',
}
```

**En Node.js (Express) :**
```javascript
const { createLogger } = require('winston');
const LokiTransport = require('winston-loki');

const logger = createLogger({
  transports: [new LokiTransport({ host: 'http://SOC_SERVER:3100' })]
});
```

### Événements détectés (tous types d'apps)

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

### Alertes email (Grafana)

| Alerte | Déclencheur | Délai |
|--------|-------------|-------|
| Brute Force | > 1 événement / 5 min | Immédiat |
| SQL Injection | > 0 événement | Immédiat |
| XSS | > 0 événement | Immédiat |
| Pic 401 | > 5 en 5 min | 5 min |
| Pic 500 | > 3 en 5 min | 5 min |

---

## 4. Modèles de données (ERD)

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
│ PK  id              : AutoField                                      │
│ FK  user            : User                                           │
│     verified_email  : BooleanField                                   │
│     verified_phone  : BooleanField                                   │
│     otp_code        : CharField(6)   ← OTP vérification/reset       │
│     otp_expires_at  : DateTimeField  ← Expire dans 10 min           │
│     otp_type        : ENUM [verify_email, reset_password]            │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                         ACCOUNT                                     │
├─────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                          │
│ FK  user            : User (CASCADE)                                │
│     account_number  : CharField (unique) ← Format: RSSxxxxxxxx     │
│     account_name    : CharField                                     │
│     account_type    : ENUM [checking, savings]                      │
│     currency        : ENUM [MRU, DZD, USD, EUR]                    │
│     balance         : DecimalField(15,2)                            │
│     available_balance : DecimalField(15,2)                          │
│     status          : ENUM [active, frozen, closed]                 │
│     daily_withdrawal_limit  : DecimalField  (défaut: 5 000)        │
│     daily_transfer_limit    : DecimalField  (défaut: 10 000)       │
└──────────────┬──────────────────────────────┬───────────────────────┘
               │ FK from_account              │ FK to_account
               ▼                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        TRANSACTION                                  │
├─────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                          │
│ FK  from_account    : Account (PROTECT)                             │
│ FK  to_account      : Account (PROTECT, nullable)                   │
│ FK  to_beneficiary  : Beneficiary (SET_NULL, nullable)              │
│     transaction_type: ENUM [transfer, payment, withdrawal,          │
│                              deposit, salary]                       │
│     amount          : DecimalField(15,2)                            │
│     transaction_fee : DecimalField(10,2)                            │
│     total_amount    : DecimalField(15,2)                            │
│     reference_number: CharField (unique) ← Format: TXNxxxxxxxx     │
│     status          : ENUM [pending, processing, completed,         │
│                              failed, reversed]                      │
│     is_flagged      : BooleanField   ← Fraude détectée             │
│     fraud_score     : IntegerField                                  │
│     ip_address      : GenericIPAddressField  ← Pour SOC             │
│     created_at      : DateTimeField                                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        TRANSACTION HISTORY                          │
├─────────────────────────────────────────────────────────────────────┤
│ PK  id              : AutoField                                     │
│ FK  transaction     : Transaction (CASCADE)                         │
│ FK  changed_by      : User (SET_NULL)                               │
│     status_before   : CharField                                     │
│     status_after    : CharField                                     │
│     reason          : TextField                                     │
│     changed_at      : DateTimeField                                 │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                          CARD                                       │
├─────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                          │
│ FK  account         : Account (CASCADE)                             │
│     card_type       : ENUM [debit, credit, virtual]                 │
│     card_brand      : ENUM [VISA, MASTERCARD, AMEX]                 │
│     last_four_digits: CharField(4)                                  │
│     card_number_hash: CharField (sécurisé)                          │
│     status          : ENUM [active, suspended, expired, blocked]    │
│     daily_spending_limit   : DecimalField                           │
│     monthly_spending_limit : DecimalField                           │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        BENEFICIARY                                  │
├─────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                          │
│ FK  user            : User (CASCADE)                                │
│     beneficiary_name: CharField                                     │
│     beneficiary_type: ENUM [internal, external]                     │
│     account_number  : CharField                                     │
│     phone_number    : CharField                                     │
│     bank_name       : CharField                                     │
│     is_verified     : BooleanField                                  │
└─────────────────────────────────────────────────────────────────────┘
```

### Relations entre modèles

```
User ──────────── UserProfile     (1:1)
User ──────────── Account         (1:N)  un user → plusieurs comptes
User ──────────── Beneficiary     (1:N)  un user → plusieurs bénéficiaires
Account ────────── Card            (1:N)  un compte → plusieurs cartes
Account ────────── Transaction     (1:N)  via from_account et to_account
Transaction ────── TransactionHistory (1:N)  historique des changements de statut
```

---

## 5. Diagrammes de conception

### 5.1 Diagramme de cas d'utilisation

```
                    ┌──────────────────────────────────────────┐
                    │              RSS BANK                  │
                    │                                          │
  ┌──────────┐      │  ○ S'inscrire (+ vérif OTP email)       │
  │          │      │  ○ Se connecter (JWT)                    │
  │  CLIENT  │─────►│  ○ Voir solde / carte bancaire           │
  │          │      │  ○ Effectuer un virement                 │
  └──────────┘      │  ○ Scanner / Générer QR Code             │
                    │  ○ Recharger / Retrait / Paiement        │
                    │  ○ Voir historique transactions          │
                    │  ○ Changer mot de passe                  │
                    │  ○ Basculer langue (FR/AR)               │
                    │                                          │
  ┌──────────┐      │  ○ Gérer statuts utilisateurs            │
  │  ADMIN   │─────►│  ○ Voir dashboard admin                  │
  │          │      │  ○ Voir tous les logs SOC                │
  └──────────┘      │                                          │
                    │  ○ Voir alertes sécurité (Grafana)       │
  ┌──────────┐      │  ○ Bloquer IPs malveillantes             │
  │ SOC TEAM │─────►│  ○ Recevoir emails d'alerte              │
  │          │      │  ○ Analyser logs d'attaque               │
  └──────────┘      │                                          │
                    └──────────────────────────────────────────┘
```

### 5.2 Diagramme de séquence — Inscription avec OTP

```
  Client Flutter          Backend Django              Gmail SMTP
       │                        │                          │
       │── POST /register/ ────►│                          │
       │                        │ génère OTP (6 chiffres)  │
       │                        │── send_mail() ──────────►│
       │                        │                          │── email → Client
       │◄── 201 pending_verif ──│                          │
       │                        │                          │
       │ (Client reçoit email)  │                          │
       │                        │                          │
       │── POST /verify-email/ ─►│                          │
       │   {email, code: "XXXX"} │                          │
       │                        │ vérifie OTP + expiry     │
       │◄── 200 "Email vérifié" ─│                          │
       │                        │                          │
       │── POST /login/ ────────►│                          │
       │◄── {access, refresh} ──│                          │
```

### 5.3 Diagramme de séquence — Détection d'attaque SOC

```
  Attaquant          Django Backend         Loki          Grafana       Email
      │                    │                 │               │             │
      │── 6x POST /login/ ─►│                │               │             │
      │   (mauvais mdp)     │                │               │             │
      │                    │ détecte BF     │               │             │
      │                    │─ log JSON ─────►│               │             │
      │◄── 401 ────────────│                │               │             │
      │                    │                │◄── query ─────│             │
      │                    │                │─── données ───►│             │
      │                    │                │               │─ alerte ───►│
      │                    │                │               │             │
      │                    │ Fail2ban lit security.log      │             │
      │                    │ iptables block IP              │             │
      │ (connexion refusée)│                │               │             │
```

### 5.4 Architecture de déploiement production

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INTERNET                                         │
└──────────┬───────────────────────────────────┬──────────────────────┘
           │ HTTPS                             │ HTTPS
           ▼                                   ▼
┌────────────────────┐               ┌──────────────────────┐
│  PythonAnywhere    │               │   Grafana Cloud       │
│                    │  logs JSON    │   (SOC)               │
│  rssbank.          │──────────────►│                       │
│  pythonanywhere.com│               │  Loki (10GB gratuit)  │
│                    │               │  Grafana Dashboard    │
│  Django REST API   │               │  Alertes Email        │
│  SQLite DB         │               └──────────────────────┘
│  Gunicorn          │
└────────────────────┘
           ▲
           │ requêtes API
           │
┌────────────────────┐
│  APK Flutter       │
│  (téléphones amis) │
│                    │
│  baseUrl =         │
│  pythonanywhere.com│
└────────────────────┘
```

---

## 6. Prérequis

**Option Docker (local) :**
- Docker >= 24
- Docker Compose >= 2.20
- 4 Go RAM minimum

**Option locale (dev) :**
- Python >= 3.11
- PostgreSQL >= 14
- Flutter SDK >= 3.0
- Android Studio + émulateur (API 30+)
- Compte Gmail avec mot de passe d'application

---

## 7. Lancement local avec Docker

```bash
# 1. Cloner le projet
git clone https://github.com/sidattBelkhair/PFE.git && cd PFE

# 2. Option A — Tout en un (app + SOC)
docker compose up --build

# 2. Option B — Séparé
docker network create soc-bridge
docker compose -f docker-compose.app.yml up --build -d
docker compose -f docker-compose.soc.yml up -d

# 3. Créer un superadmin
docker compose exec backend python manage.py createsuperuser
```

### Services disponibles

| Service | URL | Identifiants |
|---------|-----|-------------|
| API REST | http://localhost:8000/api/ | — |
| Documentation Swagger | http://localhost:8000/api/docs/ | — |
| Admin Django | http://localhost:8000/admin/ | superuser |
| App Web Flutter | http://localhost:80 | — |
| Grafana SOC | http://localhost:3000 | admin / SedadSOC2024! |
| Loki | http://localhost:3100 | — |

---

## 8. Déploiement Production

### Backend — PythonAnywhere (gratuit)

```bash
# Sur PythonAnywhere Bash Console
git clone https://github.com/sidattBelkhair/PFE.git
cd PFE/backend
python3.11 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# Créer .env
cat > .env << 'EOF'
SECRET_KEY=votre-cle-secrete-production
DEBUG=False
ALLOWED_HOSTS=rssbank.pythonanywhere.com
DB_ENGINE=django.db.backends.sqlite3
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=VOTRE_APP_PASSWORD
LOKI_URL=
EOF

python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser
```

WSGI file (`/var/www/rssbank_pythonanywhere_com_wsgi.py`) :
```python
import os, sys
path = '/home/rssbank/PFE/backend'
if path not in sys.path:
    sys.path.insert(0, path)
os.environ['DJANGO_SETTINGS_MODULE'] = 'fintech_bank.settings'
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
```

URL : `https://rssbank.pythonanywhere.com/api/`

### SOC — Grafana Cloud (gratuit)

1. Créer un compte sur **grafana.com** → plan Free (10GB logs/mois)
2. Récupérer les credentials Loki (URL + User ID + API Key)
3. Ajouter dans `backend/.env` : `LOKI_URL=https://USER:KEY@logs-prod-XXX.grafana.net`
4. Dashboard accessible depuis n'importe où

### APK Flutter

```bash
cd frontend/sedad_bank
# baseUrl déjà configuré sur rssbank.pythonanywhere.com
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

## 9. Configuration Email Gmail

1. Aller sur **myaccount.google.com**
2. Sécurité → activer **Validation en deux étapes**
3. Sécurité → **Mots de passe des applications** → `RSS BANK`
4. Google génère **16 caractères** → copier dans `.env` :

```env
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=abcd efgh ijkl mnop
```

> Sans credentials valides : Django affiche le code OTP dans le terminal (mode console).

---

## 10. API Reference complète

**Base URL :** `https://rssbank.pythonanywhere.com/api/`

> Toutes les routes sauf `/auth/` nécessitent : `Authorization: Bearer <access_token>`

### 10.1 Authentification & OTP

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/auth/register/` | Inscription → envoie OTP email |
| POST | `/api/auth/verify-email/` | Vérifier OTP inscription |
| POST | `/api/auth/resend-otp/` | Renvoyer OTP |
| POST | `/api/auth/login/` | Connexion → retourne JWT |
| POST | `/api/auth/token/refresh/` | Rafraîchir access token |
| POST | `/api/auth/forgot-password/` | Envoie OTP reset |
| POST | `/api/auth/reset-password/` | Réinitialiser mot de passe |

#### Inscription
```bash
curl -X POST https://rssbank.pythonanywhere.com/api/auth/register/ \
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

#### Connexion
```bash
curl -X POST https://rssbank.pythonanywhere.com/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "test@rss.mr", "password": "MotDePasse123!"}'
```

### 10.2 Utilisateurs

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/users/me/` | Profil courant |
| PATCH | `/api/users/{id}/` | Modifier profil |
| POST | `/api/users/change_password/` | Changer mot de passe |
| PATCH | `/api/users/{id}/update-status/` | Modifier statut (admin) |

### 10.3 Comptes bancaires

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/accounts/` | Lister mes comptes |
| POST | `/api/accounts/` | Créer un compte |
| POST | `/api/accounts/{id}/deposit/` | Recharger un compte |

### 10.4 Transactions

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/transactions/` | Transactions envoyées |
| POST | `/api/transactions/` | Créer une transaction |
| GET | `/api/transactions/received/` | Transactions reçues |

Types de transaction : `transfer` · `payment` · `withdrawal` · `deposit` · `salary`

---

## 11. Application Flutter

### Navigation (5 onglets)

| Onglet | Route | Description |
|--------|-------|-------------|
| Accueil | `/home` | Carte bancaire + 6 services |
| Historique | `/history` | Transactions filtrées par date |
| QR | `/qr-transactions` | Générer / Partager / Scanner |
| Ma Banque | `/ma-banque` | Comptes + création |
| Profil | `/profile` | Infos + MDP + langue |

### Écrans d'authentification

| Route | Écran |
|-------|-------|
| `/login` | Connexion |
| `/register` | Inscription |
| `/verify-email` | Code OTP 6 chiffres + timer |
| `/forgot-password` | Email pour reset |
| `/reset-password` | OTP + nouveau mot de passe |

### State Management (Provider)

| Provider | Rôle |
|----------|------|
| `AuthProvider` | Session JWT, login, register, OTP, changePassword |
| `AccountProvider` | Liste comptes, création, sélection |
| `TransactionProvider` | Transactions envoyées + reçues, création |
| `UserProvider` | Liste utilisateurs (admin) |
| `LanguageProvider` | Locale FR/AR, persistance SharedPreferences |

---

## 12. Multi-langue FR / AR

L'app supporte le **Français** et l'**Arabe** avec direction **RTL automatique**.

### Changer la langue
- Onglet **Profil** → carte Langue → boutons FR / AR
- Le choix est **sauvegardé** et restauré au prochain lancement

### Fichiers de traduction
```
frontend/sedad_bank/lib/l10n/
├── app_fr.arb    ← Français (80+ clés)
└── app_ar.arb    ← Arabe (80+ clés)
```

---

## 13. Tests de sécurité

### Lancer le script d'attaque complet
```bash
chmod +x hack.sh

# En local
./hack.sh

# Contre PythonAnywhere
./hack.sh https://rssbank.pythonanywhere.com
```

Le script teste : Reconnaissance, Brute Force (25 mots), SQL Injection (12 payloads), XSS (6 payloads), Path Traversal, Bypass Auth.

### Tests manuels rapides

```bash
BASE=https://rssbank.pythonanywhere.com

# Brute force (déclenche alerte après 5)
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

## 14. Structure du projet

```
PFE/
├── docker-compose.yml              # Orchestration complète (7 services)
├── docker-compose.app.yml          # App seule (DB + Backend + Frontend + Promtail)
├── docker-compose.soc.yml          # SOC seul (Loki + Grafana + Fail2ban)
├── .env                            # SMTP Grafana
├── hack.sh                         # Script de test sécurité
├── README.md                       # Ce fichier
│
├── backend/                        # API Django REST Framework
│   ├── Dockerfile
│   ├── run.sh                      # Migrations auto + gunicorn
│   ├── requirements.txt
│   ├── .env                        # DB + Email + Loki
│   ├── logs/
│   │   ├── security.log            # Événements SOC (JSON)
│   │   ├── access.log              # Requêtes HTTP (JSON)
│   │   └── django.log              # Logs applicatifs
│   ├── fintech_bank/
│   │   ├── settings.py             # Config Django complète
│   │   └── urls.py
│   └── apps/core/
│       ├── models.py               # User, Account, Transaction, Card, Beneficiary
│       ├── views.py                # ViewSets + OTP + Auth
│       ├── serializers.py
│       ├── urls.py
│       └── security_middleware.py  # Détection SQL/XSS/BruteForce → JSON
│
├── frontend/sedad_bank/            # Application Flutter
│   └── lib/
│       ├── main.dart               # Point d'entrée, session JWT
│       ├── l10n/                   # Traductions FR + AR
│       ├── core/services/api_service.dart
│       ├── providers/              # Auth, Account, Transaction, User, Language
│       ├── routes/app_routes.dart  # GoRouter + garde auth
│       ├── widgets/                # BankCard, MainShell, AppDrawer
│       └── screens/               # auth/, home/, transactions/, qr/, profile/...
│
└── soc/                            # Security Operations Center
    ├── loki.yml                    # Config stockage logs
    ├── promtail.yml                # Collecte logs → Loki
    ├── promtail-local.yml
    ├── fail2ban/
    │   ├── jail.local              # 4 règles de bannissement
    │   └── filter.d/               # Filtres regex par type d'attaque
    └── grafana/
        ├── grafana.ini             # Config SMTP alertes
        └── provisioning/
            ├── datasources/        # Connexion Loki
            ├── alerting/           # 5 règles d'alertes + policies email
            └── dashboards/         # Dashboard RSS BANK SOC (JSON)
```

---

*RSS BANK — Projet de Fin d'Études | 2025-2026*
*Application bancaire digitale mobile pour la Mauritanie — Devise : MRU (Ouguiya Mauritanien)*
*SOC centralisé multi-applications — Loki + Grafana + Fail2ban*
