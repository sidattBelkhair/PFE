import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/bank_card_widget.dart';
import '../../widgets/app_drawer.dart';

class HomeContent extends StatefulWidget {
  const HomeContent({Key? key}) : super(key: key);

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _services = [
    {'label': 'Paiements',          'icon': Icons.payments_outlined,          'route': '/paiements'},
    {'label': 'Transferts',         'icon': Icons.swap_horiz_rounded,         'route': '/transfer'},
    {'label': 'Retraits',           'icon': Icons.atm_rounded,                'route': '/retraits'},
    {'label': 'Recharge tél.',      'icon': Icons.phone_android_outlined,     'route': '/recharge'},
    {'label': 'Paiement factures',  'icon': Icons.receipt_long_outlined,      'route': '/paiement-factures'},
    {'label': 'Plus de services',   'icon': Icons.apps_rounded,               'route': '/plus-services'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AccountProvider>(context, listen: false).fetchAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final firstName = user?.firstName ?? '';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: const AppDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _scaffoldKey.currentState?.openDrawer(),
                    child: const _HeaderBtn(child: Icon(Icons.menu, size: 22)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        Text(
                          firstName.isNotEmpty ? firstName : 'Bienvenue',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      const _HeaderBtn(child: Icon(Icons.notifications_outlined, size: 22)),
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Contenu scrollable ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Carte bancaire
                    Consumer2<AccountProvider, AuthProvider>(
                      builder: (context, ap, auth, _) {
                        if (ap.isLoading) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(color: AppTheme.primaryGold),
                            ),
                          );
                        }
                        if (ap.accounts.isEmpty) {
                          return _EmptyCard(
                            onCreateTap: () => context.push('/create-account'),
                          );
                        }
                        final account = ap.selectedAccount ?? ap.accounts.first;
                        final userName = auth.currentUser?.getFullName() ?? '';
                        return BankCardWidget(account: account, userName: userName);
                      },
                    ),

                    const SizedBox(height: 12),

                    // Pagineur comptes
                    Consumer<AccountProvider>(
                      builder: (context, ap, _) {
                        if (ap.accounts.length <= 1) return const SizedBox.shrink();
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(ap.accounts.length, (i) {
                            final selected = (ap.selectedAccount ?? ap.accounts.first).id == ap.accounts[i].id;
                            return GestureDetector(
                              onTap: () => ap.selectAccount(ap.accounts[i]),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: selected ? 20 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: selected ? AppTheme.primaryGold : AppTheme.dividerColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            );
                          }),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // Grille services 2×3
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 1.3,
                        ),
                        itemCount: _services.length,
                        itemBuilder: (context, i) {
                          final s = _services[i];
                          return _ServiceCard(
                            icon: s['icon'] as IconData,
                            label: s['label'] as String,
                            onTap: () {
                              final route = s['route'] as String;
                              if (route == '/transfer') {
                                context.push(route);
                              } else {
                                context.push(route);
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return '';
    return 'Bonsoir';
  }
}

// ── Carte vide ────────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyCard({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            const Text('Aucun compte', style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onCreateTap,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bouton header ─────────────────────────────────────────────────────────────
class _HeaderBtn extends StatelessWidget {
  final Widget child;
  const _HeaderBtn({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconTheme(
        data: const IconThemeData(color: AppTheme.textPrimary),
        child: child,
      ),
    );
  }
}

// ── Carte de service ──────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ServiceCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: AppTheme.textPrimary),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// @deprecated Utilisez HomeContent + MainShell à la place
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => const HomeContent();
}
