# RSS BANK — Application Bancaire Mobile + SOC Multi-Applications

> **Projet de Fin d'Études (PFE) 2025-2026**  
> Application bancaire mobile complète avec SOC centralisé capable de surveiller plusieurs applications simultanément.  
> Stack : Flutter · Django · JWT · Loki · Grafana · Fail2ban · ML Anomaly Detection

---

## Table des matières

**Application**
1. [Présentation](#1-présentation)
2. [Architecture globale](#2-architecture-globale)
3. [Modèles de données (ERD)](#3-modèles-de-données-erd)
4. [Diagrammes de conception](#4-diagrammes-de-conception)
5. [Prérequis](#5-prérequis)
6. [Lancement avec Docker](#6-lancement-avec-docker)
7. [Déploiement production](#7-déploiement-production)
8. [Configuration email](#8-configuration-email)
9. [API Reference](#9-api-reference)
10. [Application Flutter](#10-application-flutter)
11. [Multi-langue FR / AR](#11-multi-langue-fr--ar)

**SOC — Security Operations Center**

12. [SOC — Architecture & flux de données](#12-soc--architecture--flux-de-données)
13. [SOC — Déploiement du serveur SOC](#13-soc--déploiement-du-serveur-soc)
14. [SOC — Intégration d'une nouvelle application](#14-soc--intégration-dune-nouvelle-application)
15. [SOC — Dashboards Grafana](#15-soc--dashboards-grafana)
16. [SOC — Alertes email (Brevo)](#16-soc--alertes-email-brevo)
17. [SOC — Fail2ban (blocage IP)](#17-soc--fail2ban-blocage-ip)
18. [SOC — ML Anomaly Detector](#18-soc--ml-anomaly-detector)
19. [SOC — Tests d'attaque](#19-soc--tests-dattaque)
20. [SOC — Référence des événements](#20-soc--référence-des-événements)
21. [SOC — Dépannage](#21-soc--dépannage)

**Projet**

22. [Structure du projet](#22-structure-du-projet)

---

## 1. Présentation

**RSS BANK** est une plateforme bancaire mobile développée dans le cadre d'un PFE. Elle est couplée à un **SOC centralisé** capable de surveiller plusieurs applications bancaires en simultané.

### Fonctionnalités bancaires

- Inscription avec vérification email par **OTP** (6 chiffres, expire en 10 min)
- Mot de passe oublié → OTP → réinitialisation sécurisée
- Gestion de comptes bancaires (courant / épargne) en **MRU** (Ouguiya Mauritanien)
- Virements via numéro de téléphone ou **QR Code**
- Services : recharge, retraits, paiements, factures
- Authentification **JWT** (access 60 min / refresh 1 jour)
- **Multi-langue Français / Arabe** avec RTL automatique
- Dashboard administrateur (gestion des statuts utilisateurs)

### Fonctionnalités SOC

- Détection temps réel : **SQL Injection, XSS, Path Traversal, Brute Force**
- Push automatique des logs vers **Loki** (thread background, batch toutes les 2s)
- Dashboard **Grafana** isolé par application
- Alertes email par application via **Brevo SMTP** (300 mails/jour gratuit)
- Blocage IP automatique via **Fail2ban + iptables**
- Détection comportementale par **Machine Learning** (IsolationForest, 8 features)
- Support **multi-applications** : chaque app Django se connecte avec une variable `RSS_SOC_APP_NAME`

---

## 2. Architecture globale

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           RSS BANK — PFE                                 │
├───────────────────────┬──────────────────────┬───────────────────────────┤
│   Frontend Flutter    │   Backend Django      │   SOC / Monitoring        │
│   Android / iOS       │   REST API + JWT      │   Loki + Grafana          │
│   Port 80             │   Port 8000           │   Port 3000 / 3100        │
├───────────────────────┴──────────────────────┤                           │
│           PostgreSQL / SQLite                │   Fail2ban                │
│           Port 5432                          │   ML Anomaly Detector     │
└──────────────────────────────────────────────┴───────────────────────────┘
```

### Stack technique

| Composant | Technologie | Version |
|-----------|-------------|---------|
| Frontend | Flutter + Provider + GoRouter | 3.x |
| Backend | Django REST Framework | 4.2.7 |
| Base de données | PostgreSQL (prod) / SQLite (dev) | 15 / builtin |
| Authentification | JWT (SimpleJWT) | 60 min access / 1j refresh |
| Email OTP | Gmail SMTP | — |
| Stockage logs | Loki | 2.9.0 |
| Dashboard SOC | Grafana | 10.2.0 |
| Alertes email SOC | Brevo SMTP | — |
| Blocage IP | Fail2ban | latest |
| ML détection | scikit-learn IsolationForest | 1.x |
| Serveur | Gunicorn | 21.2.0 |

---

## 3. Modèles de données (ERD)

```
┌──────────────────────────────────────────────────────────────────────┐
│                        USER (AbstractUser)                           │
├──────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                           │
│     email           : CharField (unique)                             │
│     first_name      : CharField                                      │
│     last_name       : CharField                                      │
│     phone_number    : CharField                                      │
│     national_id     : CharField (unique)                             │
│     role            : ENUM [client, admin, agent]                    │
│     status          : ENUM [active, suspended, blocked, closed]      │
│     kyc_status      : ENUM [pending, approved, rejected]             │
│     two_factor_enabled : BooleanField                                │
│     last_login_ip   : GenericIPAddressField                          │
│     login_attempts  : IntegerField                                   │
│     created_at      : DateTimeField                                  │
└─────────────────────────────┬────────────────────────────────────────┘
                              │ OneToOne
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          USER PROFILE                                │
├──────────────────────────────────────────────────────────────────────┤
│ PK  id              : AutoField                                      │
│ FK  user            : User                                           │
│     verified_email  : BooleanField                                   │
│     otp_code        : CharField(6)   ← OTP vérification/reset       │
│     otp_expires_at  : DateTimeField  ← Expire dans 10 min           │
│     otp_type        : ENUM [verify_email, reset_password]            │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                           ACCOUNT                                    │
├──────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                           │
│ FK  user            : User (CASCADE)                                 │
│     account_number  : CharField (unique) ← Format: RSSxxxxxxxx      │
│     account_type    : ENUM [checking, savings]                       │
│     currency        : ENUM [MRU, DZD, USD, EUR]                     │
│     balance         : DecimalField(15,2)                             │
│     status          : ENUM [active, frozen, closed]                  │
│     daily_withdrawal_limit  : DecimalField  (défaut: 5 000 MRU)     │
│     daily_transfer_limit    : DecimalField  (défaut: 10 000 MRU)    │
└─────────────┬────────────────────────────────────┬───────────────────┘
              │ FK from_account                    │ FK to_account
              ▼                                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          TRANSACTION                                 │
├──────────────────────────────────────────────────────────────────────┤
│ PK  id              : UUID                                           │
│     transaction_type: ENUM [transfer, payment, withdrawal,           │
│                              deposit, salary]                        │
│     amount          : DecimalField(15,2)                             │
│     reference_number: CharField (unique) ← Format: TXNxxxxxxxx      │
│     status          : ENUM [pending, processing, completed, failed]  │
│     is_flagged      : BooleanField   ← Fraude détectée              │
│     fraud_score     : IntegerField                                   │
│     ip_address      : GenericIPAddressField  ← Pour SOC             │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                             CARD                                     │
├──────────────────────────────────────────────────────────────────────┤
│ FK  account         : Account (CASCADE)                              │
│     card_type       : ENUM [debit, credit, virtual]                  │
│     card_brand      : ENUM [VISA, MASTERCARD, AMEX]                  │
│     last_four_digits: CharField(4)                                   │
│     card_number_hash: CharField (sécurisé)                           │
│     status          : ENUM [active, suspended, expired, blocked]     │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                          BENEFICIARY                                 │
├──────────────────────────────────────────────────────────────────────┤
│ FK  user            : User (CASCADE)                                 │
│     beneficiary_type: ENUM [internal, external]                      │
│     account_number  : CharField                                      │
│     phone_number    : CharField                                      │
│     is_verified     : BooleanField                                   │
└──────────────────────────────────────────────────────────────────────┘
```

**Relations :**
```
User ─────── UserProfile     (1:1)
User ─────── Account         (1:N)
User ─────── Beneficiary     (1:N)
Account ───── Card            (1:N)
Account ───── Transaction     (1:N)  via from_account / to_account
Transaction ── TransactionHistory (1:N)
```

---

## 4. Diagrammes de conception

### 4.1 Cas d'utilisation

```
                    ┌─────────────────────────────────────────┐
                    │               RSS BANK                  │
  ┌──────────┐      │  ○ S'inscrire (OTP email)               │
  │  CLIENT  │─────►│  ○ Se connecter (JWT)                   │
  └──────────┘      │  ○ Voir solde / carte bancaire          │
                    │  ○ Effectuer un virement / QR Code      │
                    │  ○ Recharge / Retrait / Paiement        │
                    │  ○ Voir historique transactions         │
                    │  ○ Basculer langue FR / AR              │
                    │                                         │
  ┌──────────┐      │  ○ Gérer statuts utilisateurs           │
  │  ADMIN   │─────►│  ○ Voir dashboard admin                 │
  └──────────┘      │  ○ Consulter tous les logs SOC         │
                    │                                         │
  ┌──────────┐      │  ○ Voir alertes Grafana (par app)       │
  │ SOC TEAM │─────►│  ○ Recevoir emails d'alerte             │
  └──────────┘      │  ○ Analyser logs d'attaque             │
                    │  ○ Bloquer IPs via Fail2ban             │
                    └─────────────────────────────────────────┘
```

### 4.2 Séquence — Inscription OTP

```
  Client Flutter        Backend Django           Gmail SMTP
       │                      │                       │
       │── POST /register/ ──►│                       │
       │                      │ génère OTP 6 chiffres │
       │                      │── send_mail() ────────►│── email → Client
       │◄── 201 pending ───── │                       │
       │                      │                       │
       │── POST /verify-email/ {email, code} ────────►│
       │                      │ vérifie OTP + expiry  │
       │◄── 200 vérifié ───── │                       │
       │── POST /login/ ──────►│                       │
       │◄── {access, refresh} │                       │
```

### 4.3 Séquence — Détection d'attaque SOC

```
  Attaquant       Django Middleware        Loki          Grafana       Email
      │                  │                  │               │             │
      │── 6x POST ──────►│                  │               │             │
      │  (mauvais mdp)   │ détecte BF       │               │             │
      │                  │── log JSON ──────►│               │             │
      │◄── 429 / 401 ────│                  │◄── query ─────│             │
      │                  │                  │── données ────►│─ alerte ──►│
      │                  │                  │               │             │
      │      Fail2ban lit security.log → iptables block IP               │
      │ (toutes connexions refusées)                                      │
```

### 4.4 Déploiement production

```
              INTERNET
       ┌──────────┴──────────┐
       │ HTTPS               │ HTTPS
       ▼                     ▼
┌─────────────────┐   ┌──────────────────────┐
│ PythonAnywhere  │   │   SOC (198.199.70.48) │
│                 │logs│                      │
│ Django API      │──►│  Loki  :3100          │
│ SQLite          │   │  Grafana :3000        │
│ Gunicorn        │   │  Fail2ban             │
└─────────────────┘   │  ML Detector          │
        ▲             │  Alertes → Brevo      │
        │ API         └──────────────────────┘
┌─────────────────┐
│  APK Flutter    │
│  (Android)      │
└─────────────────┘
```

---

## 5. Prérequis

**Avec Docker (recommandé) :**
- Docker >= 24
- Docker Compose >= 2.20
- 4 Go RAM minimum

**En local (dev) :**
- Python >= 3.11
- PostgreSQL >= 14
- Flutter SDK >= 3.0
- Android Studio + émulateur API 30+
- Compte Gmail avec mot de passe d'application (pour OTP)

---

## 6. Lancement avec Docker

```bash
# 1. Cloner
git clone https://github.com/sidattBelkhair/PFE.git && cd PFE

# 2. Créer le fichier .env à la racine
cat > .env << 'EOF'
SMTP_HOST=smtp-relay.brevo.com:2525
SMTP_USER=votre@email.com
SMTP_PASSWORD=votre_cle_brevo
SOC_HOST=198.199.70.48
EOF

# 3. Démarrer le SOC (Loki + Grafana)
docker compose -f docker-compose.soc.yml up -d

# 4. Vérifications
curl http://localhost:3100/ready          # → "ready"
curl -s http://localhost:3000/api/health  # → {"database":"ok",...}
```

### Services disponibles

| Service | URL locale | Identifiants |
|---------|-----------|-------------|
| API REST Django | http://localhost:8000/api/ | — |
| Admin Django | http://localhost:8000/admin/ | superuser |
| Grafana SOC | http://localhost:3000 | admin / SedadSOC2024! |
| Loki | http://localhost:3100 | — |

---

## 7. Déploiement production

### Backend — PythonAnywhere

```bash
# Sur PythonAnywhere Bash Console
git clone https://github.com/sidattBelkhair/PFE.git
cd PFE/backend
python3.11 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

cat > .env << 'EOF'
SECRET_KEY=votre-cle-secrete-longue
DEBUG=False
ALLOWED_HOSTS=rssbank.pythonanywhere.com
DB_ENGINE=django.db.backends.sqlite3
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=VOTRE_APP_PASSWORD_GMAIL
RSS_SOC_APP_NAME=rss-bank
RSS_SOC_LOKI_URL=http://198.199.70.48:3100
EOF

python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser
```

Fichier WSGI `/var/www/rssbank_pythonanywhere_com_wsgi.py` :
```python
import os, sys
sys.path.insert(0, '/home/rssbank/PFE/backend')
os.environ['DJANGO_SETTINGS_MODULE'] = 'fintech_bank.settings'
from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
```

### APK Flutter

```bash
cd frontend/sedad_bank
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

## 8. Configuration email

### Gmail — OTP inscription / reset password

1. `myaccount.google.com` → Sécurité → activer **Validation en deux étapes**
2. Sécurité → **Mots de passe des applications** → créer `RSS BANK`
3. Google génère 16 caractères → dans `backend/.env` :

```env
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=abcd efgh ijkl mnop
```

> Sans credentials valides : Django affiche le code OTP dans le terminal (mode console).

### Brevo — Alertes SOC (email Grafana)

1. Créer un compte sur **brevo.com** (gratuit, 300 emails/jour)
2. SMTP & API → Clés API → générer une clé SMTP
3. Dans `.env` à la racine :

```env
SMTP_HOST=smtp-relay.brevo.com:2525
SMTP_USER=votre@email.com
SMTP_PASSWORD=votre_cle_brevo
```

---

## 9. API Reference

**Base URL :** `https://rssbank.pythonanywhere.com/api/`

> Toutes les routes sauf les endpoints d'auth nécessitent : `Authorization: Bearer <access_token>`

### Authentification & OTP

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| POST | `/api/comptes/inscription/` | Inscription → envoie OTP email |
| POST | `/api/comptes/verifier-email/` | Vérifier OTP inscription |
| POST | `/api/comptes/connexion/` | Connexion → retourne JWT |
| POST | `/api/comptes/deconnexion/` | Déconnexion |
| POST | `/api/comptes/token/rafraichir/` | Rafraîchir access token |
| POST | `/api/comptes/mot-de-passe-oublie/` | Envoie OTP reset |
| POST | `/api/comptes/reinitialiser-mdp/` | Réinitialiser mot de passe |

```bash
# Inscription
curl -X POST https://rssbank.pythonanywhere.com/api/comptes/inscription/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","password":"MotDePasse123!","first_name":"Mohamed","phone_number":"+22200000001"}'

# Connexion
curl -X POST https://rssbank.pythonanywhere.com/api/comptes/connexion/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","password":"MotDePasse123!"}'
```

### Comptes bancaires

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/comptes/profil/` | Profil + comptes |
| POST | `/api/comptes/` | Créer un compte |
| POST | `/api/comptes/{id}/recharger/` | Recharger un compte |

### Transactions

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| GET | `/api/transactions/` | Transactions envoyées |
| POST | `/api/transactions/` | Créer une transaction |
| GET | `/api/transactions/recues/` | Transactions reçues |

Types : `transfer` · `payment` · `withdrawal` · `deposit` · `salary`

---

## 10. Application Flutter

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

## 11. Multi-langue FR / AR

L'app supporte le **Français** et l'**Arabe** avec direction **RTL automatique**.

- Onglet **Profil** → carte Langue → boutons FR / AR
- Le choix est sauvegardé et restauré au prochain lancement

```
frontend/sedad_bank/lib/l10n/
├── app_fr.arb    ← Français (80+ clés)
└── app_ar.arb    ← Arabe (80+ clés)
```

---

---

# SOC — Security Operations Center

---

## 12. SOC — Architecture & flux de données

### Architecture multi-applications

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      APPLICATIONS SURVEILLÉES                            │
│                                                                          │
│  ┌──────────────┐   ┌──────────────────┐   ┌──────────────┐             │
│  │  RSS BANK    │   │ financeapp-moulay │   │  trackpay    │  ...        │
│  │  (Django)    │   │  (Django)         │   │  (Django)    │             │
│  │              │   │                   │   │              │             │
│  │ security_    │   │ security_         │   │ security_    │             │
│  │ middleware   │   │ middleware         │   │ middleware   │             │
│  └──────┬───────┘   └────────┬──────────┘   └──────┬───────┘             │
└─────────┼────────────────────┼────────────────────┼──────────────────────┘
          │  HTTP push JSON     │                    │
          └────────────────────┼────────────────────┘
                               │ /loki/api/v1/push
                               ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    SOC CENTRALISÉ (198.199.70.48)                        │
│                                                                          │
│  ┌──────────┐  push   ┌────────────┐  scrape  ┌──────────────────────┐  │
│  │Middleware│ ───────►│    Loki    │ ◄──────── │       Grafana        │  │
│  │(apps)    │         │  :3100     │           │  :3000               │  │
│  └──────────┘         │  7 jours   │           │  Dashboard par app   │  │
│                       └────────────┘           │  Alertes → Brevo     │  │
│                             │                  └──────────────────────┘  │
│                    ┌────────────────┐                                     │
│  ┌─────────────┐   │   Fail2ban     │                                     │
│  │ ML Anomaly  │──►│   iptables     │                                     │
│  │ Detector    │   │   Ban IP auto  │                                     │
│  └─────────────┘   └────────────────┘                                     │
└──────────────────────────────────────────────────────────────────────────┘
```

### Flux de données détaillé

```
Requête HTTP entrante
    │
    ▼
SecurityMiddleware (avant la vue Django)
    ├── Scan RAW_URI   → PATH_TRAVERSAL
    ├── Scan body JSON → SQL_INJECTION, XSS
    ├── IP bannie ?    → 429 immédiat
    └── Après réponse : échec login ? → compteur BRUTE_FORCE
           │
           ▼ (thread daemon, batch toutes les 2 secondes)
       Loki :3100/loki/api/v1/push
       Labels : job="django-security", app="rss-bank", event="SQL_INJECTION"
           │
           ▼
       Grafana scrape Loki
           ├── Dashboard temps réel
           └── Règle d'alerte (sum by app, fenêtre 5 min)
                   │ si > 0 événement
                   ▼
              Email Brevo → équipe SOC
```

### Labels Loki

| Label | Exemple | Rôle |
|-------|---------|------|
| `job` | `django-security` | Identifie les logs sécurité |
| `app` | `rss-bank` | Identifie l'application source |
| `event` | `SQL_INJECTION` | Type d'événement |
| `env` | `prod` | Environnement |

---

## 13. SOC — Déploiement du serveur SOC

```bash
# 1. Créer .env à la racine du projet
cat > .env << 'EOF'
SMTP_HOST=smtp-relay.brevo.com:2525
SMTP_USER=votre@email.com
SMTP_PASSWORD=votre_cle_brevo
SOC_HOST=198.199.70.48
EOF

# 2. Démarrer Loki + Grafana
docker compose -f docker-compose.soc.yml up -d

# 3. Vérifier
curl http://localhost:3100/ready                        # → "ready"
curl -s http://localhost:3000/api/health                # → {"database":"ok"}

# 4. Voir les apps connectées dans Loki
curl -s http://localhost:3100/loki/api/v1/label/app/values | python3 -m json.tool
```

### Services SOC

| Service | URL | Identifiants |
|---------|-----|-------------|
| Grafana | http://198.199.70.48:3000 | admin / SedadSOC2024! |
| Loki | http://198.199.70.48:3100 | — |
| Loki push | http://198.199.70.48:3100/loki/api/v1/push | — |

### Recharger la config Grafana sans redémarrer

```bash
curl -X POST http://admin:SedadSOC2024!@198.199.70.48:3000/api/admin/provisioning/dashboards/reload
curl -X POST http://admin:SedadSOC2024!@198.199.70.48:3000/api/admin/provisioning/alerting/reload
```

---

## 14. SOC — Intégration d'une nouvelle application

### Étape 1 — Copier le middleware

Copier `security_middleware.py` (racine du repo) dans le projet Django de l'ami :

```
monapp/
├── monapp/
│   ├── settings.py
│   ├── urls.py
│   └── security_middleware.py   ← copier ici
└── manage.py
```

### Étape 2 — Configurer settings.py

```python
import os

MIDDLEWARE = [
    'monapp.security_middleware.SecurityMiddleware',  # EN PREMIER
    'django.middleware.security.SecurityMiddleware',
    # ... reste des middlewares Django
]
```

### Étape 3 — Ajouter dans .env

```env
RSS_SOC_APP_NAME=financeapp-moulay   # nom unique, lettres/chiffres/tirets
RSS_SOC_LOKI_URL=http://198.199.70.48:3100
RSS_SOC_ENV=prod
```

### Étape 4 — Table Brute Force (PostgreSQL, optionnel)

```sql
CREATE TABLE rss_soc_login_failures (
    id SERIAL PRIMARY KEY,
    ip VARCHAR(45),
    ts TIMESTAMP DEFAULT NOW()
);
```

> Sans cette table le middleware fonctionne quand même (ban en mémoire uniquement).

### Étape 5 — Créer le dashboard Grafana

```bash
# Sur le serveur SOC
python3 /root/PFE/soc/add_app_dashboard.py financeapp-moulay

# Recharger Grafana
docker compose -f /root/PFE/docker-compose.soc.yml restart grafana
```

Dashboard disponible : `http://198.199.70.48:3000/d/soc-financeapp-moulay`

### Variables d'environnement du middleware

| Variable | Défaut | Description |
|----------|--------|-------------|
| `RSS_SOC_APP_NAME` | `rss-bank` | Nom unique de l'app dans Loki |
| `RSS_SOC_LOKI_URL` | `http://198.199.70.48:3100` | URL Loki |
| `RSS_SOC_ENV` | `prod` | Environnement (prod/dev/staging) |
| `RSS_SOC_DB_TABLE` | `rss_soc_login_failures` | Table PostgreSQL pour les échecs |

### Ce que le middleware détecte automatiquement

| Menace | Technique de détection |
|--------|----------------------|
| SQL Injection | Regex sur body + URL + query string (patterns `SELECT`, `UNION`, `--`, `OR 1=1`, `SLEEP()`…) |
| XSS | Regex (`<script>`, `onerror=`, `javascript:`, `document.cookie`…) |
| Path Traversal | Regex sur l'URI **brute** avant normalisation Django (`../`, `%2e%2e`…) |
| Brute Force | Compteur par IP sur endpoints de connexion (seuil : 5 échecs / 5 min) |

### Endpoints de connexion reconnus (Brute Force)

Tout endpoint POST contenant l'un de ces mots est surveillé :

```
login, auth, signin, sign-in, connexion, connect, session,
token, jwt, oauth, mot-de-passe, password, pwd, credentials, authenticate
```

---

## 15. SOC — Dashboards Grafana

### Dashboards disponibles

| Application | URL |
|-------------|-----|
| RSS BANK (principal) | http://198.199.70.48:3000/d/rss-bank-soc |
| financeapp-moulay | http://198.199.70.48:3000/d/soc-financeapp-moulay |
| trackpay | http://198.199.70.48:3000/d/soc-trackpay |
| nova-sso | http://198.199.70.48:3000/d/soc-nova-sso |

Chaque dashboard est **isolé** pour son application (variable `app` verrouillée en `constant`, cachée). Il affiche :
- Compteurs d'événements (SQLi / XSS / BF / PT) sur les 24h
- Stream de logs en temps réel
- Heatmap des attaques par heure
- Tableau des IPs les plus actives

### Ajouter un dashboard pour une nouvelle app

```bash
python3 /root/PFE/soc/add_app_dashboard.py <app_name>
# Exemple
python3 /root/PFE/soc/add_app_dashboard.py nova-sso
```

Le script duplique le template `soc/grafana/provisioning/dashboards/sedad_bank_soc.json` et verrouille la variable `app`.

---

## 16. SOC — Alertes email (Brevo)

### Règles d'alerte actives

Fichier : `soc/grafana/provisioning/alerting/alerts.yml`

Chaque alerte utilise `sum by (app)` pour être **par application** :

```yaml
expr: 'sum by (app) (count_over_time({job="django-security", event="SQL_INJECTION"}[5m]))'
```

| Alerte | Événement | Sévérité | Délai |
|--------|-----------|----------|-------|
| SQL Injection Detected | `SQL_INJECTION` > 0 / 5 min | critical | Immédiat |
| XSS Attack Detected | `XSS` > 0 / 5 min | high | Immédiat |
| Path Traversal Detected | `PATH_TRAVERSAL` > 0 / 5 min | high | Immédiat |
| Brute Force Attack | `BRUTE_FORCE` > 0 / 5 min | critical | Immédiat |

### Exemple d'email reçu

```
Sujet  : [FIRING] SQL Injection sur financeapp-moulay
Corps  : 13 tentative(s) SQL Injection en 5 min sur financeapp-moulay
         Dashboard : http://198.199.70.48:3000/d/rss-bank-soc?var-app=financeapp-moulay
```

### Modifier l'adresse de réception

Fichier `soc/grafana/provisioning/alerting/contact_points.yml` :
```yaml
- name: soc-email
  grafana_managed_receiver_configs:
    - type: email
      settings:
        addresses: votre_email@example.com
```

---

## 17. SOC — Fail2ban (blocage IP)

Fail2ban tourne sur le serveur SOC et lit `security.log` pour bannir les IPs via `iptables`.

### Règles actives (`soc/fail2ban/jail.local`)

| Règle | Événement surveillé | Seuil | Ban |
|-------|---------------------|-------|-----|
| `rss-bruteforce` | `BRUTE_FORCE` | 5 / 5 min | **1 heure** |
| `rss-sqli` | `SQL_INJECTION` | 1 détection | **24 heures** |
| `rss-xss` | `XSS` | 1 détection | **24 heures** |
| `rss-traversal` | `PATH_TRAVERSAL` | 1 détection | **24 heures** |
| `rss-ml-anomaly` | `ML_ANOMALY` | 2 / 5 min | **12 heures** |

### Commandes utiles

```bash
# Lister les IPs bannies
sudo fail2ban-client status rss-bruteforce
sudo fail2ban-client status rss-sqli

# Débannir une IP
sudo fail2ban-client set rss-bruteforce unbanip 1.2.3.4

# Tester un filtre
sudo fail2ban-regex /var/log/apps/security.log /etc/fail2ban/filter.d/rss-sqli.conf

# Redémarrer
sudo systemctl restart fail2ban
```

---

## 18. SOC — ML Anomaly Detector

Le détecteur utilise **scikit-learn IsolationForest** pour détecter les comportements anormaux indépendamment des patterns connus.

Dossier : `soc/anomaly_detector/`

### Features analysées (8 indicateurs par IP / fenêtre 60s)

| Feature | Description |
|---------|-------------|
| `req_count` | Nombre total de requêtes dans la fenêtre |
| `error_rate` | Taux de réponses 4xx + 5xx |
| `unique_paths` | Nombre de chemins distincts accédés |
| `avg_duration_ms` | Durée moyenne des requêtes |
| `post_ratio` | Proportion de requêtes POST |
| `hour` | Heure de la journée (0-23) |
| `status_4xx_rate` | Taux de réponses 4xx |
| `status_5xx_rate` | Taux de réponses 5xx |

### Lancer le détecteur

```bash
cd soc/anomaly_detector
pip install -r requirements.txt

export ACCESS_LOG=/root/PFE/backend/logs/access.log
export SECURITY_LOG=/root/PFE/backend/logs/security.log
export WINDOW_SEC=60
export MIN_REQUESTS=5
export CONTAMINATION=0.1

python3 detector.py
```

### Événement généré

```json
{
  "ts": "2026-05-07T14:23:00Z",
  "event": "ML_ANOMALY",
  "ip": "185.220.101.45",
  "anomaly_score": -0.38,
  "features": {
    "req_count": 247,
    "error_rate": 0.891,
    "unique_paths": 89,
    "post_ratio": 0.94,
    "hour": 3
  }
}
```

> Score proche de -1 = anomalie forte. Score proche de +1 = comportement normal.

---

## 19. SOC — Tests d'attaque

### Scripts disponibles

```bash
# RSS BANK (cible locale)
bash /root/PFE/hack.sh

# financeapp-moulay (cible distante)
bash /root/PFE/attack_financeapp.sh
```

### Phases du test

| Phase | Type | Payloads | Résultat attendu dans Loki |
|-------|------|----------|---------------------------|
| 1 | Health check | — | HTTP 200/401 |
| 2 | Brute Force | 7 tentatives | `BRUTE_FORCE` après la 5e |
| 3 | SQL Injection | 13 payloads | `SQL_INJECTION` × 13 |
| 4 | XSS | 6 payloads | `XSS` × 6 |
| 5 | Path Traversal | 6 payloads | `PATH_TRAVERSAL` × 3-6 |
| 6 | Accès non autorisés | 4 endpoints | `UNAUTHORIZED` × 4 |
| 7 | Énumération reset | 5 emails | Loggé |

### Vérifier les résultats

```bash
# Logs en temps réel (hôte)
tail -f /root/PFE/backend/logs/security.log | python3 -m json.tool

# Compter par type
grep -c '"event": "SQL_INJECTION"' /root/PFE/backend/logs/security.log
grep -c '"event": "BRUTE_FORCE"'   /root/PFE/backend/logs/security.log
grep -c '"event": "XSS"'           /root/PFE/backend/logs/security.log

# Requêter Loki directement
curl -s -G http://198.199.70.48:3100/loki/api/v1/query \
  --data-urlencode 'query={job="django-security", event="SQL_INJECTION"}' \
  --data-urlencode 'limit=10' | python3 -m json.tool
```

### Tests manuels rapides

```bash
BASE=https://rssbank.pythonanywhere.com

# Brute force (alerte après 5 tentatives)
for i in {1..7}; do
  curl -s -X POST $BASE/api/comptes/connexion/ \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"victim@test.com\",\"password\":\"wrong$i\"}"
done

# SQL Injection
curl -s -X POST $BASE/api/comptes/connexion/ \
  -H "Content-Type: application/json" \
  -d '{"email":"'\'' OR 1=1--","password":"x"}'

# XSS
curl -s -X POST $BASE/api/comptes/connexion/ \
  -H "Content-Type: application/json" \
  -d '{"email":"<script>alert(document.cookie)</script>","password":"x"}'

# Path Traversal
curl -s "$BASE/api/comptes/profil/../../../etc/passwd"
```

---

## 20. SOC — Référence des événements

### Événements du middleware

| Événement | Déclencheur | Sévérité |
|-----------|-------------|----------|
| `SQL_INJECTION` | Pattern SQL dans body / URL / query string | Critique |
| `XSS` | `<script>`, `onerror=`, `javascript:`, `fetch()`… | Haute |
| `PATH_TRAVERSAL` | `../` ou `%2e%2e` dans l'URI brute | Haute |
| `BRUTE_FORCE` | ≥ 5 échecs de connexion / 5 min / même IP | Critique |
| `LOGIN_FAILURE` | Échec connexion (3e tentative et +) | Moyenne |
| `IP_BANNED` | IP déjà bannie tente une nouvelle requête | Haute |
| `UNAUTHORIZED` | Réponse HTTP 401 | Info |
| `FORBIDDEN` | Réponse HTTP 403 | Info |

### Événement ML Detector

| Événement | Déclencheur |
|-----------|-------------|
| `ML_ANOMALY` | Score IsolationForest anormal (comportement inhabituel) |

### Format JSON de chaque log

```json
{
  "ts":     "2026-05-07T14:23:00Z",
  "event":  "SQL_INJECTION",
  "ip":     "185.220.101.45",
  "app":    "rss-bank",
  "method": "POST",
  "path":   "/api/comptes/connexion/",
  "user":   "anonymous"
}
```

---

## 21. SOC — Dépannage

### Grafana ne reçoit pas de logs d'une app

```bash
# Tester le push Loki depuis le serveur de l'app
python3 -c "
import urllib.request, json, time
data = json.dumps({'streams':[{
  'stream':{'job':'django-security','app':'test','event':'TEST','env':'dev'},
  'values':[[str(int(time.time()*1e9)),'test connexion ok']]
}]}).encode()
req = urllib.request.Request(
  'http://198.199.70.48:3100/loki/api/v1/push',
  data=data,
  headers={'Content-Type':'application/json'}
)
print('Status:', urllib.request.urlopen(req).status)
"
# → 204 = succès, autre = problème réseau/firewall
```

### Le dashboard d'une app ne s'affiche pas

```bash
# Vérifier que l'app envoie bien des logs dans Loki
curl -s http://198.199.70.48:3100/loki/api/v1/label/app/values | python3 -m json.tool

# Recréer le dashboard
python3 /root/PFE/soc/add_app_dashboard.py <app_name>
docker compose -f /root/PFE/docker-compose.soc.yml restart grafana
```

### Brute Force non détecté

Vérifier que l'URL de connexion contient un mot reconnu :
```
/api/comptes/connexion/  → "connexion" ✓
/api/users/se-connecter/ → aucun mot reconnu ✗ → ajouter dans LOGIN_KEYWORDS
```

### Path Traversal manqué (3/6 au lieu de 6/6)

Django normalise `request.path` et supprime les `../`. Le middleware v6 lit aussi `RAW_URI`. Si Nginx ne le transmet pas :
```nginx
proxy_set_header RAW_URI $request_uri;
```

### Alertes Grafana restent en état "Normal"

```bash
# Vérifier que Loki reçoit les bons labels
curl -s -G http://198.199.70.48:3100/loki/api/v1/query \
  --data-urlencode 'query={job="django-security"}' \
  --data-urlencode 'limit=5' | python3 -m json.tool
# → Si résultat vide : le middleware ne pousse pas vers Loki
```

### Voir les logs des conteneurs

```bash
docker compose -f /root/PFE/docker-compose.soc.yml logs loki    --tail 50
docker compose -f /root/PFE/docker-compose.soc.yml logs grafana --tail 50
```

---

## 22. Structure du projet

```
PFE/
├── docker-compose.soc.yml          # SOC : Loki + Grafana
├── security_middleware.py          # Middleware v6 à distribuer aux amis
├── attack_financeapp.sh            # Script test attaques (financeapp-moulay)
├── hack.sh                         # Script test attaques (RSS BANK)
├── .env                            # SMTP Brevo + SOC_HOST
├── README.md                       # Ce fichier
│
└── soc/                            # Security Operations Center
    ├── add_app_dashboard.py        # Générateur dashboard par app
    ├── loki.yml                    # Config Loki (rétention 7j, port 3100)
    ├── promtail.yml                # Collecte logs locaux
    ├── promtail-remote.yml         # Collecte pour serveur distant
    │
    ├── anomaly_detector/
    │   ├── detector.py             # ML IsolationForest (8 features)
    │   └── requirements.txt
    │
    ├── fail2ban/
    │   ├── jail.local              # 5 règles (BF=1h, SQLi/XSS/PT=24h, ML=12h)
    │   └── filter.d/
    │       ├── rss-bruteforce.conf
    │       ├── rss-sqli.conf
    │       ├── rss-xss.conf
    │       ├── rss-traversal.conf
    │       └── rss-ml-anomaly.conf
    │
    └── grafana/
        ├── grafana.ini             # SMTP Brevo + sécurité
        └── provisioning/
            ├── datasources/
            │   └── loki.yml        # Connexion Loki → Grafana
            ├── alerting/
            │   ├── alerts.yml      # 4 règles (sum by app)
            │   ├── contact_points.yml
            │   └── policies.yml
            └── dashboards/
                ├── dashboard.yml
                ├── sedad_bank_soc.json          # Template principal
                ├── soc_soc-financeapp-moulay.json
                ├── soc_soc-trackpay.json
                └── soc_soc-nova-sso.json
```

---

*RSS BANK — Projet de Fin d'Études | 2025-2026*  
*Application bancaire digitale mobile pour la Mauritanie — Devise : MRU (Ouguiya Mauritanien)*  
*SOC centralisé multi-applications : Loki 2.9 · Grafana 10.2 · Fail2ban · IsolationForest ML*
