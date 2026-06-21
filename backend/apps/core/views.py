import random
import secrets
import string
import uuid
from decimal import Decimal
from datetime import timedelta

from django.core.cache import cache
from django.core.mail import send_mail
from django.db import transaction as db_transaction
import threading
from django.utils import timezone
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework.response import Response
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework_simplejwt.tokens import RefreshToken
import requests as http_requests
from django.conf import settings
from django.shortcuts import redirect

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
        threading.Thread(target=send_otp_email, args=(user.email, code, 'verify_email',), daemon=True).start()

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
        threading.Thread(target=send_otp_email, args=(email, code, otp_type,), daemon=True).start()
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
        threading.Thread(target=send_otp_email, args=(email, code, 'reset_password',), daemon=True).start()
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


class FaceLoginEnrollView(APIView):
    """
    POST /api/auth/face-login/enroll/
    multipart/form-data : { file: <photo_reference.jpg> }

    Auth requise. Appelé une fois (bouton "Connecter mon visage" du
    profil), juste après un KYC validé. Stocke la photo de référence
    côté backend — aucun appel au service tiers ici, c'est seulement
    un enrôlement local utilisé plus tard par FaceLoginView.
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        user = request.user
        ip = get_client_ip(request)

        if user.kyc_status != 'approved':
            raise ValidationError({'detail': 'KYC non validé : impossible d\'activer la connexion par visage.'})

        reference_photo = request.FILES.get('file')
        if not reference_photo:
            raise ValidationError({'detail': 'file est requis.'})

        user.face_reference_photo = reference_photo
        user.save(update_fields=['face_reference_photo'])

        log_security_event('FACE_ENROLL_SUCCESS', ip, request, {'user': user.email})
        return Response({'detail': 'Visage enregistré'}, status=status.HTTP_200_OK)


class FaceLoginView(APIView):
    """
    POST /api/auth/face-login/
    multipart/form-data : { national_id: <NNI>, file: <selfie.jpg> }

    Récupère la photo de référence enrôlée via FaceLoginEnrollView et la
    compare, côté serveur, à la nouvelle selfie via le service tiers
    (NovaGard) /kyc/verify, puis émet des tokens JWT si le visage matche.
    """
    permission_classes = [AllowAny]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        ip = get_client_ip(request)
        national_id = (request.data.get('national_id') or '').strip()
        selfie = request.FILES.get('file')

        if not national_id or not selfie:
            raise ValidationError({'detail': 'national_id et file sont requis.'})

        # Anti brute-force par IP
        cache_key = f'face_login_fail_{ip}'
        attempts = cache.get(cache_key, 0)
        if attempts >= 5:
            log_security_event('BRUTE_FORCE', ip, request, {
                'national_id': national_id,
                'attempts': attempts,
                'context': 'face_login',
            })
            raise ValidationError({'detail': 'Trop de tentatives, réessayez plus tard.'})

        try:
            user = User.objects.get(national_id=national_id)
        except User.DoesNotExist:
            attempts += 1
            cache.set(cache_key, attempts, timeout=300)
            log_security_event('FACE_LOGIN_FAILED', ip, request, {
                'national_id': national_id,
                'reason': 'unknown_national_id',
            })
            raise ValidationError({'detail': 'Connexion par visage impossible.'})

        if user.kyc_status != 'approved' or user.status in ('suspended', 'blocked', 'closed'):
            log_security_event('FACE_LOGIN_FAILED', ip, request, {
                'user': user.email,
                'reason': 'kyc_or_status',
            })
            raise ValidationError({'detail': 'Connexion par visage non disponible pour ce compte.'})

        if not user.face_reference_photo:
            log_security_event('FACE_LOGIN_FAILED', ip, request, {
                'user': user.email,
                'reason': 'no_reference_photo',
            })
            raise ValidationError({'detail': 'Aucune photo de référence enregistrée. Activez d\'abord la connexion par visage depuis le profil.'})

        # Vérification biométrique côté serveur (clé API jamais exposée au client)
        try:
            with user.face_reference_photo.open('rb') as reference_file:
                face_response = http_requests.post(
                    f'{settings.FACE_API_BASE_URL}/kyc/verify',
                    headers={'Secure-Nova-Key': settings.FACE_API_KEY},
                    files={
                        'image1': ('reference.jpg', reference_file.read(), 'image/jpeg'),
                        'image2': (selfie.name, selfie.read(), selfie.content_type),
                    },
                    timeout=30,
                )
        except http_requests.RequestException:
            log_security_event('FACE_LOGIN_FAILED', ip, request, {
                'user': user.email,
                'reason': 'face_api_unreachable',
            })
            raise ValidationError({'detail': 'Service de reconnaissance faciale indisponible.'})

        if face_response.status_code != 200:
            attempts += 1
            cache.set(cache_key, attempts, timeout=300)
            log_security_event('FACE_LOGIN_FAILED', ip, request, {
                'user': user.email,
                'reason': 'face_api_error',
                'status_code': face_response.status_code,
            })
            return Response({'detail': 'Échec de la vérification faciale.'}, status=status.HTTP_400_BAD_REQUEST)

        face_data = face_response.json() if face_response.content else {}
        decision = str(face_data.get('decision', '')).lower()
        matched = decision == 'allow'

        if not matched:
            attempts += 1
            cache.set(cache_key, attempts, timeout=300)
            log_security_event('FACE_LOGIN_FAILED', ip, request, {
                'user': user.email,
                'reason': 'no_match',
                'decision': face_data.get('decision'),
            })
            return Response({'detail': 'Visage non reconnu.'}, status=status.HTTP_401_UNAUTHORIZED)

        # Succès
        cache.delete(cache_key)
        log_security_event('FACE_LOGIN_SUCCESS', ip, request, {'user': user.email})

        refresh = RefreshToken.for_user(user)
        return Response({
            'refresh': str(refresh),
            'access': str(refresh.access_token),
            'user': UserSerializer(user).data,
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

    @action(detail=False, methods=['post'], url_path='complete-kyc', permission_classes=[IsAuthenticated])
    def complete_kyc(self, request):
        """
        POST /api/users/complete-kyc/
        Appelé par Flutter après vérification OCR + Face réussie.
        """
        user = request.user

        if user.kyc_status == 'approved':
            return Response(
                {'detail': 'KYC déjà validé', 'kyc_status': 'approved'},
                status=status.HTTP_200_OK,
            )

        face_confidence = request.data.get('face_match_confidence', 0)
        try:
            face_confidence = float(face_confidence)
        except (TypeError, ValueError):
            face_confidence = 0.0

        SEUIL_REJET = 0.3
        if 0 < face_confidence < SEUIL_REJET:
            user.kyc_status = 'rejected'
            user.save(update_fields=['kyc_status'])
            return Response(
                {
                    'detail': 'Vérification faciale insuffisante',
                    'kyc_status': 'rejected',
                    'confidence': face_confidence,
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        national_id = request.data.get('national_id', '').strip()
        extracted_first = request.data.get('extracted_first_name', '').strip()
        extracted_last = request.data.get('extracted_last_name', '').strip()

        if national_id and not user.national_id:
            user.national_id = national_id
        if extracted_first and not user.first_name:
            user.first_name = extracted_first
        if extracted_last and not user.last_name:
            user.last_name = extracted_last

        user.kyc_status = 'approved'
        user.kyc_submitted_at = timezone.now()
        user.save()

        return Response(
            {
                'detail': 'KYC validé avec succès',
                'kyc_status': 'approved',
                'user': UserSerializer(user).data,
            },
            status=status.HTTP_200_OK,
        )

    @action(detail=False, methods=['get'], url_path='kyc-status', permission_classes=[IsAuthenticated])
    def kyc_status_view(self, request):
        """
        GET /api/users/kyc-status/
        Retourne le statut KYC de l'utilisateur courant.
        """
        user = request.user
        return Response({
            'kyc_status': user.kyc_status,
            'national_id_set': bool(user.national_id),
            'requires_kyc': user.kyc_status != 'approved',
        })






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

SSO_STATE_CACHE_PREFIX = "sso_state_"
SSO_STATE_TTL = 300  # 5 minutes
SSO_FAIL_WINDOW = 300  # 5 minutes
SSO_FAIL_THRESHOLD = 10


def _sso_rate_limited(ip):
    """Retourne True si l'IP a dépassé le seuil de tentatives SSO échouées."""
    return cache.get(f"sso_fail_{ip}", 0) >= SSO_FAIL_THRESHOLD


def _register_sso_failure(ip, request, reason, extra=None):
    cache_key = f"sso_fail_{ip}"
    attempts = cache.get(cache_key, 0) + 1
    cache.set(cache_key, attempts, timeout=SSO_FAIL_WINDOW)

    payload = {"reason": reason, "attempts": attempts}
    if extra:
        payload.update(extra)
    log_security_event("SSO_LOGIN_FAILED", ip, request, payload)

    if attempts >= SSO_FAIL_THRESHOLD:
        log_security_event("SSO_BRUTE_FORCE", ip, request, payload)


def _provision_sso_user(userinfo, ip, request):
    """
    Crée ou récupère l'utilisateur RSS Bank correspondant au profil SSO.
    Retourne (user, error_response) — error_response est None en cas de succès.
    """
    email = userinfo.get("email")
    if not email:
        _register_sso_failure(ip, request, "missing_email")
        return None, Response({"error": "Profil SSO invalide"}, status=status.HTTP_400_BAD_REQUEST)

    # Si le provider expose la claim OIDC standard email_verified, on l'exige.
    if userinfo.get("email_verified") is False:
        _register_sso_failure(ip, request, "email_not_verified", {"email": email})
        return None, Response({"error": "Email SSO non vérifié"}, status=status.HTTP_403_FORBIDDEN)

    existing = User.objects.filter(email=email).first()
    if existing is not None:
        # Empêche un compte SSO de prendre le contrôle d'un compte local
        # protégé par mot de passe (anti account-takeover).
        if existing.has_usable_password():
            _register_sso_failure(ip, request, "account_conflict", {"email": email})
            return None, Response(
                {"error": "Un compte existe déjà avec cet email. Connectez-vous avec votre mot de passe."},
                status=status.HTTP_409_CONFLICT,
            )
        if existing.status != "active" or not existing.is_active:
            _register_sso_failure(ip, request, "account_inactive", {"email": email})
            return None, Response({"error": "Compte désactivé"}, status=status.HTTP_403_FORBIDDEN)
        return existing, None

    unique_username = email[:140] + "_" + uuid.uuid4().hex[:8]
    user = User.objects.create(
        email=email,
        username=unique_username,
        first_name=userinfo.get("given_name", "")[:150],
        last_name=userinfo.get("family_name", "")[:150],
        is_active=True,
    )
    user.set_unusable_password()
    user.save()
    return user, None


class SSOStartView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        ip = get_client_ip(request)
        if _sso_rate_limited(ip):
            return Response({"error": "Trop de tentatives, réessayez plus tard"}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        # Protection CSRF du flow OAuth (paramètre state à usage unique)
        state = secrets.token_urlsafe(32)
        cache.set(f"{SSO_STATE_CACHE_PREFIX}{state}", True, timeout=SSO_STATE_TTL)

        auth_url = (
            f"{settings.SSO_AUTHORIZE_URL}"
            f"?client_id={settings.SSO_CLIENT_ID}"
            f"&response_type=code"
            f"&redirect_uri={settings.SSO_REDIRECT_URI}"
            f"&scope=openid profile email"
            f"&state={state}"
        )
        return redirect(auth_url)


class SSOCallbackView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        ip = get_client_ip(request)
        if _sso_rate_limited(ip):
            return Response({"error": "Trop de tentatives, réessayez plus tard"}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        code = request.GET.get("code")
        state = request.GET.get("state")

        if not code:
            _register_sso_failure(ip, request, "missing_code")
            return Response({"error": "Code OAuth manquant"}, status=status.HTTP_400_BAD_REQUEST)

        # Vérifie et consomme le state (protection CSRF, usage unique)
        state_key = f"{SSO_STATE_CACHE_PREFIX}{state}" if state else None
        if not state or not cache.get(state_key):
            _register_sso_failure(ip, request, "invalid_state")
            return Response({"error": "Requête SSO invalide ou expirée"}, status=status.HTTP_400_BAD_REQUEST)
        cache.delete(state_key)

        try:
            # 1. Échanger le code contre un token
            token_resp = http_requests.post(
                settings.SSO_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "client_id": settings.SSO_CLIENT_ID,
                    "client_secret": settings.SSO_CLIENT_SECRET,
                    "redirect_uri": settings.SSO_REDIRECT_URI,
                },
                timeout=10,
            )

            if token_resp.status_code != 200:
                _register_sso_failure(ip, request, "token_exchange_failed")
                return Response({"error": "Impossible de récupérer le token SSO"}, status=status.HTTP_400_BAD_REQUEST)

            access_token = token_resp.json().get("access_token")

            # 2. Récupérer les infos utilisateur
            userinfo_resp = http_requests.get(
                settings.SSO_USERINFO_URL,
                headers={"Authorization": f"Bearer {access_token}"},
                timeout=10,
            )

            if userinfo_resp.status_code != 200:
                _register_sso_failure(ip, request, "userinfo_failed")
                return Response({"error": "Impossible de récupérer le profil SSO"}, status=status.HTTP_400_BAD_REQUEST)

            userinfo = userinfo_resp.json()

            # 3. Créer ou récupérer l'utilisateur RSS Bank
            user, error_response = _provision_sso_user(userinfo, ip, request)
            if error_response:
                return error_response

            # 4. Générer JWT RSS Bank
            cache.delete(f"sso_fail_{ip}")
            log_security_event("SSO_LOGIN_SUCCESS", ip, request, {"user": user.email})
            refresh = RefreshToken.for_user(user)
            return Response({
                "message": "Connexion SSO réussie",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            })

        except http_requests.RequestException:
            _register_sso_failure(ip, request, "sso_provider_unreachable")
            return Response({"error": "Service SSO indisponible"}, status=status.HTTP_502_BAD_GATEWAY)
        except Exception:
            log_security_event("SSO_LOGIN_ERROR", ip, request, {})
            return Response({"error": "Erreur lors de la connexion SSO"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class SSOLoginView(APIView):
    """
    Échange un access_token SSO (obtenu côté mobile via PKCE) contre un JWT RSS Bank.
    """
    permission_classes = [AllowAny]

    def post(self, request):
        ip = get_client_ip(request)
        if _sso_rate_limited(ip):
            return Response({"error": "Trop de tentatives, réessayez plus tard"}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        sso_access_token = request.data.get("sso_access_token")
        if not sso_access_token or not isinstance(sso_access_token, str):
            _register_sso_failure(ip, request, "missing_token")
            return Response({"error": "sso_access_token manquant"}, status=status.HTTP_400_BAD_REQUEST)

        try:
            userinfo_resp = http_requests.get(
                settings.SSO_USERINFO_URL,
                headers={"Authorization": f"Bearer {sso_access_token}"},
                timeout=10,
            )

            if userinfo_resp.status_code != 200:
                _register_sso_failure(ip, request, "invalid_token")
                return Response({"error": "Token SSO invalide ou expiré"}, status=status.HTTP_401_UNAUTHORIZED)

            userinfo = userinfo_resp.json()

            user, error_response = _provision_sso_user(userinfo, ip, request)
            if error_response:
                return error_response

            cache.delete(f"sso_fail_{ip}")
            log_security_event("SSO_LOGIN_SUCCESS", ip, request, {"user": user.email})
            refresh = RefreshToken.for_user(user)
            return Response({
                "message": "Connexion SSO réussie",
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": UserSerializer(user).data,
            })

        except http_requests.RequestException:
            _register_sso_failure(ip, request, "sso_provider_unreachable")
            return Response({"error": "Service SSO indisponible"}, status=status.HTTP_502_BAD_GATEWAY)
        except Exception:
            log_security_event("SSO_LOGIN_ERROR", ip, request, {})
            return Response({"error": "Erreur lors de la connexion SSO"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)