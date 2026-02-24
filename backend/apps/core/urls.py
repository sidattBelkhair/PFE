from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from .views import (
    RegisterView, LoginView,
    UserViewSet, UserProfileViewSet,
    AccountViewSet, CardViewSet, BeneficiaryViewSet,
    TransactionViewSet, TransactionHistoryViewSet
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
    path('auth/token/refresh/', TokenRefreshView.as_view()),
    path('', include(router.urls)),
]