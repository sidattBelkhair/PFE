from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    RegisterView, LoginView, FaceLoginView, FaceLoginEnrollView,
    VerifyEmailView, ResendOtpView, ForgotPasswordView, ResetPasswordView,
    UserViewSet, UserProfileViewSet,
    AccountViewSet, CardViewSet, BeneficiaryViewSet,
    TransactionViewSet, TransactionHistoryViewSet,
    SSOLoginView,
    SSOStartView,
    SSOCallbackView,
    SSOExchangeView,
    TrackPayResolveView,
    TrackPayInitiateView,
)

router = DefaultRouter()

# Users
router.register('users', UserViewSet, basename='user')
router.register('users/profile', UserProfileViewSet, basename='profile')

# Accounts
router.register('accounts', AccountViewSet, basename='account')
router.register('cards', CardViewSet, basename='card')
router.register('beneficiaries', BeneficiaryViewSet, basename='beneficiary')

# Transactions
router.register('transactions', TransactionViewSet, basename='transaction')
router.register('transactions/history', TransactionHistoryViewSet, basename='transaction-history')

urlpatterns = [
    path('auth/register/', RegisterView.as_view({'post': 'create'})),
    path('auth/login/', LoginView.as_view()),
    path('auth/face-login/', FaceLoginView.as_view()),
    path('auth/face-login/enroll/', FaceLoginEnrollView.as_view()),
    path('auth/token/refresh/', TokenRefreshView.as_view()),
    path('auth/verify-email/', VerifyEmailView.as_view()),
    path('auth/resend-otp/', ResendOtpView.as_view()),
    path('auth/forgot-password/', ForgotPasswordView.as_view()),
    path('auth/reset-password/', ResetPasswordView.as_view()),
    path('auth/sso/start/', SSOStartView.as_view()),
    path('auth/sso/callback/', SSOCallbackView.as_view()),
    path('auth/sso-login/', SSOLoginView.as_view(), name='sso-login'),
    path('auth/sso/exchange/', SSOExchangeView.as_view()),
    path('payments/trackpay/resolve/', TrackPayResolveView.as_view()),
    path('payments/trackpay/initiate/', TrackPayInitiateView.as_view()),
    path('', include(router.urls)),
   
]
