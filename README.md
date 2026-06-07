# RSS BANK — Application Bancaire Mobile

> **Projet de Fin d'Études (PFE) — 2025/2026**  
> Application bancaire mobile complète avec API Django REST, frontend Flutter et SOC centralisé multi-applications.

---

## Table des matières

1. [Présentation](#1-présentation)
2. [Architecture globale](#2-architecture-globale)
3. [Stack technique](#3-stack-technique)
4. [Structure du projet](#4-structure-du-projet)
5. [Modèles de données](#5-modèles-de-données)
6. [API Reference complète](#6-api-reference-complète)
7. [Sécurité](#7-sécurité)
8. [SOC Multi-applications](#8-soc-multi-applications)
9. [Variables d'environnement](#9-variables-denvironnement)
10. [Installation & Lancement](#10-installation--lancement)
11. [Logs](#11-logs)
12. [Tests de sécurité](#12-tests-de-sécurité)
13. [Application Flutter](#13-application-flutter)
14. [Déploiement production](#14-déploiement-production)

---

## 1. Présentation

**RSS BANK** est une plateforme bancaire mobile développée dans le cadre d'un PFE. Elle est couplée à un **SOC (Security Operations Center) centralisé** capable de surveiller plusieurs applications bancaires simultanément.

### Fonctionnalités

| Domaine | Fonctionnalité |
|---------|---------------|
| Auth | Inscription + vérification email OTP (10 min), login JWT, reset mot de passe |
| Comptes | Comptes courant/épargne en MRU · DZD · USD · EUR |
| Transactions | Virements atomiques par numéro de compte ou numéro de téléphone |
| Cartes | Gestion cartes débit/crédit/virtuel (VISA, Mastercard, Amex) |
| Bénéficiaires | Interne (RSS Bank) et externe (autre banque) |
| Sécurité | Blocage SQL Injection, XSS, Path Traversal, Brute Force (sans Suricata) |
| SOC | Loki + Grafana + Suricata + Promtail — alertes email via Brevo |
| Flutter | Multi-langue FR/AR (RTL automatique), 5 onglets, QR Code |

---

## 2. Architecture globale

```
┌─────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                  │
└──────────┬──────────────────────────┬──────────────────────────────┘
           │ HTTP/HTTPS               │ HTTPS
           ▼                          ▼
┌─────────────────────┐    ┌──────────────────────────────────────┐
│  Flutter (Android)  │    │         appbank (104.248.61.147)     │
│                     │───►│                                      │
│  Provider + JWT     │    │  ┌──────────────┐  ┌─────────────┐  │
│  GoRouter           │    │  │   Suricata   │  │   Django    │  │
│  FR / AR            │    │  │   NFQUEUE    │  │   Gunicorn  │  │
└─────────────────────┘    │  │   15 règles  │  │   Port 8000 │  │
                           │  └──────┬───────┘  └──────┬──────┘  │
                           │         │ drop/pass        │ logs    │
                           │  ┌──────▼───────────────────▼──────┐ │
                           │  │  iptables NFQUEUE + ipset ban   │ │
                           │  └─────────────────────────────────┘ │
                           └──────────────────┬───────────────────┘
                                              │ logs JSON (Loki push)
                                              ▼
                           ┌──────────────────────────────────────┐
                           │     SOC (198.199.70.48)              │
                           │                                      │
                           │  Loki:3100  ←  Promtail             │
                           │  Grafana:3000  →  Email Brevo       │
                           │  4 règles d'alerte RSS               │
                           └──────────────────────────────────────┘
```

### Diagramme de séquence — Attaque détectée

```
  Attaquant          SecurityMiddleware      Loki        Grafana     Email
      │                     │                │              │           │
      │── GET ?q=UNION ────►│                │              │           │
      │                     │ détecte SQLi   │              │           │
      │                     │── log JSON ───►│              │           │
      │◄── HTTP 403 ────────│                │◄─── query ───│           │
      │   (vue jamais       │                │──── data ────►│           │
      │    exécutée)        │                │              │─ alerte ──►│
```

### Diagramme de séquence — Inscription OTP

```
  Flutter             Backend Django            Brevo SMTP
     │                      │                       │
     │── POST /register/ ──►│                       │
     │                      │── génère OTP (6 ch.) ─►│─── email ──► Client
     │◄── 201 pending ──────│                       │
     │── POST /verify/ ────►│ valide OTP + expiry   │
     │◄── 200 vérifié ──────│                       │
     │── POST /login/ ─────►│                       │
     │◄── {access, refresh}─│                       │
```

---

## 3. Stack technique

| Composant | Technologie | Version |
|-----------|-------------|---------|
| Frontend | Flutter + Provider + GoRouter | 3.x |
| Backend | Django REST Framework | 4.2.7 |
| Auth | SimpleJWT | 5.5.1 — access 60min / refresh 1j |
| Base de données | PostgreSQL (prod) · SQLite (dev) | 15 |
| Email | Brevo API HTTPS (contourne blocage port 587) | sib-api v7.6 |
| Serveur | Gunicorn | 21.2.0 — 3 workers |
| IPS réseau | Suricata NFQUEUE | 7.0.3 — 15 règles |
| Collecte logs | Promtail | 2.9.0 |
| Stockage logs | Loki | 2.9.0 |
| Dashboard SOC | Grafana | 10.2.0 |
| Ban IP réseau | ipset + iptables | — |

---

## 4. Structure du projet

```
PFE/
├── docker-compose.app.yml          # App seule : db + backend
├── docker-compose.soc.yml          # SOC : Loki + Grafana
├── .env                            # SMTP Grafana
├── RSS_SOC_MIDDLEWARE_README.md    # Guide intégration middleware pour amis
├── README.md                       # Ce fichier
│
├── backend/                        # API Django REST Framework
│   ├── Dockerfile                  # python:3.11-slim, port 8000
│   ├── run.sh                      # migrate + collectstatic + gunicorn
│   ├── requirements.txt
│   ├── .env                        # DB + Email + SOC
│   ├── logs/                       # Montés en volume Docker
│   │   ├── security.log            # Événements SOC (JSON)
│   │   ├── access.log              # Requêtes HTTP (JSON)
│   │   └── django.log              # Logs internes Django
│   ├── fintech_bank/
│   │   ├── settings.py             # Config Django complète
│   │   └── urls.py                 # Routes : /admin/ /api/ /api/docs/
│   └── apps/core/
│       ├── models.py               # 7 modèles
│       ├── views.py                # 14 ViewSets / APIViews
│       ├── serializers.py          # 13 sérialiseurs
│       ├── urls.py                 # Router DRF + auth endpoints
│       ├── admin.py                # Interface admin Django
│       ├── brevo_backend.py        # Backend email custom Brevo HTTPS
│       ├── security_middleware.py  # Middleware SOC v5 (detect + block)
│       └── migrations/             # 4 migrations
│
├── frontend/sedad_bank/            # Application Flutter
│   └── lib/
│       ├── main.dart
│       ├── l10n/                   # Traductions FR + AR
│       ├── core/services/
│       ├── providers/              # Auth, Account, Transaction, User, Language
│       ├── routes/app_routes.dart
│       └── screens/
│
└── soc/                            # Security Operations Center
    ├── loki.yml
    ├── promtail.yml                # Collecte eve.json Suricata + logs Django
    └── grafana/
        ├── grafana.ini             # SMTP Brevo
        └── provisioning/
            ├── datasources/        # Loki datasource
            ├── alerting/           # 4 règles + contact points + policies
            └── dashboards/         # Dashboard RSS BANK SOC
```

---

## 5. Modèles de données

### Relations

```
User (AbstractUser · UUID)
 ├── UserProfile          1:1   OTP, notifications, vérifications
 ├── Account              1:N   Comptes bancaires
 │    ├── Card            1:N   Cartes bancaires
 │    └── Transaction     1:N   via from_account / to_account
 │         └── TransactionHistory  1:N  Historique des statuts
 └── Beneficiary          1:N   Bénéficiaires enregistrés
```

### User

| Champ | Type | Notes |
|-------|------|-------|
| `id` | UUID | Clé primaire |
| `email` | CharField unique | Identifiant de connexion |
| `phone_number` | CharField | |
| `national_id` | CharField unique | CNI |
| `role` | ENUM | `client` · `admin` · `agent` |
| `status` | ENUM | `active` · `suspended` · `blocked` · `closed` |
| `kyc_status` | ENUM | `pending` · `approved` · `rejected` |
| `two_factor_enabled` | Boolean | |
| `last_login_ip` | GenericIPAddressField | Suivi SOC |
| `login_attempts` | Integer | Compteur tentatives |
| `account_locked_until` | DateTime | Verrouillage temporaire |
| `profile_photo` | ImageField | `/media/profiles/` |

### UserProfile (1:1 User)

| Champ | Type | Notes |
|-------|------|-------|
| `verified_email` | Boolean | Confirmé via OTP |
| `otp_code` | CharField(6) | Code OTP actif |
| `otp_expires_at` | DateTime | Expire dans 10 min |
| `otp_type` | ENUM | `verify_email` · `reset_password` |
| `notification_email/sms/push` | Boolean | Préférences |

### Account

| Champ | Type | Notes |
|-------|------|-------|
| `id` | UUID | |
| `account_number` | CharField unique | Format `RSSxxxxxxxx` |
| `account_type` | ENUM | `checking` · `savings` |
| `currency` | ENUM | `MRU` · `DZD` · `USD` · `EUR` |
| `balance` | Decimal(15,2) | Solde total |
| `available_balance` | Decimal(15,2) | Solde disponible |
| `status` | ENUM | `active` · `frozen` · `closed` |
| `daily_withdrawal_limit` | Decimal | Défaut : 5 000 |
| `daily_transfer_limit` | Decimal | Défaut : 10 000 |

### Transaction

| Champ | Type | Notes |
|-------|------|-------|
| `id` | UUID | |
| `from_account` | FK Account | PROTECT |
| `to_account` | FK Account | PROTECT, nullable |
| `to_beneficiary` | FK Beneficiary | SET_NULL |
| `transaction_type` | ENUM | `transfer` · `payment` · `withdrawal` · `deposit` · `salary` |
| `amount` | Decimal(15,2) | |
| `transaction_fee` | Decimal(10,2) | |
| `total_amount` | Decimal(15,2) | `amount + fee` |
| `reference_number` | CharField unique | Format `TXNxxxxxxxx` |
| `status` | ENUM | `pending` · `processing` · `completed` · `failed` · `reversed` |
| `is_flagged` | Boolean | Fraude |
| `fraud_score` | Integer | Score 0-100 |
| `ip_address` | IP | Pour SOC |

### Card

| Champ | Type | Notes |
|-------|------|-------|
| `id` | UUID | |
| `account` | FK Account | CASCADE |
| `card_type` | ENUM | `debit` · `credit` · `virtual` |
| `card_brand` | ENUM | `VISA` · `MASTERCARD` · `AMEX` |
| `last_four_digits` | CharField(4) | |
| `card_number_hash` | CharField unique | Stocké hashé |
| `cvv_hash` | CharField | Stocké hashé |
| `status` | ENUM | `active` · `suspended` · `expired` · `blocked` |
| `daily_spending_limit` | Decimal | |
| `monthly_spending_limit` | Decimal | |

### Beneficiary

| Champ | Type | Notes |
|-------|------|-------|
| `id` | UUID | |
| `user` | FK User | CASCADE |
| `beneficiary_type` | ENUM | `internal` · `external` |
| `account_number` | CharField | Optionnel |
| `phone_number` | CharField | Virement par téléphone |
| `bank_name` | CharField | Banque externe |
| `is_verified` | Boolean | |

### Table brute-force (créée automatiquement)

```sql
rss_soc_login_failures (
    id   SERIAL PRIMARY KEY,
    ip   VARCHAR(64) NOT NULL,
    ts   TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
-- Une ligne par tentative. COUNT(*) donne le nombre en 5 min.
```

---

## 6. API Reference complète

**Base URL :** `http://104.248.61.147:8000/api/`  
**Swagger :** `http://104.248.61.147:8000/api/docs/`  
**Auth requise** (sauf `/auth/`) : `Authorization: Bearer <access_token>`

### Codes de réponse

| Code | Signification |
|------|---------------|
| `200` | Succès |
| `201` | Créé |
| `400` | Données invalides |
| `401` | Non authentifié |
| `403` | **Attaque bloquée** (SQL / XSS / Path Traversal) |
| `404` | Introuvable |
| `429` | **IP bannie** — brute force — `Retry-After: 3600` |
| `500` | Erreur serveur |

---

### 6.1 Authentification

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/auth/register/` | Inscription → envoi OTP email |
| `POST` | `/auth/verify-email/` | Valider OTP |
| `POST` | `/auth/resend-otp/` | Renvoyer OTP |
| `POST` | `/auth/login/` | Connexion → JWT |
| `POST` | `/auth/token/refresh/` | Rafraîchir access token |
| `POST` | `/auth/forgot-password/` | Demander reset mot de passe |
| `POST` | `/auth/reset-password/` | Réinitialiser avec OTP |
| `POST` | `/auth/sso-login/` | Connexion SSO externe |

**POST `/auth/register/`**
```json
{
  "email": "user@example.com",
  "password": "MotDePasse123!",
  "password_confirm": "MotDePasse123!",
  "first_name": "Mohamed",
  "last_name": "Diallo",
  "phone_number": "+22200000001"
}
```
Réponse `201` :
```json
{ "message": "Compte créé. Vérifiez votre email.", "email": "user@example.com" }
```

**POST `/auth/login/`**
```json
{ "email": "user@example.com", "password": "MotDePasse123!" }
```
Réponse `200` :
```json
{
  "access": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": { "id": "uuid", "email": "...", "role": "client" }
}
```

**POST `/auth/verify-email/`**
```json
{ "email": "user@example.com", "code": "482931" }
```

**POST `/auth/forgot-password/`**
```json
{ "email": "user@example.com" }
```

**POST `/auth/reset-password/`**
```json
{ "email": "user@example.com", "code": "182746", "new_password": "Nouveau123!", "new_password_confirm": "Nouveau123!" }
```

---

### 6.2 Utilisateurs

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/users/` | Liste (admin) |
| `GET` | `/users/me/` | Profil connecté |
| `GET` | `/users/{id}/` | Détail |
| `PUT/PATCH` | `/users/{id}/` | Modifier profil |
| `DELETE` | `/users/{id}/` | Supprimer |
| `POST` | `/users/change_password/` | Changer mot de passe |
| `POST` | `/users/logout/` | Déconnexion |
| `PATCH` | `/users/{id}/update_status/` | Changer statut (admin) |

**GET `/users/me/`** — Réponse :
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "first_name": "Mohamed",
  "last_name": "Diallo",
  "phone_number": "+22200000001",
  "role": "client",
  "status": "active",
  "kyc_status": "pending",
  "two_factor_enabled": false,
  "created_at": "2026-01-01T00:00:00Z"
}
```

**POST `/users/change_password/`**
```json
{ "old_password": "Ancien123!", "new_password": "Nouveau123!", "new_password_confirm": "Nouveau123!" }
```

**PATCH `/users/{id}/update_status/`** (admin)
```json
{ "status": "suspended" }
```

---

### 6.3 Profil utilisateur

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/users/profile/me/` | Voir profil complet |
| `PUT/PATCH` | `/users/profile/me/` | Modifier bio, notifications |

---

### 6.4 Comptes bancaires

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/accounts/` | Mes comptes |
| `POST` | `/accounts/` | Créer un compte |
| `GET` | `/accounts/{id}/` | Détail |
| `PUT/PATCH` | `/accounts/{id}/` | Modifier |
| `DELETE` | `/accounts/{id}/` | Fermer |
| `POST` | `/accounts/{id}/deposit/` | Déposer des fonds |

**POST `/accounts/`**
```json
{ "account_name": "Compte Principal", "account_type": "checking", "currency": "MRU" }
```

**POST `/accounts/{id}/deposit/`**
```json
{ "amount": "5000.00" }
```

---

### 6.5 Transactions

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/transactions/` | Transactions envoyées |
| `POST` | `/transactions/` | Créer une transaction |
| `GET` | `/transactions/{id}/` | Détail |
| `GET` | `/transactions/received/` | Transactions reçues |
| `GET` | `/transactions/history/` | Historique des statuts |

**POST `/transactions/`** — Par numéro de compte :
```json
{
  "from_account": "uuid-source",
  "to_account": "uuid-destination",
  "transaction_type": "transfer",
  "amount": "1000.00",
  "currency": "MRU",
  "description": "Remboursement"
}
```

**POST `/transactions/`** — Par numéro de téléphone :
```json
{
  "from_account": "uuid-source",
  "to_phone": "+22200000002",
  "transaction_type": "transfer",
  "amount": "500.00",
  "currency": "MRU"
}
```

Réponse `201` :
```json
{
  "id": "uuid",
  "reference_number": "TXNa1b2c3d4",
  "status": "completed",
  "amount": "1000.00",
  "transaction_fee": "0.00",
  "total_amount": "1000.00",
  "created_at": "2026-05-07T10:00:00Z"
}
```

---

### 6.6 Cartes

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/cards/` | Mes cartes |
| `POST` | `/cards/` | Créer |
| `GET` | `/cards/{id}/` | Détail |
| `PUT/PATCH` | `/cards/{id}/` | Modifier limites / statut |
| `DELETE` | `/cards/{id}/` | Supprimer |

---

### 6.7 Bénéficiaires

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `GET` | `/beneficiaries/` | Mes bénéficiaires |
| `POST` | `/beneficiaries/` | Ajouter |
| `GET` | `/beneficiaries/{id}/` | Détail |
| `PUT/PATCH` | `/beneficiaries/{id}/` | Modifier |
| `DELETE` | `/beneficiaries/{id}/` | Supprimer |

---

## 7. Sécurité

### 7.1 Middleware Django (sans Suricata — distributable)

Le fichier `backend/apps/core/security_middleware.py` est le **premier middleware** dans la chaîne. Il coupe la requête avant la vue si une attaque est détectée.

```
Requête entrante
      │
      ▼
┌──────────────────────────────────────────────────────┐
│  SecurityMiddleware v5                               │
│                                                      │
│  1. IP bannie ?      ── OUI ──► HTTP 429            │
│        │                        Vue jamais appelée   │
│       NON                                           │
│        │                                            │
│  2. SQL / XSS /      ── OUI ──► HTTP 403            │
│     PATH_TRAVERSAL              Vue jamais appelée   │
│     détecté ?                                       │
│        │                                            │
│       NON                                           │
│        │                                            │
│  3. Requête normale ──────────► Vue Django          │
│                                      │              │
│  4. Après réponse :                  ▼              │
│     Login raté ≥5 → ban IP en mémoire               │
│     (prochaine req → 429 pendant 1h)                │
└──────────────────────────────────────────────────────┘
```

| Événement | Déclencheur | Réponse HTTP |
|-----------|-------------|-------------|
| `SQL_INJECTION` | Regex SQL dans params/body | `403` |
| `XSS` | `<script>`, `onerror=`, `javascript:` | `403` |
| `PATH_TRAVERSAL` | `../`, `/etc/passwd`, `%2e%2e` | `403` |
| `BRUTE_FORCE` | 5+ échecs login en 5 min / même IP | `429` + ban 1h |
| `BANNED_IP` | IP déjà bannie | `429` |
| `LOGIN_SUCCESS` | POST login 200/201 | Log SOC uniquement |
| `LOGIN_FAILURE` | POST login 400/401/403 | Log SOC + compteur DB |
| `UNAUTHORIZED` | HTTP 401 hors login | Log SOC uniquement |

Tous les événements sont poussés vers Loki en JSON :
```json
{
  "ts": "2026-05-07T10:00:00Z",
  "event": "SQL_INJECTION",
  "ip": "45.33.32.156",
  "method": "GET",
  "path": "/api/users/",
  "app": "rss-bank",
  "blocked": true
}
```

### 7.2 Suricata IPS (couche réseau — serveur appbank uniquement)

Suricata tourne en mode NFQUEUE et inspecte le trafic **avant** Django.

```
Internet → iptables NFQUEUE → Suricata (15 règles) → Django
                                    │
                                    └── drop HTTP 403 si match
```

**Règles actives** (`/etc/suricata/rules/rss-bank.rules`) :

| SID | Type | Règle |
|-----|------|-------|
| 9000001 | SQL | UNION SELECT |
| 9000002 | SQL | OR 1=1 |
| 9000003 | SQL | DROP TABLE |
| 9000004 | SQL | admin'-- |
| 9000005 | SQL | SELECT FROM |
| 9000010 | XSS | `<script` |
| 9000011 | XSS | `onerror=` |
| 9000012 | XSS | `javascript:` |
| 9000013 | XSS | `<iframe` |
| 9000014 | XSS | `<img onerror` |
| 9000020 | Traversal | `../` |
| 9000021 | Traversal | `%2e%2e` |
| 9000022 | Traversal | `/etc/passwd` |
| 9000023 | Traversal | `system32` |
| 9000030 | BruteForce | 5 POST /login/ en 60s (alert) |

**Ban IP (ipset)** — `banner.py` lit `eve.json` et banne toute IP alertée pendant 1h :
```bash
ipset list rss_blacklist          # IPs bannies actuellement
```

### 7.3 JWT

- **Access token** : durée 60 minutes, algorithme HS256
- **Refresh token** : durée 1 jour
- Route de refresh : `POST /api/auth/token/refresh/`

### 7.4 Email via Brevo (contourne blocage DigitalOcean)

DigitalOcean bloque le port 587 en sortie. L'envoi d'emails passe par l'**API HTTPS Brevo** (pas SMTP), via le backend custom `brevo_backend.py`.

---

## 8. SOC Multi-applications

### Concept

Le SOC est une plateforme centralisée indépendante. N'importe quelle app Django peut l'utiliser en ajoutant le middleware.

```
┌──────────────┐                    ┌─────────────────────────────┐
│  RSS BANK    │ ──── logs JSON ───►│                             │
│  (app 1)     │                    │     SOC CENTRALISÉ          │
└──────────────┘                    │  198.199.70.48              │
                                    │                             │
┌──────────────┐                    │  Loki:3100  ← logs          │
│  App amis 2  │ ──── logs JSON ───►│  Grafana:3000 → dashboard   │
│  (Django)    │                    │  Alertes → Email Brevo      │
└──────────────┘                    │                             │
                                    │  4 règles actives :         │
┌──────────────┐                    │  · SQL Injection            │
│  App amis 3  │ ──── logs JSON ───►│  · XSS                      │
│  (Django)    │                    │  · Path Traversal           │
└──────────────┘                    │  · Brute Force              │
                                    └─────────────────────────────┘
```

### Ajouter une app au SOC (3 étapes)

1. **Copier** `backend/apps/core/security_middleware.py` dans l'app
2. **Ajouter** en premier dans `settings.py` MIDDLEWARE :
   ```python
   'apps.core.security_middleware.SecurityMiddleware'
   ```
3. **Configurer** `.env` :
   ```env
   RSS_SOC_APP_NAME=nom-unique-app    # seule variable obligatoire
   RSS_SOC_URL=http://198.199.70.48:3100
   RSS_SOC_TOKEN=rssbank-token-2024
   RSS_SOC_BLOCK_ATTACKS=true
   RSS_SOC_BAN_DURATION=3600
   RSS_SOC_EMAIL_ALERTS=false
   ```

Chaque app apparaît dans Grafana filtrée par son `app` label.

### Alertes Grafana (4 règles)

| Règle UID | Titre | Seuil |
|-----------|-------|-------|
| `alert-sqli-rss` | SQL Injection Detected | > 0 événement en 5 min |
| `alert-xss-rss` | XSS Attack Detected | > 0 événement en 5 min |
| `alert-traversal-rss` | Path Traversal Detected | > 0 événement en 5 min |
| `alert-bruteforce-rss` | Brute Force Detected | > 0 événement en 5 min |

Email envoyé à : `belkhairtaleb@gmail.com` via Brevo SMTP `smtp-relay.brevo.com:2525`

---

## 9. Variables d'environnement

### `backend/.env`

```env
# Django
SECRET_KEY=django-insecure-xxx-changer-en-prod
DEBUG=True
ALLOWED_HOSTS=*

# PostgreSQL
DB_ENGINE=django.db.backends.postgresql
DB_NAME=sedad_bank
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=db
DB_PORT=5432

# Email (Brevo API — contourne port 587 bloqué)
BREVO_API_KEY=xkeysib-...
BREVO_FROM_NAME=RSS Bank
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=xxxx xxxx xxxx xxxx

# SOC — Middleware de sécurité
RSS_SOC_APP_NAME=rss-bank          # Nom visible dans Grafana
RSS_SOC_URL=http://198.199.70.48:3100
RSS_SOC_TOKEN=rssbank-token-2024
RSS_SOC_ENV=production
RSS_SOC_LOCAL_LOGS=/app/logs
RSS_SOC_BLOCK_ATTACKS=true         # false = log sans bloquer
RSS_SOC_BAN_DURATION=3600          # Durée ban IP en secondes
RSS_SOC_EMAIL_ALERTS=false         # Grafana gère les alertes email
```

### `.env` (racine — Grafana SMTP)

```env
GF_SMTP_ENABLED=true
GF_SMTP_HOST=smtp-relay.brevo.com:2525
GF_SMTP_USER=a92c4c001@smtp-brevo.com
GF_SMTP_PASSWORD=xsmtpsib-...
GF_SMTP_FROM_ADDRESS=rssbank700@gmail.com
```

---

## 10. Installation & Lancement

### Prérequis

- Docker >= 24
- Docker Compose >= 2.20
- 2 Go RAM minimum

### Lancement rapide

```bash
git clone <repo> && cd PFE

# App seule (DB + Backend Django)
docker compose -f docker-compose.app.yml up --build -d

# SOC seul (Loki + Grafana)
docker compose -f docker-compose.soc.yml up -d
```

### Services

| Service | URL | Identifiants |
|---------|-----|-------------|
| API REST | http://localhost:8000/api/ | — |
| Swagger | http://localhost:8000/api/docs/ | — |
| Admin Django | http://localhost:8000/admin/ | admin@rss.com / Admin2024! |
| Grafana SOC | http://198.199.70.48:3000 | admin / SedadSOC2024! |
| Loki | http://198.199.70.48:3100 | — |

### Développement local (sans Docker)

```bash
cd backend
python3.11 -m venv venv && source venv/bin/activate
pip install -r requirements.txt

# SQLite pour le dev
export DB_ENGINE=django.db.backends.sqlite3

python manage.py migrate
python manage.py createsuperuser
python manage.py runserver
```

### Ce que fait `run.sh` au démarrage Docker

```bash
1. Attente que PostgreSQL soit prêt (pg_isready)
2. python manage.py migrate --noinput
3. python manage.py collectstatic --noinput
4. Crée superadmin admin@rss.com / Admin2024! si absent
5. gunicorn fintech_bank.wsgi --bind 0.0.0.0:8000 --workers 3 --timeout 60
```

---

## 11. Logs

Les logs sont montés en volume Docker dans `backend/logs/` (accessible sur le host directement).

### Lire les logs

```bash
# Sécurité en temps réel
tail -f backend/logs/security.log

# Filtrer par type d'attaque
grep "SQL_INJECTION"   backend/logs/security.log | tail -20
grep "BRUTE_FORCE"     backend/logs/security.log | tail -20
grep "XSS"             backend/logs/security.log | tail -20
grep "PATH_TRAVERSAL"  backend/logs/security.log | tail -20

# Requêtes HTTP
tail -f backend/logs/access.log

# Depuis le container
docker exec pfe-backend-1 tail -f /app/logs/security.log
```

### Format `security.log`

```json
{
  "ts": "2026-05-07T10:30:00Z",
  "event": "SQL_INJECTION",
  "ip": "45.33.32.156",
  "method": "GET",
  "path": "/api/users/?search=' OR 1=1",
  "app": "rss-bank",
  "blocked": true
}
```

### Format `access.log`

```json
{
  "ts": "2026-05-07T10:30:01Z",
  "method": "POST",
  "path": "/api/auth/login/",
  "status": 200,
  "ip": "102.168.1.5",
  "user": "user@example.com",
  "duration_ms": 45,
  "app": "rss-bank"
}
```

### IPs bannies (brute force)

```bash
# Ban en mémoire (reset au restart)
docker exec pfe-backend-1 python manage.py shell -c "
from apps.core.security_middleware import _banned_ips
import time
for ip, expiry in _banned_ips.items():
    print(f'{ip} — expire dans {int(expiry - time.time())}s')
"

# Historique des tentatives en base (vraies colonnes : id, ip, ts)
docker exec pfe-backend-1 python manage.py shell -c "
from django.db import connection
c = connection.cursor()
c.execute('''
    SELECT ip, COUNT(*) as tentatives, MAX(ts) as derniere
    FROM rss_soc_login_failures
    WHERE ts > NOW() - INTERVAL '1 hour'
    GROUP BY ip ORDER BY tentatives DESC LIMIT 20
''')
for row in c.fetchall():
    print(f'IP: {row[0]} | Tentatives: {row[1]} | Dernière: {row[2]}')
"

# Ban réseau Suricata (ipset)
ipset list rss_blacklist
```

---

## 12. Tests de sécurité

```bash
BASE=http://104.248.61.147:8000

# SQL Injection → doit retourner 403
curl -s -o /dev/null -w "SQL Injection: %{http_code}\n" \
  "$BASE/api/users/?search=' UNION SELECT 1,2,3--"

# XSS → doit retourner 403
curl -s -o /dev/null -w "XSS: %{http_code}\n" \
  "$BASE/api/users/?q=<script>alert(1)</script>"

# Path Traversal → doit retourner 403
curl -s -o /dev/null -w "Path Traversal: %{http_code}\n" \
  "$BASE/api/../../../etc/passwd"

# Brute Force → doit retourner 429 après 5 tentatives
for i in {1..7}; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE/api/auth/login/" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"test@test.com\",\"password\":\"wrong$i\"}")
  echo "Tentative $i : HTTP $CODE"
done
```

Résultats attendus :
```
SQL Injection  : HTTP 403
XSS            : HTTP 403
Path Traversal : HTTP 403
Tentative 1-5  : HTTP 401
Tentative 6-7  : HTTP 429  ← IP bannie pendant 1h
```

### Vérifier que les logs arrivent sur le SOC

```bash
curl -s "http://198.199.70.48:3100/loki/api/v1/query" \
  -H "X-Scope-OrgID: rssbank-token-2024" \
  --data-urlencode 'query={job="django-security", event="SQL_INJECTION"}' | python3 -m json.tool
```

---

## 13. Application Flutter

### Navigation

| Onglet | Route | Description |
|--------|-------|-------------|
| Accueil | `/home` | Carte bancaire + 6 services |
| Historique | `/history` | Transactions filtrées |
| QR | `/qr-transactions` | Générer / Scanner |
| Ma Banque | `/ma-banque` | Comptes + création |
| Profil | `/profile` | Infos + mot de passe + langue |

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
| `AuthProvider` | Session JWT, login, register, OTP |
| `AccountProvider` | Comptes, création, sélection |
| `TransactionProvider` | Transactions envoyées + reçues |
| `UserProvider` | Liste utilisateurs (admin) |
| `LanguageProvider` | Locale FR/AR, persistance SharedPreferences |

### Multi-langue FR / AR

- Basculer depuis **Profil** → carte Langue
- Direction **RTL automatique** en arabe
- Fichiers : `lib/l10n/app_fr.arb` et `lib/l10n/app_ar.arb` (80+ clés)

---

## 14. Déploiement production

### Checklist `.env` avant déploiement

```env
DEBUG=False
SECRET_KEY=<clé aléatoire 50+ caractères — jamais la clé de dev>
ALLOWED_HOSTS=mondomaine.com
DB_PASSWORD=<mot de passe fort>
RSS_SOC_BLOCK_ATTACKS=true
RSS_SOC_EMAIL_ALERTS=false
```

### Sur le serveur (DigitalOcean)

```bash
# Rebuild après modification
docker compose -f docker-compose.app.yml up --build -d

# Voir les logs en direct
docker logs pfe-backend-1 -f

# Vérifier le middleware actif
docker logs pfe-backend-1 2>&1 | grep "rss-soc"
# → [rss-soc] v5 active | app=rss-bank env=production block=True ban=3600s
```

### APK Flutter

```bash
cd frontend/sedad_bank
flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

---

*RSS BANK — Projet de Fin d'Études 2025-2026*  
*Stack : Django 4.2 · Flutter 3 · PostgreSQL 15 · JWT · Suricata · Loki · Grafana · Brevo*  
*Devise : MRU (Ouguiya Mauritanien) · Multi-langue : Français / Arabe*
