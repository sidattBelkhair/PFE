import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({Key? key}) : super(key: key);

  @override
  State<RechargeScreen> createState() => _RechargeScreenState();
}

class _RechargeScreenState extends State<RechargeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneCtrl = TextEditingController();
  int? _selectedAmount;

  static const _amounts = [10, 20, 30, 50, 75, 100, 150, 200, 300, 500, 1000, 2000];

  static const _countries = [
    {'name': 'Maroc',           'flag': '🇲🇦'},
    {'name': "Côte d'Ivoire",   'flag': '🇨🇮'},
    {'name': 'Turquie',         'flag': '🇹🇷'},
    {'name': 'Tunisie',         'flag': '🇹🇳'},
    {'name': 'Espagne',         'flag': '🇪🇸'},
    {'name': 'Sénégal',         'flag': '🇸🇳'},
    {'name': 'États-Unis',      'flag': '🇺🇸'},
    {'name': 'Arabie Saoudite', 'flag': '🇸🇦'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
      final phone = context.read<AuthProvider>().currentUser?.phoneNumber;
      if (phone != null && phone.isNotEmpty) _phoneCtrl.text = phone;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Recharge téléphonique',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // Segment control
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(23),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'Mauritanie'), Tab(text: 'International')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildMauritanieTab(), _buildInternationalTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMauritanieTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Veuillez entrer votre numéro de téléphone pour\nvoir les offres disponibles de votre opérateur.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Numéro de téléphone',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemCount: _amounts.length,
            itemBuilder: (context, i) {
              final amount = _amounts[i];
              final selected = _selectedAmount == amount;
              return GestureDetector(
                onTap: () => setState(() => _selectedAmount = amount),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.textPrimary : Colors.white,
                    border: Border.all(
                      color: selected ? AppTheme.textPrimary : const Color(0xFFD0D0D0),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(
                    children: [
                      if (selected)
                        const Positioned(
                          top: 6, right: 6,
                          child: Icon(Icons.check_circle, color: Colors.white, size: 14),
                        ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              amount.toString(),
                              style: TextStyle(
                                color: selected ? Colors.white : AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              'MRU',
                              style: TextStyle(
                                color: selected ? Colors.white70 : AppTheme.textSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _selectedAmount != null ? _handleRecharge : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedAmount != null
                    ? AppTheme.primaryGold
                    : const Color(0xFFE0E0E0),
                foregroundColor: _selectedAmount != null ? Colors.white : AppTheme.textSecondary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Demander', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInternationalTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Text(
            'Choisissez un pays',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _countries.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 20),
            itemBuilder: (context, i) {
              final c = _countries[i];
              return ListTile(
                leading: Text(c['flag']!, style: const TextStyle(fontSize: 28)),
                title: Text(
                  c['name']!,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${c['name']} — Bientôt disponible')),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleRecharge() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez un numéro de téléphone')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirmer la recharge'),
        content: Text('Recharger $phone avec $_selectedAmount MRU ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);

    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun compte disponible'), backgroundColor: AppTheme.errorColor),
      );
      return;
    }

    final ok = await tp.createTransaction(
      fromAccountId: account.id,
      transactionType: 'payment',
      amount: _selectedAmount!.toDouble(),
      description: 'Recharge téléphonique — $phone',
      currency: account.currency,
    );

    if (mounted) {
      if (ok) {
        setState(() => _selectedAmount = null);
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_android_rounded, color: AppTheme.successColor, size: 40),
                ),
                const SizedBox(height: 16),
                const Text('Recharge effectuée !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Le numéro $phone a été rechargé de $_selectedAmount MRU avec succès.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Parfait !'),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tp.errorMessage ?? 'Erreur lors de la recharge'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
