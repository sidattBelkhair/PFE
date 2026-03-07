# RSS BANK — Application Bancaire Mobile

> Projet de Fin d'Études (PFE) — Application bancaire mobile complète avec système SOC intégré

---

## Table des matières

1. [Présentation](#1-présentation)
2. [Architecture](#2-architecture)
3. [Prérequis](#3-prérequis)
4. [Lancement avec Docker](#4-lancement-avec-docker)
5. [Lancement sans Docker (local)](#5-lancement-sans-docker-local)
6. [Configuration Email Gmail](#6-configuration-email-gmail)
7. [API Reference complète](#7-api-reference-complète)
8. [Application Flutter](#8-application-flutter)
9. [Multi-langue FR / AR](#9-multi-langue-fr--ar)
10. [SOC — Monitoring & Alertes](#10-soc--monitoring--alertes)
11. [Guide de test complet](#11-guide-de-test-complet)
12. [Tests de sécurité](#12-tests-de-sécurité)
13. [Structure du projet](#13-structure-du-projet)
14. [Modèles de données](#14-modèles-de-données)

---

## 1. Présentation

**RSS BANK** est une plateforme bancaire mobile développée dans le cadre d'un PFE.

### Fonctionnalités

- **Inscription** avec vérification email par code OTP (6 chiffres, expire en 10 min)
- **Mot de passe oublié** → code OTP par email → réinitialisation
- Gestion de comptes bancaires (courant / épargne) en **MRU** (Ouguiya Mauritanien)
- Virements via numéro de téléphone ou **QR Code**
- Services : recharge, retraits, paiements, factures
- Authentification JWT avec protection **anti brute-force**
- **Multi-langue Français / Arabe** (RTL automatique)
- **SOC** (Security Operations Center) : Loki + Promtail + Grafana
- Détection automatique : SQL Injection, XSS, Path Traversal, Brute Force
- Dashboard administrateur (gestion des statuts utilisateurs)

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
| Auth | JWT (SimpleJWT) | 60min access / 1j refresh |
| Email OTP | Gmail SMTP | — |
| Logs | Loki + Promtail | 2.9.0 |
| Dashboard SOC | Grafana | 10.2.0 |
| Serveur | Gunicorn (Docker) / runserver (local) | — |

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
- Compte Gmail avec mot de passe d'application (pour l'envoi des OTP)

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

# Configurer les variables d'environnement
# Éditer le fichier .env (voir section 6 pour l'email)

# Créer la base de données PostgreSQL
psql -U postgres -c "CREATE DATABASE sedad_bank;"

# Appliquer toutes les migrations
python manage.py migrate

# (Optionnel) Créer un superadmin
python manage.py createsuperuser

# Lancer le serveur
python manage.py runserver
# → http://127.0.0.1:8000
```

### Frontend Flutter

```bash
cd frontend/sedad_bank

# Installer les dépendances
flutter pub get

# Générer les fichiers de localisation (FR/AR)
flutter gen-l10n

# Lancer sur émulateur Android
flutter run

# Vérifier la qualité du code (doit afficher 0 erreurs, 0 warnings)
flutter analyze
```

> Sur émulateur Android, l'API est accessible via `http://10.0.2.2:8000/api/`
> Sur appareil physique (même réseau Wi-Fi), utiliser l'IP locale du PC.

---

## 6. Configuration Email Gmail

Les codes OTP sont envoyés par email (inscription + mot de passe oublié).

### Étapes

1. Aller sur [myaccount.google.com](https://myaccount.google.com) avec le compte Gmail de l'app
2. **Sécurité** → activer **Validation en deux étapes**
3. **Sécurité** → **Mots de passe des applications** → choisir "Autre (nom personnalisé)" → `RSS BANK`
4. Google génère un code de **16 caractères** (ex: `abcdefghijklmnop`)
5. Copier ce code **sans espaces** dans `backend/.env` :

```env
EMAIL_HOST_USER=rssbank700@gmail.com
EMAIL_HOST_PASSWORD=abcdefghijklmnop
```

6. Redémarrer le serveur Django

> Si les credentials sont absents ou invalides, Django affiche le code OTP dans le terminal (mode console) — pratique pour le développement.

### Fichier `backend/.env` complet

```env
SECRET_KEY=django-insecure-change-this-in-production
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1,10.0.2.2

# Base de données PostgreSQL
DB_ENGINE=django.db.backends.postgresql
DB_NAME=sedad_bank
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=localhost
DB_PORT=5432

# Email Gmail SMTP
EMAIL_HOST_USER=votre_email@gmail.com
EMAIL_HOST_PASSWORD=motdepasse16caract
```

---

## 7. API Reference complète

**Base URL :** `http://localhost:8000/api/`
**Documentation interactive :** http://localhost:8000/api/docs/

> Toutes les routes sauf `/auth/` nécessitent :
> `Authorization: Bearer <access_token>`

---

### 7.1 Authentification & OTP

#### Inscription — POST /api/auth/register/

Crée le compte et envoie automatiquement un OTP de vérification à l'email.

```bash
curl -s -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "mohamedou@rss.mr",
    "password": "MotDePasse123!",
    "password_confirm": "MotDePasse123!",
    "first_name": "Mohamedou",
    "last_name": "Diallo",
    "phone_number": "+22200000001"
  }' | python -m json.tool
```

Réponse `201` :
```json
{
  "message": "Compte créé. Vérifiez votre email pour le code de confirmation.",
  "email": "mohamedou@rss.mr",
  "status": "pending_verification"
}
```

---

#### Vérifier l'email — POST /api/auth/verify-email/

```bash
curl -s -X POST http://localhost:8000/api/auth/verify-email/ \
  -H "Content-Type: application/json" \
  -d '{"email": "mohamedou@rss.mr", "code": "123456"}' \
  | python -m json.tool
```

Réponse `200` :
```json
{ "message": "Email vérifié avec succès. Vous pouvez vous connecter." }
```

---

#### Renvoyer un code OTP — POST /api/auth/resend-otp/

```bash
curl -s -X POST http://localhost:8000/api/auth/resend-otp/ \
  -H "Content-Type: application/json" \
  -d '{"email": "mohamedou@rss.mr", "type": "verify_email"}' \
  | python -m json.tool
```

Types : `verify_email` · `reset_password`

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

> Brute-force : après 5 échecs en 5 min → événement `BRUTE_FORCE` dans les logs.

---

#### Rafraîchir le token — POST /api/auth/token/refresh/

```bash
curl -s -X POST http://localhost:8000/api/auth/token/refresh/ \
  -H "Content-Type: application/json" \
  -d '{"refresh": "eyJ..."}' | python -m json.tool
```

---

#### Mot de passe oublié — POST /api/auth/forgot-password/

Envoie un OTP de réinitialisation à l'email.

```bash
curl -s -X POST http://localhost:8000/api/auth/forgot-password/ \
  -H "Content-Type: application/json" \
  -d '{"email": "mohamedou@rss.mr"}' | python -m json.tool
```

---

#### Réinitialiser le mot de passe — POST /api/auth/reset-password/

```bash
curl -s -X POST http://localhost:8000/api/auth/reset-password/ \
  -H "Content-Type: application/json" \
  -d '{
    "email": "mohamedou@rss.mr",
    "code": "654321",
    "new_password": "NouveauPass456!",
    "new_password_confirm": "NouveauPass456!"
  }' | python -m json.tool
```

---

### 7.2 Utilisateurs

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

#### Modifier le statut (admin) — PATCH /api/users/{id}/update-status/

```bash
curl -s -X PATCH http://localhost:8000/api/users/$USER_ID/update-status/ \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "suspended"}' | python -m json.tool
```

Statuts : `active` · `suspended` · `blocked` · `closed`

---

### 7.3 Comptes bancaires

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
curl -s -X POST "http://localhost:8000/api/accounts/$ACCOUNT_ID/deposit/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"amount": 50000}' | python -m json.tool
```

---

### 7.4 Transactions

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

#### Effectuer une opération — POST /api/transactions/

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

Types : `transfer` · `payment` · `withdrawal` · `deposit` · `salary`

Réponse `201` :
```json
{
  "reference_number": "TXN4A7B2C1D",
  "amount": "1000.00",
  "currency": "MRU",
  "status": "completed",
  "transaction_fee": "0.00",
  "total_amount": "1000.00"
}
```

---

## 8. Application Flutter

### Navigation (5 onglets)

| Onglet | Route | Description |
|--------|-------|-------------|
| Accueil | `/home` | Carte bancaire + grille services (6 actions) |
| Historique | `/history` | Transactions avec filtres et groupement par date |
| QR | `/qr-transactions` | Générer, partager, scanner un QR de paiement |
| Ma Banque | `/ma-banque` | Liste des comptes, création de compte |
| Profil | `/profile` | Infos, changement MDP, langue |

### Écrans d'authentification

| Route | Écran | Description |
|-------|-------|-------------|
| `/login` | LoginScreen | Connexion email + mot de passe |
| `/register` | RegisterScreen | Inscription avec tous les champs |
| `/verify-email` | VerifyEmailScreen | Saisie code OTP 6 chiffres + timer 10 min |
| `/forgot-password` | ForgotPasswordScreen | Saisie email pour reset |
| `/reset-password` | ResetPasswordScreen | Code OTP + nouveau mot de passe |

### Services disponibles

| Service | Route | Description |
|---------|-------|-------------|
| Virement | `/transfer` | Transfert vers numéro de téléphone |
| Recharge | `/recharge` | Crédit téléphonique |
| Retrait | `/retraits` | Retrait espèces |
| Paiement | `/paiements` | Paiement marchand |
| Factures | `/paiement-factures` | Eau, électricité, internet |
| Plus | `/plus-services` | Autres services |

### Fonctionnement QR

- Génère un QR contenant les informations du compte (JSON)
- Partage ou télécharge en PNG (`rss_qr.png`)
- Scanner la caméra pour payer un autre utilisateur

### State Management (Provider)

| Provider | Rôle |
|----------|------|
| `AuthProvider` | Session JWT, login, register, OTP, changePassword |
| `AccountProvider` | Liste comptes, création, sélection |
| `TransactionProvider` | Transactions envoyées + reçues, création |
| `UserProvider` | Liste utilisateurs (admin) |
| `LanguageProvider` | Locale FR/AR, persistance SharedPreferences |

---

## 9. Multi-langue FR / AR

L'app supporte le **Français** et l'**Arabe** avec direction **RTL automatique**.

### Changer la langue dans l'app

- Depuis le **Profil** (onglet 5) → carte Langue → boutons FR / AR
- Depuis le **Drawer** (menu hamburger) → boutons FR / AR
- Le choix est **sauvegardé** et restauré au prochain lancement

### Fichiers de traduction

```
frontend/sedad_bank/lib/l10n/
├── app_fr.arb    ← Français (langue par défaut)
└── app_ar.arb    ← Arabe
```

### Ajouter une clé de traduction

1. Ajouter dans `app_fr.arb` :
   ```json
   "maCle": "Mon texte en français"
   ```
2. Ajouter dans `app_ar.arb` :
   ```json
   "maCle": "نصي بالعربية"
   ```
3. Régénérer :
   ```bash
   flutter gen-l10n
   ```
4. Utiliser dans un écran :
   ```dart
   final l = AppLocalizations.of(context)!;
   Text(l.maCle)
   ```

### Clés disponibles (principales)

| Clé | Français | Arabe |
|-----|----------|-------|
| `appName` | RSS BANK | بنك RSS |
| `login` | Connexion | تسجيل الدخول |
| `register` | Inscription | إنشاء حساب |
| `verifyEmail` | Vérification email | التحقق من البريد الإلكتروني |
| `forgotPasswordTitle` | Mot de passe oublié ? | نسيت كلمة المرور؟ |
| `home` | Accueil | الرئيسية |
| `history` | Historique | السجل |
| `myBank` | Ma banque | بنكي |
| `profile` | Profil | الملف الشخصي |
| `transfer` | Virement | تحويل |
| `balance` | Solde disponible | الرصيد المتاح |
| `logout` | Déconnexion | تسجيل الخروج |

---

## 10. SOC — Monitoring & Alertes

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
| `LOGIN_SUCCESS` | Connexion réussie |
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

### Fichiers de logs

| Fichier | Contenu |
|---------|---------|
| `backend/logs/access.log` | Toutes les requêtes HTTP (méthode, URL, IP, statut, durée) |
| `backend/logs/django.log` | Erreurs Django (DEBUG, WARNING, ERROR) |
| `backend/logs/security.log` | Événements de sécurité (JSON) |

### Grafana

- URL : http://localhost:3000
- Identifiants : `admin` / `SedadSOC2024!`
- Dashboard : **RSS BANK SOC**
- Alertes email : 1 seul email par attaque (silence 12h)

---

## 11. Guide de test complet

> Suivre ces étapes dans l'ordre pour tout tester avant la remise.

---

### Étape 1 — Vérifier que tous les services tournent

```bash
docker compose up --build

# Dans un autre terminal
docker compose ps
```

Résultat attendu — tous `Up` :
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

### Étape 3 — Tester l'inscription avec vérification email

```bash
# Inscription → reçoit un OTP par email
curl -s -X POST http://localhost:8000/api/auth/register/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","password":"Test123!","password_confirm":"Test123!","first_name":"Test","last_name":"User","phone_number":"+22200000001"}' \
  | python -m json.tool

# (Si pas de Gmail configuré, voir le code OTP dans le terminal Django)

# Vérifier l'email avec le code reçu
curl -s -X POST http://localhost:8000/api/auth/verify-email/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","code":"123456"}' \
  | python -m json.tool

# Connexion
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","password":"Test123!"}' \
  | python -m json.tool

# Définir le token pour la suite
TOKEN="COLLER_LE_TOKEN_access_ICI"
```

---

### Étape 4 — Tester mot de passe oublié

```bash
# Envoyer un OTP de reset
curl -s -X POST http://localhost:8000/api/auth/forgot-password/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr"}' | python -m json.tool

# Réinitialiser avec le code reçu
curl -s -X POST http://localhost:8000/api/auth/reset-password/ \
  -H "Content-Type: application/json" \
  -d '{"email":"test@rss.mr","code":"654321","new_password":"NewPass456!","new_password_confirm":"NewPass456!"}' \
  | python -m json.tool
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
  | python -c "import sys,json; data=json.load(sys.stdin); print(data[0]['id'])")
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
# Effectuer un virement
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

### Étape 7 — Tester l'application Flutter

```bash
cd frontend/sedad_bank && flutter run
```

Scénario complet dans l'app :
1. **Inscription** → email reçu avec code OTP → saisir le code → compte vérifié
2. **Connexion** → voir la carte bancaire RSS BANK
3. Onglet **QR** → générer son QR, le télécharger, scanner
4. **Ma Banque** → créer un compte épargne
5. **Historique** → filtres Tous / Virements / Reçus
6. **Profil** → changer le mot de passe, basculer en **Arabe** → toute l'app en arabe RTL
7. **Mot de passe oublié** depuis l'écran de connexion

---

### Étape 8 — Vérifier les logs SOC en direct

```bash
# Événements sécurité
tail -f backend/logs/security.log | python -m json.tool

# Toutes les requêtes HTTP
tail -f backend/logs/access.log | python -m json.tool
```

---

### Étape 9 — Vérifier Grafana

1. Ouvrir http://localhost:3000
2. Login : `admin` / `SedadSOC2024!`
3. Aller dans **Dashboards → RSS BANK SOC**
4. Vérifier : requêtes/min, codes HTTP, événements sécurité

---

## 12. Tests de sécurité

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

### Test manuel brute-force

```bash
# Déclenche l'alerte après 5 tentatives
for i in {1..6}; do
  curl -s -X POST http://localhost:8000/api/auth/login/ \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"admin@rss.mr\",\"password\":\"wrong$i\"}"
  echo ""
done
```

### Test SQL Injection

```bash
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"admin OR 1=1--","password":"x"}'
```

### Test XSS

```bash
curl -s -X POST http://localhost:8000/api/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email":"<script>alert(1)</script>","password":"x"}'
```

---

## 13. Structure du projet

```
PFE/
├── docker-compose.yml           # Orchestration complète (6 services)
├── .env                         # SMTP pour alertes Grafana
├── hack.sh                      # Script de test de sécurité
├── README.md                    # Ce fichier
│
├── backend/                     # API Django REST Framework
│   ├── Dockerfile               # Python 3.11 + gunicorn
│   ├── run.sh                   # Migrations auto + lancement serveur
│   ├── requirements.txt         # Dépendances Python
│   ├── .env                     # DB + SECRET_KEY + Email Gmail
│   ├── logs/
│   │   ├── security.log         # Événements SOC (JSON)
│   │   ├── access.log           # Toutes les requêtes HTTP (JSON)
│   │   └── django.log           # Logs applicatifs
│   ├── fintech_bank/
│   │   ├── settings.py          # Config Django (JWT, CORS, DB, Email, Logging)
│   │   └── urls.py              # Routes : /api/, /admin/, /api/docs/
│   └── apps/core/
│       ├── models.py            # User, UserProfile (OTP), Account, Card, Transaction
│       ├── views.py             # ViewSets + vues OTP (Register, VerifyEmail, ForgotPassword...)
│       ├── serializers.py       # Validation DRF (inscription avec UUID username, OTP)
│       ├── urls.py              # Endpoints API
│       ├── security_middleware.py  # Détection SQL/XSS/BruteForce → logs JSON
│       └── migrations/
│           ├── 0001_initial.py
│           ├── 0002_fix_beneficiary_account_number.py
│           ├── 0003_add_mru_currency.py
│           └── 0004_userprofile_otp_code_...py  # Champs OTP sur UserProfile
│
├── frontend/sedad_bank/         # Application Flutter
│   ├── pubspec.yaml             # Dépendances (Provider, GoRouter, Dio, QR, i18n...)
│   ├── l10n.yaml                # Config génération localizations
│   └── lib/
│       ├── main.dart            # Point d'entrée, session JWT, locale
│       ├── l10n/
│       │   ├── app_fr.arb       # ~80 clés en Français
│       │   └── app_ar.arb       # ~80 clés en Arabe
│       ├── core/
│       │   ├── services/api_service.dart   # Client HTTP Dio (baseUrl auto)
│       │   └── theme/app_theme.dart        # Couleurs et thème RSS BANK
│       ├── models/              # user_model, account_model, transaction_model
│       ├── providers/
│       │   ├── auth_provider.dart          # login, register, OTP, changePassword
│       │   ├── account_provider.dart       # comptes bancaires
│       │   ├── transaction_provider.dart   # transactions envoyées + reçues
│       │   ├── user_provider.dart          # liste utilisateurs (admin)
│       │   └── language_provider.dart      # locale FR/AR + SharedPreferences
│       ├── routes/app_routes.dart          # GoRouter + garde d'authentification
│       ├── widgets/
│       │   ├── bank_card_widget.dart       # Carte bancaire avec toggle solde
│       │   ├── main_shell.dart             # Bottom nav 5 onglets
│       │   └── app_drawer.dart             # Drawer avec switcher langue
│       └── screens/
│           ├── auth/            # login, register, verify_email, forgot_password, reset_password
│           ├── home/            # home_screen (carte + services)
│           ├── transactions/    # transaction_history_screen, transfer_screen
│           ├── accounts/        # create_account_screen
│           ├── bank/            # ma_banque_screen
│           ├── profile/         # profile_screen
│           ├── services/        # paiements, recharge, retraits, factures, plus_services
│           ├── qr/              # qr_transactions_screen
│           └── admin/           # admin_dashboard_screen
│
└── soc/                         # Security Operations Center
    ├── loki.yml                 # Stockage des logs
    ├── promtail.yml             # Collecte logs → Loki
    └── grafana/
        ├── grafana.ini          # Config SMTP alertes
        └── provisioning/
            ├── alerting/        # 5 règles d'alertes + policies
            └── dashboards/      # Dashboard RSS BANK SOC
```

---

## 14. Modèles de données

```
User (UUID)
 ├── email, first_name, last_name, phone_number
 ├── role      : client / admin / agent
 ├── status    : active / suspended / blocked / closed
 ├── kyc_status: pending / approved / rejected
 └── two_factor_enabled, login_attempts, last_login_ip

UserProfile (OneToOne → User)
 ├── verified_email, verified_phone, verified_identity
 ├── otp_code, otp_expires_at         ← OTP 6 chiffres (expire 10 min)
 └── otp_type : verify_email / reset_password

Account (UUID)
 ├── account_number : RSSxxxxxxxxxxxx (généré automatiquement)
 ├── account_type   : checking / savings
 ├── currency       : MRU / DZD / USD / EUR
 └── balance, available_balance, status

Transaction (UUID)
 ├── transaction_type : transfer / payment / withdrawal / deposit / salary
 ├── status           : pending / processing / completed / failed / reversed
 ├── reference_number : TXNxxxxxxxx (unique)
 ├── amount, transaction_fee, total_amount, currency
 └── ip_address (pour SOC)

Card (UUID)
 ├── card_type  : debit / credit / virtual
 └── card_brand : VISA / MASTERCARD / AMEX

Beneficiary (UUID)
 ├── phone_number, beneficiary_name
 └── beneficiary_type : internal / external
```

---

*RSS BANK — Projet de Fin d'Études | 2025-2026*
*Application de banque digitale mobile pour la Mauritanie — Devise : MRU (Ouguiya Mauritanien)*
