import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

class PaiementFacturesScreen extends StatefulWidget {
  const PaiementFacturesScreen({Key? key}) : super(key: key);

  @override
  State<PaiementFacturesScreen> createState() => _PaiementFacturesScreenState();
}

class _PaiementFacturesScreenState extends State<PaiementFacturesScreen> {
  static const _billers = [
    {'name': 'SOMELEC',   'subtitle': 'Société mauritanienne d\'électricité',    'icon': Icons.bolt_outlined,          'color': Color(0xFFFFC107)},
    {'name': 'SNDE',      'subtitle': 'Société nationale de l\'eau',             'icon': Icons.water_drop_outlined,    'color': Color(0xFF2196F3)},
    {'name': 'Mauritel',  'subtitle': 'Opérateur téléphonique',                 'icon': Icons.signal_cellular_alt,    'color': Color(0xFFE91E63)},
    {'name': 'Mattel',    'subtitle': 'Opérateur téléphonique',                 'icon': Icons.signal_cellular_alt,    'color': Color(0xFF9C27B0)},
    {'name': 'Chinguitel','subtitle': 'Opérateur téléphonique',                 'icon': Icons.signal_cellular_alt,    'color': Color(0xFF4CAF50)},
    {'name': 'Camtel',    'subtitle': 'Internet fibre optique',                  'icon': Icons.wifi_outlined,          'color': Color(0xFF00BCD4)},
    {'name': 'Autres',    'subtitle': 'Autre fournisseur',                       'icon': Icons.receipt_long_outlined,  'color': Color(0xFF607D8B)},
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Paiement de factures',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _billers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (context, i) {
          final b = _billers[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: (b['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(b['icon'] as IconData, color: b['color'] as Color, size: 24),
              ),
              title: Text(b['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppTheme.textPrimary)),
              subtitle: Text(b['subtitle'] as String,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () => _showFactureDialog(context, b['name'] as String),
            ),
          );
        },
      ),
    );
  }

  void _showFactureDialog(BuildContext context, String billerName) {
    final refCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.dividerColor, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payer $billerName',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: refCtrl,
              decoration: InputDecoration(
                labelText: 'Numéro de contrat / référence',
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
                labelText: 'Montant à payer',
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
                  onPressed: tp.isLoading ? null : () async {
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
                      description: 'Facture $billerName — Réf: $ref',
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
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    color: AppTheme.successColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 44),
                                ),
                                const SizedBox(height: 16),
                                Text('Facture $billerName payée !',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Le paiement de ${amount.toStringAsFixed(0)} MRU a été effectué et enregistré dans votre historique.',
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
                  },
                  child: tp.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Payer la facture', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
