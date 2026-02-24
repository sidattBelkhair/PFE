from rest_framework import serializers
from django.contrib.auth import authenticate
from .models import User, UserProfile, Account, Card, Beneficiary, Transaction, TransactionHistory


# ─────────────────────────────────────────────
#  USER SERIALIZERS
# ─────────────────────────────────────────────

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'phone_number', 'national_id', 'role', 'status',
            'profile_photo', 'address', 'city', 'country', 'date_of_birth',
            'kyc_status', 'two_factor_enabled', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'role', 'status']


class UserProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = UserProfile
        fields = [
            'user', 'bio', 'verified_email', 'verified_phone', 'verified_identity',
            'notification_email', 'notification_sms', 'notification_push'
        ]


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['email', 'phone_number', 'password', 'password_confirm', 'first_name', 'last_name']

    def validate(self, attrs):
        if attrs['password'] != attrs.pop('password_confirm'):
            raise serializers.ValidationError("Les mots de passe ne correspondent pas")
        return attrs

    def create(self, validated_data):
        user = User.objects.create_user(
            email=validated_data['email'],
            phone_number=validated_data.get('phone_number'),
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', ''),
            username=validated_data['email']
        )
        UserProfile.objects.get_or_create(user=user)
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()

    def validate(self, attrs):
        try:
            user = User.objects.get(email=attrs['email'])
            if not user.check_password(attrs['password']):
                raise serializers.ValidationError("Identifiants invalides")
            if user.status in ('suspended', 'blocked', 'closed'):
                raise serializers.ValidationError("Ce compte est désactivé. Contactez le support.")
        except User.DoesNotExist:
            raise serializers.ValidationError("Identifiants invalides")
        attrs['user'] = user
        return attrs


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField()
    new_password = serializers.CharField(min_length=8)
    new_password_confirm = serializers.CharField(min_length=8)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['new_password_confirm']:
            raise serializers.ValidationError("Les mots de passe ne correspondent pas")
        return attrs


# ─────────────────────────────────────────────
#  ACCOUNT SERIALIZERS
# ─────────────────────────────────────────────

class AccountSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = Account
        fields = [
            'id', 'user', 'account_number', 'account_name', 'account_type',
            'currency', 'balance', 'available_balance', 'status', 'is_default',
            'daily_withdrawal_limit', 'daily_transfer_limit', 'created_at'
        ]
        read_only_fields = ['id', 'user', 'account_number', 'balance', 'available_balance', 'created_at']


class CardSerializer(serializers.ModelSerializer):
    account = AccountSerializer(read_only=True)

    class Meta:
        model = Card
        fields = [
            'id', 'account', 'last_four_digits', 'card_type', 'card_brand',
            'cardholder_name', 'expiry_month', 'expiry_year', 'status',
            'is_contactless_enabled', 'is_online_enabled', 'created_at'
        ]
        read_only_fields = ['id', 'created_at']


class BeneficiarySerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = Beneficiary
        fields = [
            'id', 'user', 'beneficiary_name', 'beneficiary_type',
            'account_number', 'bank_name', 'phone_number',
            'is_verified', 'created_at'
        ]
        read_only_fields = ['id', 'created_at', 'user']


# ─────────────────────────────────────────────
#  TRANSACTION SERIALIZERS
# ─────────────────────────────────────────────

class TransactionSerializer(serializers.ModelSerializer):
    from_account_name = serializers.CharField(source='from_account.account_name', read_only=True)
    to_account_name = serializers.CharField(source='to_account.account_name', read_only=True, allow_null=True)
    to_beneficiary_name = serializers.CharField(source='to_beneficiary.beneficiary_name', read_only=True, allow_null=True)

    # Champ write-only pour virement par numéro de téléphone
    to_phone = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Transaction
        fields = [
            'id', 'from_account', 'from_account_name', 'to_account', 'to_account_name',
            'to_beneficiary', 'to_beneficiary_name', 'to_phone',
            'transaction_type', 'amount', 'currency', 'description',
            'reference_number', 'transaction_fee', 'total_amount',
            'status', 'is_flagged', 'created_at'
        ]
        read_only_fields = [
            'id', 'reference_number', 'transaction_fee', 'total_amount', 'created_at',
            'to_beneficiary',
        ]


class TransactionHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = TransactionHistory
        fields = ['id', 'status_before', 'status_after', 'changed_by', 'changed_at', 'reason']
        read_only_fields = ['id', 'changed_at']
