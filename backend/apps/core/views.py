import random
import string
from decimal import Decimal
from datetime import timedelta

from django.core.cache import cache
from django.core.mail import send_mail
from django.db import transaction as db_transaction
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .security_middleware import log_security_event, get_client_ip

from .models import User, UserProfile, Account, Card, Beneficiary, Transaction, TransactionHistory
from .serializers import (
    UserSerializer, UserProfileSerializer, RegisterSerializer,
    LoginSerializer, ChangePasswordSerializer,
    VerifyEmailSerializer, ForgotPasswordSerializer, ResetPasswordSerializer,
    AccountSerializer, CardSerializer, BeneficiarySerializer,
    TransactionSerializer, TransactionHistorySerializer
)


def generate_otp():
    """Génère un code OTP à 6 chiffres."""
    return ''.join(random.choices(string.digits, k=6))


def send_otp_email(email, code, otp_type):
    """Envoie l'OTP par email."""
    if otp_type == 'verify_email':
        subject = 'RSS BANK — Vérification de votre adresse email'
        message = (
            f'Bonjour,\n\n'
            f'Votre code de vérification RSS BANK est :\n\n'
            f'    {code}\n\n'
            f'Ce code expire dans 10 minutes.\n\n'
            f'Si vous n\'avez pas créé de compte, ignorez cet email.\n\n'
            f'— RSS BANK'
        )
    else:
        subject = 'RSS BANK — Réinitialisation de votre mot de passe'
        message = (
            f'Bonjour,\n\n'
            f'Votre code de réinitialisation RSS BANK est :\n\n'
            f'    {code}\n\n'
            f'Ce code expire dans 10 minutes.\n\n'
            f'Si vous n\'avez pas demandé cette réinitialisation, ignorez cet email.\n\n'
            f'— RSS BANK'
        )
    send_mail(subject, message, None, [email], fail_silently=False)


def generate_reference_number():
    """Génère un numéro de référence unique pour une transaction."""
    chars = string.ascii_uppercase + string.digits
    random_part = ''.join(random.choices(chars, k=8))
    return f"TXN{random_part}"


# ─────────────────────────────────────────────
#  USER VIEWS
# ─────────────────────────────────────────────

class RegisterView(viewsets.ViewSet):
    permission_classes = [AllowAny]

    def create(self, request, *args, **kwargs):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()

        # Envoyer OTP de vérification email
        profile, _ = UserProfile.objects.get_or_create(user=user)
        code = generate_otp()
        profile.otp_code = code
        profile.otp_expires_at = timezone.now() + timedelta(minutes=10)
        profile.otp_type = 'verify_email'
        profile.save()
        try:
            send_otp_email(user.email, code, 'verify_email')
        except Exception:
            pass  # Ne pas bloquer l'inscription si l'email échoue

        return Response({
            'message': 'Compte créé. Vérifiez votre email pour le code de confirmation.',
            'email': user.email,
            'status': 'pending_verification'
        }, status=status.HTTP_201_CREATED)


class VerifyEmailView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyEmailSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']
        code = serializer.validated_data['code']

        try:
            user = User.objects.get(email=email)
            profile = user.profile
        except (User.DoesNotExist, UserProfile.DoesNotExist):
            return Response({'detail': 'Utilisateur introuvable.'}, status=status.HTTP_400_BAD_REQUEST)

        if profile.otp_type != 'verify_email':
            return Response({'detail': 'Code invalide.'}, status=status.HTTP_400_BAD_REQUEST)
        if profile.otp_code != code:
            return Response({'detail': 'Code incorrect.'}, status=status.HTTP_400_BAD_REQUEST)
        if profile.otp_expires_at and timezone.now() > profile.otp_expires_at:
            return Response({'detail': 'Code expiré. Demandez un nouveau code.'}, status=status.HTTP_400_BAD_REQUEST)

        profile.verified_email = True
        profile.otp_code = None
        profile.otp_expires_at = None
        profile.otp_type = None
        profile.save()

        return Response({'message': 'Email vérifié avec succès. Vous pouvez vous connecter.'})


class ResendOtpView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        email = request.data.get('email', '')
        otp_type = request.data.get('type', 'verify_email')
        try:
            user = User.objects.get(email=email)
            profile, _ = UserProfile.objects.get_or_create(user=user)
        except User.DoesNotExist:
            return Response({'detail': 'Email introuvable.'}, status=status.HTTP_400_BAD_REQUEST)

        code = generate_otp()
        profile.otp_code = code
        profile.otp_expires_at = timezone.now() + timedelta(minutes=10)
        profile.otp_type = otp_type
        profile.save()
        try:
            send_otp_email(email, code, otp_type)
        except Exception:
            pass
        return Response({'message': 'Nouveau code envoyé.'})


class ForgotPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ForgotPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']

        try:
            user = User.objects.get(email=email)
            profile, _ = UserProfile.objects.get_or_create(user=user)
        except User.DoesNotExist:
            # Réponse générique pour ne pas révéler si l'email existe
            return Response({'message': 'Si cet email existe, un code a été envoyé.'})

        code = generate_otp()
        profile.otp_code = code
        profile.otp_expires_at = timezone.now() + timedelta(minutes=10)
        profile.otp_type = 'reset_password'
        profile.save()
        try:
            send_otp_email(email, code, 'reset_password')
        except Exception:
            pass
        return Response({'message': 'Code de réinitialisation envoyé à votre email.'})


class ResetPasswordView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = ResetPasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data['email']
        code = serializer.validated_data['code']
        new_password = serializer.validated_data['new_password']

        try:
            user = User.objects.get(email=email)
            profile = user.profile
        except (User.DoesNotExist, UserProfile.DoesNotExist):
            return Response({'detail': 'Utilisateur introuvable.'}, status=status.HTTP_400_BAD_REQUEST)

        if profile.otp_type != 'reset_password':
            return Response({'detail': 'Code invalide.'}, status=status.HTTP_400_BAD_REQUEST)
        if profile.otp_code != code:
            return Response({'detail': 'Code incorrect.'}, status=status.HTTP_400_BAD_REQUEST)
        if profile.otp_expires_at and timezone.now() > profile.otp_expires_at:
            return Response({'detail': 'Code expiré. Demandez un nouveau code.'}, status=status.HTTP_400_BAD_REQUEST)

        user.set_password(new_password)
        user.save()
        profile.otp_code = None
        profile.otp_expires_at = None
        profile.otp_type = None
        profile.save()

        return Response({'message': 'Mot de passe réinitialisé avec succès. Connectez-vous.'})


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        ip = get_client_ip(request)
        email = request.data.get('email', '')

        serializer = LoginSerializer(data=request.data)
        if not serializer.is_valid():
            # Compter les tentatives échouées pour cet IP
            cache_key = f'login_fail_{ip}'
            attempts = cache.get(cache_key, 0) + 1
            cache.set(cache_key, attempts, timeout=300)  # fenêtre 5 min

            log_security_event('LOGIN_FAILED', ip, request, {
                'user': email,
                'attempts': attempts,
            })

            # Alerte brute-force si seuil dépassé
            if attempts >= 5:
                log_security_event('BRUTE_FORCE', ip, request, {
                    'user': email,
                    'attempts': attempts,
                })

            raise ValidationError(serializer.errors)

        # Succès — réinitialiser le compteur
        cache.delete(f'login_fail_{ip}')
        log_security_event('LOGIN_SUCCESS', ip, request, {'user': email})

        user = serializer.validated_data['user']
        refresh = RefreshToken.for_user(user)
        return Response({
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'user': UserSerializer(user).data
        }, status=status.HTTP_200_OK)


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'admin':
            return User.objects.all()
        return User.objects.filter(id=self.request.user.id)

    @action(detail=False, methods=['get'])
    def me(self, request):
        return Response(UserSerializer(request.user).data)

    @action(detail=False, methods=['post'])
    def change_password(self, request):
        serializer = ChangePasswordSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response({'error': 'Ancien mot de passe incorrect'}, status=status.HTTP_400_BAD_REQUEST)
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({'message': 'Mot de passe changé avec succès'})

    @action(detail=False, methods=['post'])
    def logout(self, request):
        return Response({'message': 'Déconnecté avec succès'})

    @action(detail=True, methods=['patch'], url_path='update-status')
    def update_status(self, request, pk=None):
        """Admin: change le statut d'un utilisateur (active/suspended/blocked/closed)."""
        if request.user.role != 'admin':
            return Response({'detail': 'Accès refusé.'}, status=status.HTTP_403_FORBIDDEN)
        user = self.get_object()
        new_status = request.data.get('status')
        allowed = ('active', 'suspended', 'blocked', 'closed')
        if new_status not in allowed:
            return Response({'detail': f'Statut invalide. Valeurs: {allowed}'}, status=status.HTTP_400_BAD_REQUEST)
        user.status = new_status
        user.save(update_fields=['status'])
        return Response(UserSerializer(user).data)


class UserProfileViewSet(viewsets.ModelViewSet):
    queryset = UserProfile.objects.all()
    serializer_class = UserProfileSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return UserProfile.objects.filter(user=self.request.user)

    @action(detail=False, methods=['get', 'put'])
    def me(self, request):
        try:
            profile = request.user.profile
        except UserProfile.DoesNotExist:
            profile = UserProfile.objects.create(user=request.user)

        if request.method == 'PUT':
            serializer = self.get_serializer(profile, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return Response(serializer.data)

        return Response(self.get_serializer(profile).data)


# ─────────────────────────────────────────────
#  ACCOUNT VIEWS
# ─────────────────────────────────────────────

class AccountViewSet(viewsets.ModelViewSet):
    queryset = Account.objects.all()
    serializer_class = AccountSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        if self.request.user.role == 'admin':
            return Account.objects.all()
        return Account.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        import uuid as _uuid
        account_number = f"RSS{_uuid.uuid4().hex[:12].upper()}"
        serializer.save(user=self.request.user, account_number=account_number)

    @action(detail=True, methods=['post'])
    def deposit(self, request, pk=None):
        """Créditer un compte (dépôt / rechargement)."""
        account = self.get_object()
        try:
            amount = Decimal(str(request.data.get('amount', 0)))
        except Exception:
            return Response({'error': 'Montant invalide'}, status=status.HTTP_400_BAD_REQUEST)
        if amount <= 0:
            return Response({'error': 'Le montant doit être supérieur à 0'}, status=status.HTTP_400_BAD_REQUEST)
        account.balance += amount
        account.available_balance += amount
        account.save()
        return Response(AccountSerializer(account).data, status=status.HTTP_200_OK)


class CardViewSet(viewsets.ModelViewSet):
    queryset = Card.objects.all()
    serializer_class = CardSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Card.objects.filter(account__user=self.request.user)


class BeneficiaryViewSet(viewsets.ModelViewSet):
    queryset = Beneficiary.objects.all()
    serializer_class = BeneficiarySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Beneficiary.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


# ─────────────────────────────────────────────
#  TRANSACTION VIEWS
# ─────────────────────────────────────────────

class TransactionViewSet(viewsets.ModelViewSet):
    queryset = Transaction.objects.all()
    serializer_class = TransactionSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.role == 'admin':
            return Transaction.objects.all()
        return Transaction.objects.filter(from_account__user=user)

    @db_transaction.atomic
    def perform_create(self, serializer):
        user = self.request.user
        validated_data = serializer.validated_data

        # Récupérer le compte source
        from_account = validated_data.get('from_account')

        # Vérifier que le compte appartient à l'utilisateur connecté
        if from_account.user != user:
            raise PermissionDenied("Ce compte ne vous appartient pas.")

        # Vérifier que le compte est actif
        if from_account.status != 'active':
            raise ValidationError("Le compte source est inactif ou gelé.")

        amount = Decimal(str(validated_data.get('amount', 0)))

        # Vérifier le solde disponible
        if from_account.available_balance < amount:
            raise ValidationError(
                f"Solde insuffisant. Disponible : {from_account.available_balance} {from_account.currency}"
            )

        # Gérer le bénéficiaire par numéro de téléphone (to_phone)
        to_phone = validated_data.pop('to_phone', None)
        beneficiary = None

        if to_phone:
            # Chercher ou créer un bénéficiaire avec ce numéro
            beneficiary, _ = Beneficiary.objects.get_or_create(
                user=user,
                phone_number=to_phone,
                defaults={
                    'beneficiary_name': to_phone,
                    'beneficiary_type': 'external',
                    'bank_name': 'Externe',
                }
            )

        # Générer un numéro de référence unique
        ref_number = generate_reference_number()
        while Transaction.objects.filter(reference_number=ref_number).exists():
            ref_number = generate_reference_number()

        # Calculer les frais et le montant total (0% pour l'instant)
        transaction_fee = Decimal('0.00')
        total_amount = amount + transaction_fee

        # Déduire le montant du compte source
        from_account.balance -= total_amount
        from_account.available_balance -= total_amount
        from_account.save()

        # Enregistrer la transaction
        serializer.save(
            reference_number=ref_number,
            transaction_fee=transaction_fee,
            total_amount=total_amount,
            to_beneficiary=beneficiary,
            status='completed',
            ip_address=self.request.META.get('REMOTE_ADDR'),
        )

    @action(detail=False, methods=['get'])
    def received(self, request):
        """Transactions reçues"""
        qs = Transaction.objects.filter(to_account__user=request.user)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)


class TransactionHistoryViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = TransactionHistory.objects.all()
    serializer_class = TransactionHistorySerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return TransactionHistory.objects.filter(
            transaction__from_account__user=self.request.user
        )
