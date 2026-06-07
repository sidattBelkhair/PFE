import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../core/theme/app_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
      context.read<TransactionProvider>().fetchTransactions();
      context.read<UserProvider>().fetchUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Administration'),
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (mounted) context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'Utilisateurs'),
            Tab(icon: Icon(Icons.account_balance_rounded), text: 'Comptes'),
            Tab(icon: Icon(Icons.receipt_long_rounded), text: 'Transactions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UsersTab(),
          _AccountsTab(),
          _TransactionsTab(),
        ],
      ),
    );
  }
}

// ── Onglet Utilisateurs ─────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGold),
          );
        }
        if (provider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
                const SizedBox(height: 12),
                Text(provider.errorMessage!),
                const SizedBox(height: 12),
                ElevatedButton(onPressed: provider.fetchUsers, child: const Text('Réessayer')),
              ],
            ),
          );
        }
        if (provider.users.isEmpty) {
          return const Center(child: Text('Aucun utilisateur'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: provider.users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => _UserCard(user: provider.users[i]),
        );
      },
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserModel user;
  const _UserCard({required this.user});

  Color get _statusColor {
    switch (user.status) {
      case 'active': return AppTheme.successColor;
      case 'suspended': return const Color(0xFFE67E22);
      case 'blocked': return AppTheme.errorColor;
      default: return AppTheme.textSecondary;
    }
  }

  String get _statusLabel {
    switch (user.status) {
      case 'active': return 'Actif';
      case 'suspended': return 'Suspendu';
      case 'blocked': return 'Bloqué';
      case 'closed': return 'Fermé';
      default: return user.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials =
        '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
            .toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: user.role == 'admin'
                ? AppTheme.lightGold
                : AppTheme.backgroundColor,
            child: Text(
              initials,
              style: TextStyle(
                color: user.role == 'admin'
                    ? AppTheme.darkGold
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${user.firstName} ${user.lastName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (user.role == 'admin') ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.lightGold,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Admin',
                          style: TextStyle(
                            color: AppTheme.darkGold,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // Badge statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                color: _statusColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Menu actions
          if (user.role != 'admin')
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (_) => [
                if (user.status != 'active')
                  const PopupMenuItem(
                    value: 'active',
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 18),
                        SizedBox(width: 10),
                        Text('Activer'),
                      ],
                    ),
                  ),
                if (user.status != 'suspended')
                  const PopupMenuItem(
                    value: 'suspended',
                    child: Row(
                      children: [
                        Icon(Icons.pause_circle_outline, color: Color(0xFFE67E22), size: 18),
                        SizedBox(width: 10),
                        Text('Suspendre'),
                      ],
                    ),
                  ),
                if (user.status != 'blocked')
                  const PopupMenuItem(
                    value: 'blocked',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: AppTheme.errorColor, size: 18),
                        SizedBox(width: 10),
                        Text('Bloquer'),
                      ],
                    ),
                  ),
              ],
              onSelected: (newStatus) async {
                final provider = context.read<UserProvider>();
                final ok = await provider.updateUserStatus(user.id, newStatus);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(ok ? 'Statut mis à jour' : (provider.errorMessage ?? 'Erreur')),
                      backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }
}

// ── Onglet Comptes ──────────────────────────────────────────────────────────
class _AccountsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AccountProvider>(
      builder: (context, ap, _) {
        if (ap.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
        }

        // Stats en haut
        final active = ap.accounts.where((a) => a.status == 'active').length;
        final totalBalance = ap.accounts.fold<double>(0, (s, a) => s + a.balance);

        return Column(
          children: [
            // Statistiques
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatCard(
                    label: 'Total comptes',
                    value: '${ap.accounts.length}',
                    icon: Icons.account_balance_rounded,
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Actifs',
                    value: '$active',
                    icon: Icons.check_circle_rounded,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Total soldes',
                    value: '${totalBalance.toStringAsFixed(0)} DZD',
                    icon: Icons.attach_money_rounded,
                    color: const Color(0xFF4A90D9),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ap.accounts.isEmpty
                  ? const Center(child: Text('Aucun compte'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: ap.accounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final acc = ap.accounts[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppTheme.lightGold,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.account_balance_wallet,
                                    color: AppTheme.primaryGold),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.accountNumber,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${acc.accountType} — ${acc.currency}',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${acc.balance.toStringAsFixed(0)} ${acc.currency}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryGold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: acc.status == 'active'
                                          ? AppTheme.successColor.withOpacity(0.1)
                                          : AppTheme.errorColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      acc.status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: acc.status == 'active'
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Onglet Transactions ─────────────────────────────────────────────────────
class _TransactionsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, tp, _) {
        if (tp.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
        }

        final completed = tp.transactions.where((t) => t.status == 'completed').length;
        final totalAmount = tp.transactions.fold<double>(0, (s, t) => s + t.amount);

        return Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _StatCard(
                    label: 'Total transactions',
                    value: '${tp.transactions.length}',
                    icon: Icons.receipt_long_rounded,
                    color: AppTheme.primaryGold,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Complétées',
                    value: '$completed',
                    icon: Icons.check_rounded,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 12),
                  _StatCard(
                    label: 'Volume total',
                    value: '${totalAmount.toStringAsFixed(0)} DZD',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF4A90D9),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tp.transactions.isEmpty
                  ? const Center(child: Text('Aucune transaction'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: tp.transactions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final tx = tp.transactions[i];
                        final ok = tx.status == 'completed';
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: (ok ? AppTheme.successColor : AppTheme.errorColor)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.send_rounded,
                                  color: ok ? AppTheme.successColor : AppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      tx.referenceNumber ?? tx.id,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                    Text(
                                      tx.getFormattedDate(),
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (ok ? AppTheme.successColor : AppTheme.errorColor)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tx.status,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: ok ? AppTheme.successColor : AppTheme.errorColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ── Carte statistique ────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
