import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../core/theme/app_theme.dart';

class TransferConfirmationScreen extends StatelessWidget {
  const TransferConfirmationScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) context.go('/home');
      },
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: SafeArea(
          child: Consumer<TransactionProvider>(
            builder: (context, tp, _) {
              final tx = tp.lastTransaction;
              final l = AppLocalizations.of(context)!;

              if (tx == null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                      const SizedBox(height: 16),
                      Text(l.transactionNotFound),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => context.go('/home'),
                        child: Text(l.backToHome),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  const Spacer(),

                  // Icône succès animée
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 64,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    l.transferSentTitle,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.transferSentSubtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                  ),

                  const SizedBox(height: 32),

                  // Montant mis en avant
                  Text(
                    '-${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGold,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Carte de détails
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _DetailRow(label: l.referenceLabel, value: tx.referenceNumber ?? tx.id.substring(0, 8).toUpperCase()),
                        const Divider(height: 20),
                        _DetailRow(label: l.beneficiaryLabel, value: tx.counterpartLabel.replaceFirst('Vers : ', '')),
                        const Divider(height: 20),
                        _DetailRow(
                          label: l.date,
                          value: DateFormat('dd/MM/yyyy HH:mm').format(tx.createdAt),
                        ),
                        const Divider(height: 20),
                        _DetailRow(
                          label: l.status,
                          value: tx.status == 'completed' ? l.statusCompleted : tx.status,
                          valueColor: AppTheme.successColor,
                        ),
                        if (tx.description != null && tx.description!.isNotEmpty) ...[
                          const Divider(height: 20),
                          _DetailRow(label: l.reason, value: tx.description!),
                        ],
                      ],
                    ),
                  ),

                  const Spacer(),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.home_rounded),
                            label: Text(l.backToHome),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.go('/home'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.history_rounded),
                            label: Text(l.viewHistory),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: AppTheme.primaryGold,
                              side: const BorderSide(color: AppTheme.primaryGold),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => context.go('/history'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
