import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({Key? key}) : super(key: key);

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  String _accountType = 'checking';
  String _currency = 'MRU';

  static const _accountTypes = [
    {'value': 'checking', 'label': 'Compte courant', 'icon': Icons.account_balance_wallet_outlined},
    {'value': 'savings',  'label': 'Compte épargne', 'icon': Icons.savings_outlined},
    {'value': 'business', 'label': 'Compte professionnel', 'icon': Icons.business_outlined},
  ];

  static const _currencies = ['MRU', 'DZD', 'EUR', 'USD'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Nouveau compte'),
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
              // Illustration
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.add_card_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Créer un nouveau compte bancaire',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Nom du compte
              const Text(
                'Nom du compte',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  hintText: 'Ex: Compte principal',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Veuillez nommer votre compte' : null,
              ),

              const SizedBox(height: 22),

              // Type de compte
              const Text(
                'Type de compte',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              ...(_accountTypes.map((type) {
                final selected = _accountType == type['value'];
                return GestureDetector(
                  onTap: () => setState(() => _accountType = type['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.lightGold : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppTheme.primaryGold : AppTheme.dividerColor,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          type['icon'] as IconData,
                          color: selected ? AppTheme.primaryGold : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 14),
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: selected ? AppTheme.darkGold : AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check_circle_rounded,
                              color: AppTheme.primaryGold, size: 20),
                      ],
                    ),
                  ),
                );
              })),

              const SizedBox(height: 22),

              // Devise
              const Text(
                'Devise',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: _currencies.map((c) {
                  final selected = _currency == c;
                  return ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    onSelected: (_) => setState(() => _currency = c),
                    selectedColor: AppTheme.primaryGold,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: selected ? AppTheme.primaryGold : AppTheme.dividerColor,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              Consumer<AccountProvider>(
                builder: (context, provider, _) => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: provider.isLoading ? null : _submit,
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Créer le compte'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AccountProvider>();
    final ok = await provider.createAccount(
      accountName: _nameCtrl.text.trim(),
      accountType: _accountType,
      currency: _currency,
    );
    if (mounted) {
      if (ok) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.successColor, size: 44),
                ),
                const SizedBox(height: 16),
                const Text('Compte créé !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'Votre nouveau compte bancaire a été créé avec succès.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.go('/home');
                    },
                    child: const Text('Accéder à mon compte'),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Erreur lors de la création'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }
}
