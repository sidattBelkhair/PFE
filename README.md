# RSS BANK — Application Bancaire Mobile

> Projet de Fin d'Études (PFE) — Application bancaire mobile complète avec système SOC intégré

---

## Table des matières

1. [Présentation](#1-présentation)
2. [Architecture](#2-architecture)
3. [Prérequis](#3-prérequis)
4. [Lancement avec Docker](#4-lancement-avec-docker)
5. [Lancement sans Docker (local)](#5-lancement-sans-docker-local)
6. [API Reference complète](#6-api-reference-complète)
7. [Application Flutter](#7-application-flutter)
8. [SOC — Monitoring & Alertes](#8-soc--monitoring--alertes)
9. [Guide de test complet](#9-guide-de-test-complet)
10. [Tests de sécurité](#10-tests-de-sécurité)
11. [Structure du projet](#11-structure-du-projet)

---

## 1. Présentation

**RSS BANK** est une plateforme bancaire mobile développée dans le cadre d'un PFE.

**Fonctionnalités :**
- Gestion de comptes (courant / épargne) en MRU (Ouguiya Mauritanien)
- Virements via numéro de compte ou QR Code
- Services : recharge, retraits, paiements, factures
- Authentification JWT avec protection anti brute-force
- SOC (Security Operations Center) : Loki + Promtail + Grafana
- Détection automatique : SQL Injection, XSS, Path Traversal, Brute Force
- Dashboard administrateur

---

## 2. Architecture

```
+------------------------------------------------------------------+
|                          RSS BANK                                |
+-------------------+--------------------+-------------------------+
| Frontend Flutter  |  Backend Django    |  SOC / Monitoring       |
| Port 80           |  Port 8000         |  Grafana Port 3000      |
+-------------------+--------------------+-------------------------+
|                    PostgreSQL  Port 5432                         |
+------------------------------------------------------------------+
```

| Composant | Technologie | Version |
|-----------|-------------|---------|
| Frontend | Flutter + Provider + GoRouter | 3.x |
| Backend | Django REST Framework | 4.2.7 |
| Base de données | PostgreSQL | 15 |
| Auth | JWT (SimpleJWT) | 60min / 1j |
| Logs | Loki + Promtail | 2.9.0 |
| Dashboard SOC | Grafana | 10.2.0 |
| Serveur | Gunicorn (Docker) / runserver (local) | 21.2.0 |

---

## 3. Prérequis

**Option Docker (recommandé) :**
- Docker >= 24
- Docker Compose >= 2.20
- 4 Go RAM minimum

**Option locale :**
- Python >= 3.11
- PostgreSQL >= 14
- Flutter SDK >= 3.0
- Android Studio + émulateur (API 30+)

---

## 4. Lancement avec Docker

```bash
# 1. Cloner le projet
git clone <url> && cd PFE

# 2. Lancer tous les services
docker compose up --build

# 3. Créer un compte administrateur (dans un second terminal)
docker compose exec backend python manage.py createsuperuser
```

> Les migrations sont appliquées **automatiquement** au démarrage du backend.

### Services disponibles

| Service | URL | Identifiants |
|---------|-----|-------------|
| API REST | http://localhost:8000/api/ | — |
| Documentation Swagger | http://localhost:8000/api/docs/ | — |
| Admin Django | http://localhost:8000/admin/ | superuser |
| App Web (Flutter) | http://localhost:80 | — |
| Grafana SOC | http://localhost:3000 | admin / SedadSOC2024! |
| Loki (logs) | http://localhost:3100 | — |

---

## 5. Lancement sans Docker (local)

### Backend

```bash
cd backend

# Créer et activer le venv
python -m venv venv
source venv/bin/activate        # Linux/Mac
# .\venv\Scripts\activate       # Windows

# Installer les dépendances
pip install -r requirements.txt

# Créer la base de données PostgreSQL
createdb sedad_bank

# Démarrer (migrations + serveur automatiquement)
bash run.sh
# → http://localhost:8000
```

### Frontend Flutter

```bash
cd frontend/sedad_bank
flutter pub get
flutter run                     # Émulateur Android
# OU
flutter run -d chrome           # Navigateur web
```

---

## 6. API Reference complète

**Base URL :** `http://localhost:8000/api/`
**Documentation interactive :** http://localhost:8000/api/docs/

> Toutes les routes sauf `/auth/` nécessitent :
> `Authorization: Bearer <access_token>`

---

### 6.1 Authentification

#### Inscription — POST /api/auth/register/

```bash
curl -s -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "username": "mohamedou",
    "email": "mohamedou@rss.mr",
    "password": "MotDePasse123!",
    "first_name": "Mohamedou",
    "last_name": "Diallo",
    "phone_number": "+22200000001"
  }' | python -m json.tool
```

Réponse `201` :
```json
{ "message": "Utilisateur créé avec succès", "status": "success", "user": { "id": "...", "email": "mohamedou@rss.mr" } }
```

---

#### Connexion — POST /api/auth/login/

```bash
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "mohamedou@rss.mr", "password": "MotDePasse123!"}' \
  | python -m json.tool
```

Réponse `200` :
```json
{ "access": "eyJ...", "refresh": "eyJ...", "user": { "role": "client", ... } }
```

> Brute-force : après 5 échecs en 5 min → événement `BRUTE_FORCE` loggé + alerte email.

---

#### Rafraîchir le token — POST /api/auth/token/refresh/

```bash
curl -s -X POST http://localhost:8000/api/auth/token/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh": "eyJ..."}' | python -m json.tool
```

---

### 6.2 Utilisateurs

#### Mon profil — GET /api/users/me/

```bash
curl -s http://localhost:8000/api/users/me/ \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```

#### Modifier mon profil — PATCH /api/users/{id}/

```bash
curl -s -X PATCH http://localhost:8000/api/users/$USER_ID/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"first_name": "Nouveau Nom", "phone_number": "+22211111111"}' \
  | python -m json.tool
```

#### Changer le mot de passe — POST /api/users/change_password/

```bash
curl -s -X POST http://localhost:8000/api/users/change_password/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"old_password": "MotDePasse123!", "new_password": "Nouveau456!", "new_password_confirm": "Nouveau456!"}' \
  | python -m json.tool
```

---

### 6.3 Comptes bancaires

#### Lister mes comptes — GET /api/accounts/

```bash
curl -s http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```

Réponse :
```json
[{
  "id": "uuid...",
  "account_number": "RSS1A2B3C4D5E6F7G",
  "account_name": "Compte Courant",
  "account_type": "checking",
  "currency": "MRU",
  "balance": "50000.00",
  "available_balance": "50000.00",
  "status": "active"
}]
```

#### Créer un compte — POST /api/accounts/

```bash
curl -s -X POST http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"account_name": "Mon Épargne", "account_type": "savings", "currency": "MRU"}' \
  | python -m json.tool
```

#### Recharger un compte — POST /api/accounts/{id}/deposit/

```bash
curl -s -X POST http://localhost:8000/api/accounts/$ACCOUNT_ID/deposit/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50000}' | python -m json.tool
```

---

### 6.4 Transactions

#### Transactions envoyées — GET /api/transactions/

```bash
curl -s http://localhost:8000/api/transactions/ \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```

#### Transactions reçues — GET /api/transactions/received/

```bash
curl -s http://localhost:8000/api/transactions/received/ \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```

#### Effectuer un virement — POST /api/transactions/

```bash
curl -s -X POST http://localhost:8000/api/transactions/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"from_account\": \"$ACCOUNT_ID\",
    \"transaction_type\": \"transfer\",
    \"amount\": \"1000.00\",
    \"description\": \"Test virement\",
    \"to_phone\": \"+22200000002\"
  }" | python -m json.tool
```

Types disponibles : `transfer`, `payment`, `withdrawal`, `deposit`, `salary`

Réponse `201` :
```json
{
  "reference_number": "RSS4A7B2C1D",
  "amount": "1000.00",
  "currency": "MRU",
  "status": "completed",
  "transaction_fee": "0.00",
  "total_amount": "1000.00"
}
```

---

### 6.5 Administration

> Requiert un compte avec `role = "admin"`.

#### Liste des utilisateurs — GET /api/users/

```bash
curl -s http://localhost:8000/api/users/ \
  -H "Authorization: Bearer $ADMIN_TOKEN" | python -m json.tool
```

#### Modifier le statut d'un utilisateur — PATCH /api/users/{id}/update-status/

```bash
curl -s -X PATCH http://localhost:8000/api/users/$USER_ID/update-status/ \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "suspended"}' | python -m json.tool
```

Statuts : `active`, `suspended`, `blocked`, `closed`

---

## 7. Application Flutter

### Écrans

| Onglet | Description |
|--------|-------------|
| Accueil | Carte bancaire verte + services rapides |
| Historique | Transactions envoyées et reçues |
| QR | Générer, partager, scanner un QR de paiement |
| Ma Banque | Gestion des comptes, création |
| Profil | Infos personnelles, changement de MDP |

### Fonctionnement QR
- Génère un QR contenant les infos du compte (JSON)
- Partage ou télécharge en PNG (`rss_qr.png`)
- Scan caméra pour payer un autre utilisateur

---

## 8. SOC — Monitoring & Alertes

### Pipeline

```
Backend Django
    |
    +-- security.log --> Promtail --> Loki --> Grafana --> Email
    +-- access.log   --> Promtail --> Loki --> Grafana --> Dashboard
```

### Événements détectés

| Événement | Condition |
|-----------|-----------|
| `LOGIN_FAILED` | Mauvais mot de passe |
| `BRUTE_FORCE` | >= 5 échecs en 5 min (même IP) |
| `SQL_INJECTION` | Pattern SQL dans la requête |
| `XSS` | `<script>`, `onerror=`, `javascript:` |
| `PATH_TRAVERSAL` | `../` dans l'URL |
| `UNAUTHORIZED` | HTTP 401 |
| `FORBIDDEN` | HTTP 403 |

### Format des logs (JSON)

```json
{"ts":"2026-02-26T10:30:00Z","event":"BRUTE_FORCE","ip":"192.168.1.1","method":"POST","path":"/api/auth/login/","attempts":6}
```

### Grafana
- URL : http://localhost:3000
- Identifiants : `admin` / `SedadSOC2024!`
- Dashboard : **RSS BANK SOC**
- Alertes email : 1 seul email par attaque (pas de spam), silence 12h

---

## 9. Guide de test complet

> Suivre ces étapes dans l'ordre pour tout tester avant la remise.

---

### Étape 1 — Vérifier que tous les services tournent

```bash
cd PFE
docker compose up --build

# Dans un autre terminal
docker compose ps
```

Résultat attendu — tous les services `Up` :
```
NAME         STATUS
backend      Up
db           Up (healthy)
frontend     Up
grafana      Up
loki         Up (healthy)
promtail     Up
```

---

### Étape 2 — Créer le superadmin

```bash
docker compose exec backend python manage.py createsuperuser
# Email    : admin@rss.mr
# Password : Admin123!
```

---

### Étape 3 — Vérifier l'API via Swagger

Ouvrir **http://localhost:8000/api/docs/** dans le navigateur.

On doit voir tous les endpoints documentés. Tester directement depuis l'interface Swagger.

---

### Étape 4 — Tester l'inscription et la connexion

```bash
# Inscription
curl -s -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@rss.mr","password":"Test123!","first_name":"Test","last_name":"User"}' \
  | python -m json.tool

# Connexion — copier le champ "access"
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","password":"Test123!"}' \
  | python -m json.tool

# Définir le token pour la suite
TOKEN="COLLER_LE_TOKEN_access_ICI"
```

---

### Étape 5 — Tester les comptes bancaires

```bash
# Créer un compte
curl -s -X POST http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"account_name":"Compte Principal","account_type":"checking","currency":"MRU"}' \
  | python -m json.tool

# Récupérer l'ID du compte
ACCOUNT_ID=$(curl -s http://localhost:8000/api/accounts/ \
  -H "Authorization: Bearer $TOKEN" \
  | python -m json.tool | grep '"id"' | head -1 | cut -d'"' -f4)
echo "Account ID : $ACCOUNT_ID"

# Recharger avec 50 000 MRU
curl -s -X POST "http://localhost:8000/api/accounts/$ACCOUNT_ID/deposit/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50000}' | python -m json.tool
```

---

### Étape 6 — Tester un virement

```bash
# Créer un second utilisateur
curl -s -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"username":"user2","email":"user2@rss.mr","password":"Test123!","first_name":"User","last_name":"Deux"}' \
  | python -m json.tool

# Effectuer un virement vers user2
curl -s -X POST http://localhost:8000/api/transactions/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"from_account\":\"$ACCOUNT_ID\",\"transaction_type\":\"transfer\",\"amount\":\"1000.00\",\"description\":\"Test virement PFE\",\"to_phone\":\"+22200000002\"}" \
  | python -m json.tool

# Vérifier l'historique
curl -s http://localhost:8000/api/transactions/ \
  -H "Authorization: Bearer $TOKEN" | python -m json.tool
```

---

### Étape 7 — Tester le changement de mot de passe

```bash
curl -s -X POST http://localhost:8000/api/users/change_password/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"old_password":"Test123!","new_password":"NewPass456!","new_password_confirm":"NewPass456!"}' \
  | python -m json.tool
```

---

### Étape 8 — Vérifier les logs SOC en direct

```bash
# Terminal 1 — événements sécurité
tail -f backend/logs/security.log | python -m json.tool

# Terminal 2 — toutes les requêtes HTTP
tail -f backend/logs/access.log | python -m json.tool
```

---

### Étape 9 — Tester l'application Flutter

```bash
cd frontend/sedad_bank && flutter run
```

Scénario complet dans l'app :
1. Inscription → nouveau compte
2. Connexion → voir la carte bancaire **verte RSS BANK**
3. Onglet QR → générer son QR, le télécharger, scanner
4. Ma Banque → créer un second compte épargne
5. Historique → vérifier les transactions
6. Profil → changer le mot de passe

---

### Étape 10 — Vérifier Grafana

1. Ouvrir http://localhost:3000
2. Login : `admin` / `SedadSOC2024!`
3. Aller dans **Dashboards → RSS BANK SOC**
4. Vérifier les graphiques : requêtes/min, codes HTTP, événements sécurité

---

## 10. Tests de sécurité

### Lancer le script d'attaque complet

```bash
cd PFE
chmod +x hack.sh

# Attaquer en local
./hack.sh

# Attaquer depuis une autre machine (remplacer l'IP)
./hack.sh http://192.168.1.50:8000
```

Le script teste en 6 phases : Reconnaissance, Scan endpoints, Brute Force (25 mots), SQL Injection (12 payloads), XSS (6 payloads), Bypass Auth.

À la fin : rapport avec **score de sécurité** et liste des vulnérabilités.

### Observer les détections en direct

```bash
# Dans un terminal séparé, avant de lancer hack.sh
tail -f backend/logs/security.log | python -m json.tool
```

On voit apparaître :
```json
{"ts":"...","event":"BRUTE_FORCE","ip":"127.0.0.1","attempts":6}
{"ts":"...","event":"SQL_INJECTION","ip":"127.0.0.1","method":"POST"}
{"ts":"...","event":"XSS","ip":"127.0.0.1","method":"POST"}
```

### Alertes email

Si SMTP Gmail configuré dans `.env` :
```env
SMTP_HOST=smtp.gmail.com:587
SMTP_USER=votre@gmail.com
SMTP_PASSWORD=app-password-16-chars
```

→ Email reçu après 30s d'activité d'attaque. Silence de 12h entre deux emails du même type.

### Test manuel rapide

```bash
# Brute force (déclenche l'alerte après 5 tentatives)
for i in {1..6}; do
  curl -s -X POST http://localhost:8000/api/auth/login/ \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@rss.mr\",\"password\":\"wrong$i\"}"
  echo ""
done

# SQL Injection (détectée par le middleware)
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"admin OR 1=1--","password":"x"}'

# XSS (détectée par le middleware)
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"<script>alert(1)</script>","password":"x"}'
```

---

## 11. Structure du projet

```
PFE/
+-- docker-compose.yml        # Orchestration complète (6 services)
+-- .env                      # SMTP pour alertes Grafana
+-- hack.sh                   # Script de test de sécurité (bash, sans dépendances)
+-- README.md                 # Ce fichier
|
+-- backend/                  # API Django REST Framework
|   +-- Dockerfile            # Python 3.11 + gunicorn
|   +-- run.sh                # Migrations auto + gunicorn (Docker) ou runserver (local)
|   +-- requirements.txt      # 10 dépendances Python
|   +-- .env                  # DB + SECRET_KEY
|   +-- logs/
|   |   +-- security.log      # Événements SOC (JSON) — lu par Promtail
|   |   +-- access.log        # Toutes les requêtes HTTP (JSON)
|   |   +-- django.log        # Logs applicatifs
|   +-- fintech_bank/
|   |   +-- settings.py       # Config : JWT, CORS, PostgreSQL, Logging
|   |   +-- urls.py           # Routes : /api/, /admin/, /api/docs/
|   +-- apps/core/
|       +-- models.py         # User, Account, Card, Transaction, Beneficiary
|       +-- views.py          # ViewSets REST API
|       +-- serializers.py    # Validation et sérialisation DRF
|       +-- urls.py           # Routage des endpoints
|       +-- security_middleware.py  # Détection SQL/XSS/BruteForce → logs JSON
|       +-- migrations/       # 3 migrations (initial, beneficiary fix, MRU)
|
+-- frontend/sedad_bank/      # Application Flutter
|   +-- pubspec.yaml          # Dépendances (Provider, GoRouter, Dio, QR...)
|   +-- lib/
|       +-- main.dart         # Point d'entrée, restauration de session JWT
|       +-- core/
|       |   +-- services/api_service.dart   # Client HTTP Dio (baseUrl auto)
|       |   +-- theme/app_theme.dart        # Thème vert RSS BANK
|       +-- models/           # user_model, account_model, transaction_model
|       +-- providers/        # auth, account, transaction, user (ChangeNotifier)
|       +-- routes/app_routes.dart  # GoRouter + garde d'auth
|       +-- widgets/          # bank_card_widget, main_shell, app_drawer
|       +-- screens/          # 20 écrans (auth, home, services, qr, admin...)
|
+-- soc/                      # Security Operations Center
    +-- loki.yml              # Stockage des logs
    +-- promtail.yml          # Collecte logs → Loki (position persistante)
    +-- grafana/
        +-- grafana.ini       # Config SMTP
        +-- provisioning/
            +-- alerting/     # 5 règles d'alertes + policies (repeat 12h)
            +-- dashboards/   # Dashboard RSS BANK SOC
```

---

## Modèles de données

```
User (UUID)
 +-- role      : client / admin / agent
 +-- status    : active / suspended / blocked / closed
 +-- kyc_status: pending / approved / rejected

Account (UUID)
 +-- account_number : RSS + 12 chars (ex: RSS1A2B3C4D5E6F)
 +-- account_type   : checking / savings
 +-- currency       : MRU / DZD / USD / EUR
 +-- balance, available_balance

Transaction (UUID)
 +-- transaction_type : transfer / payment / withdrawal / deposit / salary
 +-- status           : pending / processing / completed / failed / reversed
 +-- reference_number : RSS + 8 chars (ex: RSS4A7B2C1)
 +-- ip_address       (pour SOC)

Card (UUID)
 +-- card_type  : debit / credit / virtual
 +-- card_brand : VISA / MASTERCARD / AMEX
```

---

*RSS BANK — Projet de Fin d'Études | 2025-2026*
