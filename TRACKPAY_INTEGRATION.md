# Intégration RSS Bank ↔ TrackPay

## Contexte

Dans l'app RSS Bank, l'utilisateur peut payer/recharger un compte **TrackPay** depuis l'écran **Paiements → GIMTEL → TrackPay** (numéro de téléphone + montant).

Répartition des rôles :
- **RSS Bank** = source de l'argent. Débite le client, appelle TrackPay, gère l'historique.
- **TrackPay** = destinataire. Doit exposer 2 endpoints HTTPS que RSS Bank appellera en serveur-à-serveur.

RSS Bank a déjà implémenté son côté (débit, appel, remboursement automatique en cas d'échec, historique). **Il ne manque que ces 2 endpoints côté TrackPay** pour activer l'intégration en production.

---

## Ce qu'il nous faut de votre côté : 2 endpoints

### 1. Vérifier un compte — `POST /api/partners/rss-bank/accounts/resolve`

Appelé avant d'afficher la confirmation de paiement, pour vérifier que le numéro existe bien chez vous.

**Requête (RSS Bank → TrackPay) :**
```http
POST /api/partners/rss-bank/accounts/resolve
X-API-KEY: <clé fournie par vous>
Content-Type: application/json

{
  "phone": "22000000"
}
```

**Réponse attendue si le compte existe (200) :**
```json
{
  "exists": true,
  "accountName": "Mohamed Ahmed",
  "accountStatus": "ACTIVE"
}
```

**Réponse attendue si le compte n'existe pas (404) :**
```json
{
  "exists": false
}
```

---

### 2. Exécuter le paiement — `POST /api/partners/rss-bank/payments`

Appelé une fois que RSS Bank a débité son client. TrackPay doit créditer le compte correspondant et confirmer.

**Requête (RSS Bank → TrackPay) :**
```http
POST /api/partners/rss-bank/payments
X-API-KEY: <clé fournie par vous>
Content-Type: application/json

{
  "reference": "TXNE0NM7XBI",
  "phone": "22000000",
  "amount": "1000",
  "currency": "MRU",
  "senderName": "Sidatt Belkhair"
}
```

**Réponse attendue en cas de succès (200) :**
```json
{
  "status": "SUCCESS",
  "trackPayReference": "TP-2026-88991",
  "message": "Payment received"
}
```

**Réponse attendue en cas d'échec (200, avec status FAILED — pas un code HTTP d'erreur) :**
```json
{
  "status": "FAILED",
  "message": "Compte invalide ou paiement refusé"
}
```

> Si TrackPay renvoie autre chose que `200 + status=SUCCESS`, **RSS Bank annule automatiquement le débit du client** (remboursement immédiat) — donc en cas de doute, répondez `FAILED` plutôt que de planter silencieusement.

---

## Sécurité requise

| Élément | Détail |
|---|---|
| **Authentification** | Header `X-API-KEY` sur chaque requête — vous nous fournissez la clé, on vous fournit la nôtre si vous nous appelez aussi |
| **HTTPS obligatoire** | Pas de HTTP en production |
| **Idempotence** | Le champ `reference` (ex: `TXNE0NM7XBI`) est unique par paiement. **Si vous recevez deux fois la même `reference`, ne créditez qu'une seule fois.** |
| **Timeout** | RSS Bank attend votre réponse max 15 secondes sur `/payments` — au-delà, on considère l'appel en échec et on rembourse le client |

---

## Informations à nous fournir pour activer l'intégration

- [ ] URL de base de votre API (ex: `https://api.trackpay.mr`)
- [ ] Clé API (`X-API-KEY`) à utiliser pour vous appeler
- [ ] Si vous avez besoin d'une clé de notre côté pour nous appeler en retour, on vous la fournit
- [ ] Environnement de test (sandbox) si disponible, pour qu'on valide l'intégration avant la mise en prod

---

## Déjà testé côté RSS Bank

Le parcours complet (débit → appel → crédit confirmé, et débit → appel → échec → remboursement automatique) a été validé avec un service de simulation interne reproduisant exactement ce contrat. Dès que vos 2 endpoints sont prêts (même en sandbox), on peut basculer et tester en conditions réelles immédiatement.
