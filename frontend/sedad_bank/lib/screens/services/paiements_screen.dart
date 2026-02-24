import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

class PaiementsScreen extends StatefulWidget {
  const PaiementsScreen({Key? key}) : super(key: key);

  @override
  State<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends State<PaiementsScreen> {
  static const _categories = [
    {'label': 'Eau',              'icon': Icons.water_drop_outlined,        'color': Color(0xFF2196F3)},
    {'label': 'Électricité',      'icon': Icons.bolt_outlined,              'color': Color(0xFFFFC107)},
    {'label': 'Internet',         'icon': Icons.wifi_outlined,              'color': Color(0xFF9C27B0)},
    {'label': 'Téléphone',        'icon': Icons.phone_android_outlined,     'color': Color(0xFF4CAF50)},
    {'label': 'Loyer',            'icon': Icons.home_outlined,              'color': Color(0xFFFF5722)},
    {'label': 'Assurance',        'icon': Icons.shield_outlined,            'color': Color(0xFF00BCD4)},
    {'label': 'Transport',        'icon': Icons.directions_bus_outlined,    'color': Color(0xFF795548)},
    {'label': 'Autres',           'icon': Icons.more_horiz_outlined,        'color': Color(0xFF607D8B)},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Paiements',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.textPrimary),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.1,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final cat = _categories[i];
          return GestureDetector(
            onTap: () => _showPaymentDialog(context, cat['label'] as String),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (cat['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat['icon'] as IconData, color: cat['color'] as Color, size: 28),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    cat['label'] as String,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, String category) {
    final refCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Paiement — $category',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: refCtrl,
              decoration: InputDecoration(
                labelText: 'Référence / Numéro de compte',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Montant',
                suffixText: 'MRU',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Consumer2<AccountProvider, TransactionProvider>(
              builder: (context, ap, tp, _) => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: tp.isLoading ? null : () => _submitPayment(ctx, ap, tp, category, refCtrl, amountCtrl),
                  child: tp.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Payer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPayment(
    BuildContext ctx,
    AccountProvider ap,
    TransactionProvider tp,
    String category,
    TextEditingController refCtrl,
    TextEditingController amountCtrl,
  ) async {
    final ref = refCtrl.text.trim();
    final amountStr = amountCtrl.text.trim();
    if (ref.isEmpty || amountStr.isEmpty) return;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;
    final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) return;

    final ok = await tp.createTransaction(
      fromAccountId: account.id,
      transactionType: 'payment',
      amount: amount,
      description: 'Paiement $category — Réf: $ref',
      currency: account.currency,
    );

    if (ctx.mounted) {
      Navigator.pop(ctx);
      if (ok) {
        await showDialog(
          context: context,
          builder: (dCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 44),
                ),
                const SizedBox(height: 16),
                const Text('Paiement effectué !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Votre paiement de ${amount.toStringAsFixed(0)} MRU a été traité et enregistré dans votre historique.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dCtx),
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
            content: Text(tp.errorMessage ?? 'Erreur lors du paiement'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
