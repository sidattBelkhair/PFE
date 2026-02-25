# Déploiement SEDAD BANK — Guide Cloud Gratuit

## Meilleure option : Oracle Cloud Always Free

**Pourquoi Oracle Cloud ?**
- 1 VM ARM A1 : 4 CPU + 24 GB RAM — GRATUIT À VIE
- Supporte Docker Compose complet (backend + frontend + SOC)
- IP publique fixe
- Aucune carte bancaire requise (vérification téléphone uniquement)

---

## Étape 1 — Créer le compte Oracle Cloud

1. Aller sur https://cloud.oracle.com/free
2. Créer un compte gratuit (utiliser une vraie adresse email)
3. Choisir la région : **Germany Central (Frankfurt)** ou **US East (Ashburn)**
4. Vérifier le numéro de téléphone

---

## Étape 2 — Créer la VM gratuite

Dans la console Oracle Cloud :

1. **Compute** → **Instances** → **Create Instance**
2. Nom : `sedad-bank-server`
3. Image : **Ubuntu 22.04** (recommandé)
4. Shape : `VM.Standard.A1.Flex` → **4 OCPU, 24 GB RAM** (gratuit)
5. Télécharger/coller votre clé SSH publique
6. **Create** → attendre 2 min

---

## Étape 3 — Configurer le firewall

Dans Oracle Cloud → Instance → **Virtual Cloud Network** → **Security Lists** :

Ajouter les règles entrantes :
| Port | Description |
|------|-------------|
| 22   | SSH |
| 80   | Frontend Flutter Web |
| 8000 | Backend Django API |
| 3000 | Grafana SOC Dashboard |

---

## Étape 4 — Installer Docker sur la VM

```bash
# Se connecter à la VM
ssh ubuntu@VOTRE_IP_ORACLE

# Installer Docker
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker ubuntu
newgrp docker

# Vérifier
docker --version
```

---

## Étape 5 — Déployer le projet

```bash
# Sur votre machine locale — pousser sur GitHub
cd /home/sidatt/PFE
git add .
git commit -m "Deploy: SOC + Docker setup"
git push origin main

# Sur la VM Oracle — cloner et lancer
git clone https://github.com/sidattBelkhair/PFE.git
cd PFE

# Configurer le SMTP (Gmail App Password)
nano .env
# Mettre vos vraies identifiants SMTP

# Lancer tout
docker compose up -d --build
```

---

## Étape 6 — Vérifier que tout tourne

```bash
docker compose ps

# Doit afficher : db, backend, frontend, loki, promtail, grafana
# Tous en status "Up"
```

---

## URLs publiques après déploiement

Remplacer `VOTRE_IP` par l'IP de la VM Oracle :

| Service | URL |
|---------|-----|
| Application Flutter Web | http://VOTRE_IP |
| API Django | http://VOTRE_IP:8000 |
| **Dashboard SOC Grafana** | **http://VOTRE_IP:3000** |

Login Grafana : `admin` / `SedadSOC2024!`

---

## Partager avec tes amis pour les attaques

Envoyer à tes amis :
```
Lien de l'app SEDAD BANK : http://VOTRE_IP

Créez un compte et testez les services.
Pour attaquer avec les scripts :
  python full_attack.py --url http://VOTRE_IP:8000 --email test@sedad.mr
```

Toi tu surveilles en temps réel sur : **http://VOTRE_IP:3000**

---

## Options alternatives (plus simples mais limitées)

### Option B : Railway (sans SOC)
- Seulement backend + frontend (pas Grafana/Loki)
- Gratuit jusqu'à $5/mois de crédit
- Lien : https://railway.app

### Option C : Render (sans SOC)
- Backend Django sur Render (gratuit, spin-down après 15min)
- Frontend Flutter sur Netlify/Vercel (gratuit)
- Database PostgreSQL sur Neon.tech (gratuit 0.5 GB)

---

## Récapitulatif par option

| Option | Gratuit | Docker Compose | SOC Grafana | Facilité |
|--------|---------|---------------|-------------|---------|
| Oracle Cloud | Oui (à vie) | Oui | Oui | Moyen |
| Railway | Partiel | Non | Non | Facile |
| Render + Netlify | Oui | Non | Non | Facile |
