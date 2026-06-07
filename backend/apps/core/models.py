
# Create your models here.
from django.db import models
from django.contrib.auth.models import AbstractUser, Group, Permission
from django.utils.translation import gettext_lazy as _
import uuid


# ─────────────────────────────────────────────
#  USER
# ─────────────────────────────────────────────

class User(AbstractUser):
    USER_ROLES = [
        ('client', 'Client'),
        ('admin', 'Administrateur'),
        ('agent', 'Agent'),
    ]
    USER_STATUS = [
        ('active', 'Actif'),
        ('suspended', 'Suspendu'),
        ('closed', 'Fermé'),
        ('blocked', 'Bloqué'),
    ]

    groups = models.ManyToManyField(
        Group, related_name='custom_user_groups', blank=True,
        help_text='Les groupes auxquels cet utilisateur appartient.'
    )
    user_permissions = models.ManyToManyField(
        Permission, related_name='custom_user_permissions', blank=True,
        help_text='Les permissions spécifiques de cet utilisateur.'
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    phone_number = models.CharField(max_length=20, null=True, blank=True)
    national_id = models.CharField(max_length=50, unique=True, null=True, blank=True)
    role = models.CharField(max_length=20, choices=USER_ROLES, default='client')
    status = models.CharField(max_length=20, choices=USER_STATUS, default='active')
    profile_photo = models.ImageField(upload_to='profiles/', null=True, blank=True)
    address = models.TextField(null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    country = models.CharField(max_length=100, null=True, blank=True)
    date_of_birth = models.DateField(null=True, blank=True)

    kyc_status = models.CharField(
        max_length=20,
        choices=[('pending', 'En attente'), ('approved', 'Approuvé'), ('rejected', 'Rejeté')],
        default='pending'
    )
    kyc_submitted_at = models.DateTimeField(null=True, blank=True)

    two_factor_enabled = models.BooleanField(default=False)
    last_login_ip = models.GenericIPAddressField(null=True, blank=True)
    login_attempts = models.IntegerField(default=0)
    account_locked_until = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'users'
        verbose_name = _('Utilisateur')
        verbose_name_plural = _('Utilisateurs')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"


class UserProfile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    bio = models.TextField(null=True, blank=True)
    verified_email = models.BooleanField(default=False)
    verified_phone = models.BooleanField(default=False)
    verified_identity = models.BooleanField(default=False)
    notification_email = models.BooleanField(default=True)
    notification_sms = models.BooleanField(default=False)
    notification_push = models.BooleanField(default=True)
    # OTP pour vérification email et réinitialisation mot de passe
    otp_code = models.CharField(max_length=6, null=True, blank=True)
    otp_expires_at = models.DateTimeField(null=True, blank=True)
    otp_type = models.CharField(max_length=20, null=True, blank=True)  # 'verify_email' | 'reset_password'
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profil de {self.user.get_full_name()}"


# ─────────────────────────────────────────────
#  ACCOUNTS
# ─────────────────────────────────────────────

class Account(models.Model):
    ACCOUNT_TYPES = [
        ('checking', 'Courant'),
        ('savings', 'Épargne'),
    ]
    ACCOUNT_STATUS = [
        ('active', 'Actif'),
        ('frozen', 'Gelé'),
        ('closed', 'Fermé'),
    ]
    CURRENCIES = [
        ('MRU', 'Ouguiya Mauritanien'),
        ('DZD', 'Dinar Algérien'),
        ('USD', 'Dollar US'),
        ('EUR', 'Euro'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='accounts')
    account_number = models.CharField(max_length=34, unique=True)
    account_name = models.CharField(max_length=100)
    account_type = models.CharField(max_length=20, choices=ACCOUNT_TYPES)
    currency = models.CharField(max_length=3, choices=CURRENCIES, default='MRU')
    balance = models.DecimalField(max_digits=15, decimal_places=2, default=0.00)
    available_balance = models.DecimalField(max_digits=15, decimal_places=2, default=0.00)
    status = models.CharField(max_length=20, choices=ACCOUNT_STATUS, default='active')
    is_default = models.BooleanField(default=False)
    daily_withdrawal_limit = models.DecimalField(max_digits=15, decimal_places=2, default=5000.00)
    daily_transfer_limit = models.DecimalField(max_digits=15, decimal_places=2, default=10000.00)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_activity = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'accounts'
        unique_together = ['user', 'account_number']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.account_name} - {self.account_number}"

    def get_balance(self):
        return f"{self.balance} {self.currency}"


class Card(models.Model):
    CARD_TYPES = [
        ('debit', 'Débit'),
        ('credit', 'Crédit'),
        ('virtual', 'Virtuelle'),
    ]
    CARD_BRANDS = [
        ('VISA', 'Visa'),
        ('MASTERCARD', 'MasterCard'),
        ('AMEX', 'American Express'),
    ]
    CARD_STATUS = [
        ('active', 'Actif'),
        ('suspended', 'Suspendu'),
        ('expired', 'Expiré'),
        ('blocked', 'Bloqué'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    account = models.ForeignKey(Account, on_delete=models.CASCADE, related_name='cards')
    card_number_hash = models.CharField(max_length=255, unique=True)
    last_four_digits = models.CharField(max_length=4)
    card_type = models.CharField(max_length=20, choices=CARD_TYPES)
    card_brand = models.CharField(max_length=20, choices=CARD_BRANDS)
    cardholder_name = models.CharField(max_length=100)
    expiry_month = models.IntegerField()
    expiry_year = models.IntegerField()
    cvv_hash = models.CharField(max_length=255, null=True, blank=True)
    daily_spending_limit = models.DecimalField(max_digits=15, decimal_places=2, default=1000.00)
    monthly_spending_limit = models.DecimalField(max_digits=15, decimal_places=2, default=10000.00)
    status = models.CharField(max_length=20, choices=CARD_STATUS, default='active')
    is_contactless_enabled = models.BooleanField(default=True)
    is_online_enabled = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    issued_date = models.DateField(null=True, blank=True)
    activation_date = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = 'cards'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.cardholder_name} - ****{self.last_four_digits}"


class Beneficiary(models.Model):
    BENEFICIARY_TYPES = [
        ('internal', 'Interne'),
        ('external', 'Externe'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='beneficiaries')
    beneficiary_name = models.CharField(max_length=100)
    beneficiary_type = models.CharField(max_length=20, choices=BENEFICIARY_TYPES)
    account_number = models.CharField(max_length=34, blank=True, default='')
    bank_name = models.CharField(max_length=100, null=True, blank=True)
    phone_number = models.CharField(max_length=20, null=True, blank=True)
    is_verified = models.BooleanField(default=False)
    verification_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'beneficiaries'

    def __str__(self):
        return f"{self.beneficiary_name} - {self.account_number}"


# ─────────────────────────────────────────────
#  TRANSACTIONS
# ─────────────────────────────────────────────

class Transaction(models.Model):
    TRANSACTION_TYPES = [
        ('transfer', 'Virement'),
        ('payment', 'Paiement'),
        ('withdrawal', 'Retrait'),
        ('deposit', 'Dépôt'),
        ('salary', 'Salaire'),
    ]
    TRANSACTION_STATUS = [
        ('pending', 'En attente'),
        ('processing', 'En cours'),
        ('completed', 'Complété'),
        ('failed', 'Échoué'),
        ('reversed', 'Annulé'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    from_account = models.ForeignKey(Account, on_delete=models.PROTECT, related_name='sent_transactions')
    to_account = models.ForeignKey(Account, on_delete=models.PROTECT, related_name='received_transactions', null=True, blank=True)
    to_beneficiary = models.ForeignKey(Beneficiary, on_delete=models.SET_NULL, null=True, blank=True)
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    amount = models.DecimalField(max_digits=15, decimal_places=2)
    currency = models.CharField(max_length=3, default='MRU')
    description = models.TextField(null=True, blank=True)
    reference_number = models.CharField(max_length=50, unique=True)
    transaction_fee = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    total_amount = models.DecimalField(max_digits=15, decimal_places=2)
    status = models.CharField(max_length=20, choices=TRANSACTION_STATUS, default='pending')
    is_flagged = models.BooleanField(default=False)
    fraud_score = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)

    class Meta:
        db_table = 'transactions'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.transaction_type} - {self.amount} {self.currency}"


class TransactionHistory(models.Model):
    transaction = models.ForeignKey(Transaction, on_delete=models.CASCADE, related_name='history')
    status_before = models.CharField(max_length=20)
    status_after = models.CharField(max_length=20)
    changed_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    changed_at = models.DateTimeField(auto_now_add=True)
    reason = models.TextField(null=True, blank=True)

    class Meta:
        db_table = 'transaction_history'
        ordering = ['-changed_at']