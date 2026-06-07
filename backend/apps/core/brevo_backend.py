"""
Backend email Django qui utilise l'API HTTPS Brevo (ex-Sendinblue).
Contourne le blocage port 587 de DigitalOcean via HTTPS port 443.
"""
import os
from django.core.mail.backends.base import BaseEmailBackend


class BrevoAPIBackend(BaseEmailBackend):
    """Envoie les emails via l'API Brevo v3 (HTTPS)."""

    def __init__(self, fail_silently=False, **kwargs):
        super().__init__(fail_silently=fail_silently)
        self.api_key = os.getenv('BREVO_API_KEY', '')
        self.from_email = os.getenv('BREVO_FROM_EMAIL', 'rssbank700@gmail.com')
        self.from_name = os.getenv('BREVO_FROM_NAME', 'RSS Bank')

        try:
            import sib_api_v3_sdk
            from sib_api_v3_sdk.rest import ApiException
            self._sdk = sib_api_v3_sdk
            self._ApiException = ApiException

            configuration = sib_api_v3_sdk.Configuration()
            configuration.api_key['api-key'] = self.api_key
            self.client = sib_api_v3_sdk.TransactionalEmailsApi(
                sib_api_v3_sdk.ApiClient(configuration)
            )
            if self.api_key:
                print(f"[brevo] Backend actif, from={self.from_email}")
            else:
                print("[brevo] ⚠ API key vide")
                self.client = None
        except ImportError:
            print("[brevo] ❌ sib-api-v3-sdk non installé")
            self.client = None

    def send_messages(self, email_messages):
        if not self.client:
            return 0

        sent = 0
        for msg in email_messages:
            try:
                send_smtp_email = self._sdk.SendSmtpEmail(
                    sender={'name': self.from_name, 'email': self.from_email},
                    to=[{'email': to} for to in msg.to],
                    subject=msg.subject,
                    text_content=str(msg.body),
                )
                response = self.client.send_transac_email(send_smtp_email)
                sent += 1
                print(f"[brevo] ✅ Sent to {msg.to}, id={response.message_id}")
            except self._ApiException as e:
                print(f"[brevo] ❌ API error: {e}")
                if not self.fail_silently:
                    raise
            except Exception as e:
                print(f"[brevo] ❌ {type(e).__name__}: {e}")
                if not self.fail_silently:
                    raise
        return sent
