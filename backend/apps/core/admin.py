
# Register your models here.
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User, UserProfile, Account, Card, Beneficiary, Transaction, TransactionHistory


# ─────────────────────────────────────────────
#  USER ADMIN
# ─────────────────────────────────────────────

@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['email', 'first_name', 'last_name', 'role', 'status', 'kyc_status', 'created_at']
    list_filter = ['role', 'status', 'kyc_status', 'two_factor_enabled']
    search_fields = ['email', 'first_name', 'last_name', 'phone_number', 'national_id']
    ordering = ['-created_at']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Informations personnelles', {
            'fields': ('phone_number', 'national_id', 'date_of_birth', 'address', 'city', 'country', 'profile_photo')
        }),
        ('Rôle & Statut', {
            'fields': ('role', 'status', 'kyc_status', 'kyc_submitted_at')
        }),
        ('Sécurité', {
            'fields': ('two_factor_enabled', 'last_login_ip', 'login_attempts', 'account_locked_until')
        }),
    )


@admin.register(UserProfile)
class UserProfileAdmin(admin.ModelAdmin):
    list_display = ['user', 'verified_email', 'verified_phone', 'verified_identity']
    search_fields = ['user__email', 'user__first_name']


# ─────────────────────────────────────────────
#  ACCOUNT ADMIN
# ─────────────────────────────────────────────

@admin.register(Account)
class AccountAdmin(admin.ModelAdmin):
    list_display = ['account_name', 'account_number', 'user', 'account_type', 'currency', 'balance', 'status']
    list_filter = ['account_type', 'currency', 'status']
    search_fields = ['account_name', 'account_number', 'user__email']
    ordering = ['-created_at']


@admin.register(Card)
class CardAdmin(admin.ModelAdmin):
    list_display = ['cardholder_name', 'last_four_digits', 'card_brand', 'card_type', 'status']
    list_filter = ['card_type', 'card_brand', 'status']
    search_fields = ['cardholder_name', 'last_four_digits']


@admin.register(Beneficiary)
class BeneficiaryAdmin(admin.ModelAdmin):
    list_display = ['beneficiary_name', 'user', 'beneficiary_type', 'account_number', 'is_verified']
    list_filter = ['beneficiary_type', 'is_verified']
    search_fields = ['beneficiary_name', 'account_number', 'user__email']


# ─────────────────────────────────────────────
#  TRANSACTION ADMIN
# ─────────────────────────────────────────────

@admin.register(Transaction)
class TransactionAdmin(admin.ModelAdmin):
    list_display = ['reference_number', 'transaction_type', 'amount', 'currency', 'status', 'is_flagged', 'created_at']
    list_filter = ['transaction_type', 'status', 'currency', 'is_flagged']
    search_fields = ['reference_number', 'from_account__account_number']
    ordering = ['-created_at']


@admin.register(TransactionHistory)
class TransactionHistoryAdmin(admin.ModelAdmin):
    list_display = ['transaction', 'status_before', 'status_after', 'changed_by', 'changed_at']
    list_filter = ['status_after']
    ordering = ['-changed_at']