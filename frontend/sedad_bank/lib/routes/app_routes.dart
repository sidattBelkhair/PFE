import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/register_step2_screen.dart';
import '../screens/auth/change_password_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/transactions/transfer_screen.dart';
import '../screens/transactions/transfer_confirmation_screen.dart';
import '../screens/transactions/transaction_history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/accounts/create_account_screen.dart';
import '../screens/services/recharge_screen.dart';
import '../screens/services/retraits_screen.dart';
import '../screens/services/paiements_screen.dart';
import '../screens/services/paiement_factures_screen.dart';
import '../screens/services/plus_services_screen.dart';
import '../screens/qr/qr_transactions_screen.dart';
import '../screens/bank/ma_banque_screen.dart';
import '../widgets/main_shell.dart';

const _publicRoutes = [
  '/login', '/register', '/register-step2',
  '/verify-email', '/forgot-password', '/reset-password',
];

class AppRoutes {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (BuildContext context, GoRouterState state) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.sessionLoaded) return null;
      final isAuth = auth.isAuthenticated;
      final isPublic = _publicRoutes.contains(state.matchedLocation);
      if (!isAuth && !isPublic) return '/login';
      if (isAuth && isPublic) return auth.isAdmin ? '/admin' : '/home';
      return null;
    },
    routes: [
      // ── Pages publiques ────────────────────────────────────────────────
      GoRoute(path: '/login',            builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register',         builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/register-step2',   builder: (_, __) => const RegisterStep2Screen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => VerifyEmailScreen(
          email: state.extra as String? ?? '',
        ),
      ),
      GoRoute(path: '/forgot-password',  builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          email: state.extra as String? ?? '',
        ),
      ),

      // ── Admin ──────────────────────────────────────────────────────────
      GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen()),

      // ── Shell principal avec bottom nav (5 onglets) ────────────────────
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child, state: state),
        routes: [
          GoRoute(path: '/home',            builder: (_, __) => const HomeContent()),
          GoRoute(path: '/history',         builder: (_, __) => const TransactionHistoryScreen()),
          GoRoute(path: '/qr-transactions', builder: (_, __) => const QrTransactionsScreen()),
          GoRoute(path: '/ma-banque',       builder: (_, __) => const MaBanqueScreen()),
          GoRoute(path: '/profile',         builder: (_, __) => const ProfileScreen()),
        ],
      ),

      // ── Sous-pages pushées par-dessus le shell ──────────────────────────
      GoRoute(path: '/transfer',              builder: (_, __) => const TransferScreen()),
      GoRoute(path: '/transfer-confirmation', builder: (_, __) => const TransferConfirmationScreen()),
      GoRoute(path: '/create-account',        builder: (_, __) => const CreateAccountScreen()),
      GoRoute(path: '/recharge',              builder: (_, __) => const RechargeScreen()),
      GoRoute(path: '/retraits',              builder: (_, __) => const RetraitsScreen()),
      GoRoute(path: '/paiements',             builder: (_, __) => const PaiementsScreen()),
      GoRoute(path: '/paiement-factures',     builder: (_, __) => const PaiementFacturesScreen()),
      GoRoute(path: '/plus-services',         builder: (_, __) => const PlusServicesScreen()),
      GoRoute(path: '/change-password',        builder: (_, __) => const ChangePasswordScreen()),
    ],
  );
}
