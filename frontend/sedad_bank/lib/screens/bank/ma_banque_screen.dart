import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/account_provider.dart';

class MaBanqueScreen extends StatefulWidget {
  const MaBanqueScreen({Key? key}) : super(key: key);

  @override
  State<MaBanqueScreen> createState() => _MaBanqueScreenState();
}

class _MaBanqueScreenState extends State<MaBanqueScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
    });
  }

  void _showDepositDialog(BuildContext context, String accountId, String currency) {
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
            const Text('Recharger le compte',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text('Entrez le montant à créditer sur votre compte.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Montant',
                suffixText: currency,
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
            Consumer<AccountProvider>(
              builder: (context, ap, _) => SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: ap.isLoading ? null : () async {
                    final amount = double.tryParse(amountCtrl.text.trim());
                    if (amount == null || amount <= 0) return;
                    final ok = await ap.depositToAccount(accountId: accountId, amount: amount);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      if (ok) {
                        showDialog(
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
                                  child: const Icon(Icons.check_circle_rounded,
                                      color: AppTheme.successColor, size: 44),
                                ),
                                const SizedBox(height: 16),
                                const Text('Compte rechargé !',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text(
                                  '${amount.toStringAsFixed(0)} $currency ont été crédités sur votre compte.',
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
                            content: Text(ap.errorMessage ?? 'Erreur'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                  child: ap.isLoading
                      ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Créditer le compte',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Ma banque',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card_rounded, color: AppTheme.primaryGold),
            tooltip: 'Nouveau compte',
            onPressed: () => context.push('/create-account'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Mes comptes
            const Text(
              'Mes comptes',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Consumer<AccountProvider>(
              builder: (context, ap, _) {
                if (ap.isLoading) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
                }
                if (ap.accounts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, size: 48, color: AppTheme.primaryGold),
                        const SizedBox(height: 12),
                        const Text('Aucun compte', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.push('/create-account'),
                          child: const Text('Créer un compte'),
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: ap.accounts.map((account) {
                    final isSelected = ap.selectedAccount?.id == account.id;
                    return GestureDetector(
                      onTap: () => ap.selectAccount(account),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                                  colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : AppTheme.dividerColor,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46, height: 46,
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white.withOpacity(0.2) : AppTheme.lightGold,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    account.accountType == 'savings'
                                        ? Icons.savings_outlined
                                        : Icons.account_balance_wallet_outlined,
                                    color: isSelected ? Colors.white : AppTheme.primaryGold,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.accountName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        account.accountNumber,
                                        style: TextStyle(
                                          fontSize: 12,
                                          letterSpacing: 1,
                                          color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${account.balance.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      account.currency,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSelected ? Colors.white70 : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.add_circle_outline,
                                    size: 16,
                                    color: isSelected ? Colors.white : AppTheme.primaryGold),
                                label: Text(
                                  'Recharger le compte',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : AppTheme.primaryGold,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: isSelected ? Colors.white54 : AppTheme.primaryGold,
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () => _showDepositDialog(context, account.id, account.currency),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            // Informations bancaires
            const Text(
              'SEDAD BANK',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              children: [
                _InfoRow(icon: Icons.location_on_outlined, text: 'Nouakchott, Mauritanie — Rue du Commerce'),
                _InfoRow(icon: Icons.phone_outlined,       text: '+222 45 25 10 00'),
                _InfoRow(icon: Icons.email_outlined,       text: 'contact@sedadbank.mr'),
                _InfoRow(icon: Icons.schedule_outlined,    text: 'Lun–Ven : 8h00–17h00'),
              ],
            ),

            const SizedBox(height: 20),

            // Agences
            const Text(
              'Nos agences',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            _InfoCard(
              children: [
                _InfoRow(icon: Icons.storefront_outlined, text: 'Agence Centrale — Tevragh Zeina'),
                _InfoRow(icon: Icons.storefront_outlined, text: 'Agence Ksar — Centre ville'),
                _InfoRow(icon: Icons.storefront_outlined, text: 'Agence Sebkha'),
                _InfoRow(icon: Icons.storefront_outlined, text: 'Agence El Mina'),
              ],
            ),

            const SizedBox(height: 20),

            // Services rapides
            Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    icon: Icons.headset_mic_outlined,
                    label: 'Support\nclient',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('+222 45 25 10 00')),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.add_card_rounded,
                    label: 'Nouveau\ncompte',
                    onTap: () => context.push('/create-account'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.send_rounded,
                    label: 'Virement',
                    onTap: () => context.push('/transfer'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: List.generate(children.length, (i) => Column(
          children: [
            children[i],
            if (i < children.length - 1) const Divider(height: 1, indent: 52),
          ],
        )),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryGold),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 26),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
