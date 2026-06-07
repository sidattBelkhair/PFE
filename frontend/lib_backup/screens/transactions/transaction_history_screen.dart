import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/transaction_provider.dart';
import '../../models/transaction_model.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _filter = 'all';

  List<Map<String, String>> _filters(AppLocalizations l) => [
    {'value': 'all',        'label': l.all},
    {'value': 'transfer',   'label': l.transfers},
    {'value': 'received',   'label': l.received},
    {'value': 'withdrawal', 'label': l.withdrawal},
    {'value': 'payment',    'label': l.payment},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  String _dateLabel(DateTime date, AppLocalizations l) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return l.today;
    if (d == today.subtract(const Duration(days: 1))) return l.yesterday;
    return DateFormat('dd MMMM yyyy', 'fr').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l.history),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters(l).map((f) {
                  final selected = _filter == f['value'];
                  return GestureDetector(
                    onTap: () => setState(() => _filter = f['value']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primaryGold : AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        f['label']!,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Liste
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, tp, _) {
                if (tp.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGold),
                  );
                }
                if (tp.errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                        const SizedBox(height: 12),
                        Text(tp.errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: tp.fetchTransactions,
                          child: Text(l.retry),
                        ),
                      ],
                    ),
                  );
                }

                final filtered = tp.transactions.where((t) {
                  if (_filter == 'all') return true;
                  if (_filter == 'received') return t.isCredit;
                  return t.transactionType == _filter && !t.isCredit;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: AppTheme.lightGold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.receipt_long_rounded,
                              color: AppTheme.primaryGold, size: 48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l.noTransactions,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.noTransactionsDesc,
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                // Groupement par date
                final grouped = <String, List<TransactionModel>>{};
                for (final tx in filtered) {
                  final key = _dateLabel(tx.createdAt, l);
                  grouped.putIfAbsent(key, () => []).add(tx);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: grouped.keys.length,
                  itemBuilder: (context, i) {
                    final date = grouped.keys.elementAt(i);
                    final txs = grouped[date]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 10, top: i == 0 ? 0 : 16),
                          child: Text(
                            date,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        ...txs.map((tx) => _TransactionCard(tx: tx)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte de transaction ─────────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final TransactionModel tx;
  const _TransactionCard({required this.tx});

  Color get _statusColor {
    switch (tx.status) {
      case 'completed': return AppTheme.successColor;
      case 'pending':
      case 'processing': return const Color(0xFFE67E22);
      case 'failed':
      case 'reversed': return AppTheme.errorColor;
      default: return AppTheme.textSecondary;
    }
  }

  IconData get _typeIcon {
    if (tx.isCredit) return Icons.arrow_downward_rounded;
    switch (tx.transactionType) {
      case 'transfer': return Icons.send_rounded;
      case 'deposit': return Icons.arrow_downward_rounded;
      case 'withdrawal': return Icons.atm_rounded;
      case 'payment': return Icons.payment_rounded;
      default: return Icons.swap_horiz_rounded;
    }
  }

  Color get _amountColor {
    if (tx.status == 'failed' || tx.status == 'reversed') return AppTheme.errorColor;
    return tx.isCredit ? AppTheme.successColor : AppTheme.errorColor;
  }

  String _statusLabel(AppLocalizations l) {
    switch (tx.status) {
      case 'completed': return l.statusCompleted;
      case 'pending': return l.statusPending;
      case 'processing': return l.statusProcessing;
      case 'failed': return l.statusFailed;
      case 'reversed': return l.statusCancelled;
      default: return tx.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final time = DateFormat('HH:mm').format(tx.createdAt);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
          // Icône
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_typeIcon, color: _statusColor, size: 22),
          ),
          const SizedBox(width: 14),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.counterpartLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(time,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _statusLabel(l),
                        style: TextStyle(
                            color: _statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Montant
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tx.isCredit ? '+' : '-'}${tx.amount.toStringAsFixed(0)} ${tx.currency}',
                style: TextStyle(
                  color: _amountColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (tx.referenceNumber != null)
                Text(
                  tx.referenceNumber!,
                  style: const TextStyle(color: AppTheme.textHint, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
