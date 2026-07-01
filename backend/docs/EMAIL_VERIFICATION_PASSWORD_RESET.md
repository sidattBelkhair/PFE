# Service Email — Vérification de compte & Mot de passe oublié

Documentation pour intégrer correctement le système d'envoi d'email, de
vérification d'adresse email et de réinitialisation de mot de passe utilisé
dans le backend RSS Bank (Django + DRF).

---

## 1. Vue d'ensemble

| Brique | Détail |
|---|---|
| Envoi d'email | API HTTPS **Brevo** (ex-Sendinblue), via un backend Django custom |
| Stockage du code | Champ `otp_code` (6 chiffres) sur `UserProfile` |
| Type de code | `otp_type` = `"verify_email"` ou `"reset_password"` |
| Expiration | 10 minutes (`otp_expires_at`) |
| Envoi | Asynchrone via `threading.Thread` (pas de Celery) |
| Format email | Texte brut (pas de template HTML) |

Le **même mécanisme OTP** (code à 6 chiffres) sert à la fois pour la
vérification d'email à l'inscription et pour le reset de mot de passe — seul
le champ `otp_type` change.

---

## 2. Pourquoi Brevo et pas SMTP classique ?

Le port SMTP 587 est bloqué par défaut sur les VPS DigitalOcean (et beaucoup
d'hébergeurs cloud). Brevo expose une **API HTTPS (port 443)**, qui n'est
jamais bloquée. C'est pour ça qu'on n'utilise pas `EMAIL_HOST`/`EMAIL_PORT`
classiques mais un backend Django custom :

`apps/core/brevo_backend.py`
```python
class BrevoAPIBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        ...
        send_smtp_email = self._sdk.SendSmtpEmail(
            sender={'name': self.from_name, 'email': self.from_email},
            to=[{'email': to} for to in msg.to],
            subject=msg.subject,
            text_content=str(msg.body),
        )
        self.client.send_transac_email(send_smtp_email)
```

Ce backend respecte l'interface standard de Django (`BaseEmailBackend`), donc
le reste du code continue d'utiliser `django.core.mail.send_mail()` sans rien
changer.

---

## 3. Configuration requise (.env)

```bash
# Obligatoire pour activer Brevo (sinon fallback console = emails affichés
# dans les logs, rien n'est réellement envoyé)
BREVO_API_KEY=xkeysib-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Optionnel — adresse et nom affichés comme expéditeur
BREVO_FROM_EMAIL=rssbank700@gmail.com
BREVO_FROM_NAME=RSS Bank
```

Récupérer une clé API : compte Brevo → **SMTP & API** → **API Keys** → créer
une clé (commence toujours par `xkeysib-`).

### Logique de fallback (`fintech_bank/settings.py:240-249`)

```python
BREVO_API_KEY    = config('BREVO_API_KEY', default='')
BREVO_FROM_EMAIL = config('BREVO_FROM_EMAIL', default='rssbank700@gmail.com')
BREVO_FROM_NAME  = config('BREVO_FROM_NAME', default='RSS Bank')

if BREVO_API_KEY.startswith('xkeysib-'):
    EMAIL_BACKEND = 'apps.core.brevo_backend.BrevoAPIBackend'
    DEFAULT_FROM_EMAIL = BREVO_FROM_EMAIL
else:
    EMAIL_BACKEND = 'django.core.mail.backends.console.EmailBackend'
    DEFAULT_FROM_EMAIL = 'noreply@rssbank.mr'
```

⚠️ **Important** : si `BREVO_API_KEY` est vide ou mal formée, Django bascule
automatiquement sur le `console.EmailBackend` → les emails ne sont **jamais
envoyés réellement**, juste imprimés dans les logs du serveur. C'est pratique
en dev, mais source d'erreur classique en prod si la clé est oubliée dans le
`.env`.

### Dépendance Python requise

```
sib-api-v3-sdk==7.6.0
```
(déjà dans `requirements.txt` — vérifier qu'elle est bien installée si
quelqu'un clone le projet : `pip install -r requirements.txt`)

---

## 4. Modèle de données

`apps/core/models.py` — `UserProfile` (lié 1-to-1 à `User`)

```python
class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    verified_email = models.BooleanField(default=False)

    otp_code = models.CharField(max_length=6, null=True, blank=True)
    otp_expires_at = models.DateTimeField(null=True, blank=True)
    otp_type = models.CharField(max_length=20, null=True, blank=True)  # 'verify_email' | 'reset_password'
    ...
```

Migration associée : `apps/core/migrations/0004_userprofile_otp_code_userprofile_otp_expires_at_and_more.py`

Si vous intégrez ce système dans un **autre** projet Django, il faut a minima
ces 3 champs (`otp_code`, `otp_expires_at`, `otp_type`) sur le modèle lié à
l'utilisateur, plus un booléen `verified_email`.

---

## 5. Fonctions cœur (`apps/core/views.py`)

```python
def generate_otp():
    """Génère un code OTP à 6 chiffres."""
    return ''.join(random.choices(string.digits, k=6))

def send_otp_email(email, code, otp_type):
    subject = (
        "RSS BANK — Vérification de votre adresse email"
        if otp_type == 'verify_email'
        else "RSS BANK — Réinitialisation de votre mot de passe"
    )
    message = f"Votre code est : {code}\nCe code expire dans 10 minutes."

    def _send():
        send_mail(subject, message, settings.DEFAULT_FROM_EMAIL, [email])

    threading.Thread(target=_send, daemon=True).start()
```

L'envoi se fait dans un **thread daemon** pour ne pas bloquer la réponse HTTP
le temps que Brevo réponde. C'est volontairement simple (pas de retry, pas de
queue) — suffisant pour le volume actuel, mais à remplacer par Celery si le
volume d'emails augmente significativement.

---

## 6. Endpoints API

Base URL : `/api/auth/`

### A. Inscription + vérification email

| Étape | Méthode | URL | Body |
|---|---|---|---|
| 1. Inscription | `POST` | `/api/auth/register/` | `{email, phone_number, password, password_confirm, first_name, last_name}` |
| 2. Vérifier le code | `POST` | `/api/auth/verify-email/` | `{email, code}` |
| 3. Renvoyer un code | `POST` | `/api/auth/resend-otp/` | `{email, type: "verify_email"}` |

**Réponse à l'inscription :**
```json
{
  "message": "Compte créé. Vérifiez votre email pour le code de confirmation.",
  "email": "user@example.com",
  "status": "pending_verification"
}
```

**Réponse à la vérification réussie :**
```json
{ "message": "Email vérifié avec succès. Vous pouvez vous connecter." }
```

**Erreurs possibles** (`400`) : `"Code incorrect."`, `"Code expiré."`,
`"Utilisateur introuvable."`

### B. Mot de passe oublié

| Étape | Méthode | URL | Body |
|---|---|---|---|
| 1. Demander un code | `POST` | `/api/auth/forgot-password/` | `{email}` |
| 2. Réinitialiser | `POST` | `/api/auth/reset-password/` | `{email, code, new_password, new_password_confirm}` |

**Réponse à la demande (toujours la même, même si l'email n'existe pas)** :
```json
{ "message": "Si cet email existe, un code a été envoyé." }
```
→ Mesure de sécurité volontaire : ne révèle jamais si un email existe en base.

**Réponse au reset réussi :**
```json
{ "message": "Mot de passe réinitialisé avec succès. Connectez-vous." }
```

---

## 7. Schéma des flux

```
INSCRIPTION
  POST /register/ ─► crée User + UserProfile, génère OTP (type=verify_email)
                       envoie email Brevo en arrière-plan
  POST /verify-email/ ─► vérifie code + expiration ─► verified_email=True
                          efface otp_code/otp_expires_at/otp_type

MOT DE PASSE OUBLIÉ
  POST /forgot-password/ ─► si user existe : génère OTP (type=reset_password)
                              envoie email Brevo ; sinon ne fait rien
                              (réponse identique dans les 2 cas)
  POST /reset-password/  ─► vérifie code + expiration ─► set_password()
                              efface otp_code/otp_expires_at/otp_type
```

---

## 8. Sécurité — règles à respecter en intégrant

1. **Toujours vérifier `otp_expires_at > now()`** avant d'accepter un code —
   ne jamais sauter cette étape même en debug.
2. **Toujours effacer les champs OTP** après usage réussi (`otp_code = None`,
   `otp_expires_at = None`, `otp_type = None`) — empêche la réutilisation du
   même code (single-use).
3. **Ne jamais révéler si un email existe** sur l'endpoint forgot-password —
   garder la réponse générique même si `User.DoesNotExist`.
4. **Vérifier `otp_type`** en plus du code : un code généré pour
   `verify_email` ne doit pas pouvoir servir à un `reset_password` (et
   inversement), même si par hasard les 6 chiffres correspondent.
5. Le `set_password()` de Django gère le hash automatiquement — ne jamais
   stocker/comparer un mot de passe en clair.

---

## 9. Points faibles connus / à améliorer si vous étendez ce système

- Pas de **rate limiting** sur `resend-otp` / `forgot-password` → un
  attaquant peut spammer les emails d'un utilisateur. Ajouter un throttle
  DRF (`AnonRateThrottle` ou custom basé sur l'email) avant mise en prod à
  grande échelle.
- Pas de template HTML pour les emails (texte brut uniquement). Si vous
  voulez un email plus soigné, utiliser `django.template.render_to_string()`
  + `EmailMultiAlternatives` au lieu de `send_mail()`.
- Envoi via `threading.Thread` sans retry : si Brevo répond une erreur,
  l'email est perdu silencieusement (juste un `print` en log). Pour un
  système critique, préférer une tâche Celery avec retry.
- Le champ `account_locked_until` existe sur `User` mais n'est pas exploité
  dans la logique de login actuelle.

---

## 10. Checklist d'intégration pour un nouveau projet

- [ ] Installer `sib-api-v3-sdk` (`pip install sib-api-v3-sdk`)
- [ ] Copier `apps/core/brevo_backend.py` dans le nouveau projet
- [ ] Ajouter dans `settings.py` la logique de bascule `BREVO_API_KEY` →
      `EMAIL_BACKEND` (section 3 ci-dessus)
- [ ] Ajouter `BREVO_API_KEY`, `BREVO_FROM_EMAIL`, `BREVO_FROM_NAME` au `.env`
- [ ] Ajouter les 4 champs OTP au modèle utilisateur/profil
      (`otp_code`, `otp_expires_at`, `otp_type`, `verified_email`) + migration
- [ ] Copier `generate_otp()` / `send_otp_email()`
- [ ] Implémenter les 4 vues : register (avec génération OTP),
      verify-email, forgot-password, reset-password (sur le modèle de
      `apps/core/views.py:82-212`)
- [ ] Tester en local avec une clé Brevo réelle (sinon les emails restent en
      mode console et rien n'est reçu)
