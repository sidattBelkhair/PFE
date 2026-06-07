import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../core/theme/app_theme.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Virement'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compte source
              Consumer<AccountProvider>(
                builder: (context, ap, _) {
                  final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.account_balance_wallet, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Compte source',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                account?.accountNumber ?? 'Aucun compte',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (account != null)
                                Text(
                                  'Solde : ${account.getFormattedBalance()}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),



              // Téléphone bénéficiaire
              const Text(
                'Numéro de téléphone',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  hintText: '0612345678',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Numéro requis' : null,
              ),

              const SizedBox(height: 16),

              // Montant
              const Text(
                'Montant',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '1 000',
                  prefixIcon: Icon(Icons.attach_money_outlined),
                  suffixText: 'MRU',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Montant requis';
                  final d = double.tryParse(v);
                  if (d == null || d <= 0) return 'Montant invalide';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Motif
              const Text(
                'Motif (optionnel)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Loyer, remboursement…',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),

              const SizedBox(height: 32),

              Consumer<TransactionProvider>(
                builder: (context, tp, _) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: tp.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(tp.isLoading ? 'Traitement…' : 'Confirmer le virement'),
                    onPressed: tp.isLoading ? null : () => _submit(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun compte sélectionné')),
      );
      return;
    }
    final ok = await tp.sendTransfer(
      fromAccountId: account.id,
      toPhone: _phoneCtrl.text.trim(),
      amount: double.parse(_amountCtrl.text),
      description: _descCtrl.text.trim(),
    );
    if (mounted) {
      if (ok) {
        context.push('/transfer-confirmation');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tp.errorMessage ?? 'Erreur lors du virement'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
