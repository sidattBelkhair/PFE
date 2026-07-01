import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/transaction_model.dart';
import '../../providers/account_provider.dart';
import '../../providers/transaction_provider.dart';

class PaiementsScreen extends StatefulWidget {
  const PaiementsScreen({Key? key}) : super(key: key);

  @override
  State<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends State<PaiementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _selectedBank;

  static const _banks = [
    'BCM',
    'TrackPay',
    'BNM',
    'BMCI',
    'Attijari',
    'Chinguibank',
    'GBM',
    'BCI'
  ];
  bool get _isTrackPay => _selectedBank == 'TrackPay';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchAccounts();
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          l.paymentsTitle,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 22,
              color: AppTheme.textPrimary),
        ),
      ),
      body: Column(
        children: [
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
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08), blurRadius: 4)
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: 'RSS BANK'), Tab(text: 'GIMTEL')],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRssbankForm(l),
                _buildGimtelForm(l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRssbankForm(AppLocalizations l) {
    final recents = context
        .watch<TransactionProvider>()
        .transactions
        .where((t) => t.transactionType == 'payment' && !t.isCredit)
        .toList();
    final seen = <String>{};
    final recentPayments = <TransactionModel>[];
    for (final t in recents) {
      final key = t.referenceNumber ?? t.description ?? t.id;
      if (seen.add(key)) recentPayments.add(t);
      if (recentPayments.length == 6) break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.paymentCodeHint,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeCtrl,
            decoration: InputDecoration(
              labelText: l.paymentCodeLabel,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Consumer<TransactionProvider>(
                  builder: (context, tp, _) => OutlinedButton(
                    onPressed: tp.isLoading
                        ? null
                        : () => _handleRssbankPayment(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successColor,
                      side: const BorderSide(color: AppTheme.successColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: tp.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.payButton,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.scanQrComingSoon)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text(l.scanButton,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
          if (recentPayments.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(
              children: [
                const Expanded(child: Divider(color: AppTheme.dividerColor)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(l.orDivider,
                      style: const TextStyle(
                          color: AppTheme.textHint, fontSize: 12)),
                ),
                const Expanded(child: Divider(color: AppTheme.dividerColor)),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              l.payAgainTitle,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentPayments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final t = recentPayments[i];
                  final name = t.toBeneficiaryName ??
                      t.description ??
                      l.paymentCodeLabel;
                  final code = t.referenceNumber ?? '';
                  return GestureDetector(
                    onTap: () => setState(() => _codeCtrl.text = code),
                    child: Container(
                      width: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (code.isNotEmpty)
                            Text(code,
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGimtelForm(AppLocalizations l) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.gimtelHint,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedBank,
            hint: Text(l.chooseBankHint),
            decoration: InputDecoration(
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            items: _banks
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _selectedBank = v),
          ),
          const SizedBox(height: 16),
          if (_isTrackPay)
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l.email,
                suffixIcon: const Icon(Icons.email_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryGold, width: 2),
                ),
              ),
            )
          else
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.phone,
                suffixIcon: const Icon(Icons.contacts_outlined),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryGold, width: 2),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.amount,
              suffixText: 'MRU',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryGold, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Consumer<TransactionProvider>(
                  builder: (context, tp, _) => OutlinedButton(
                    onPressed: tp.isLoading
                        ? null
                        : () => _handleGimtelPayment(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.successColor,
                      side: const BorderSide(color: AppTheme.successColor),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: tp.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.payButton,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.scanQrComingSoon)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.textPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.qr_code_scanner, size: 18),
                  label: Text(l.scanButton,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleRssbankPayment(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.fillAllFields)));
      return;
    }
    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ??
        (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.noAccountAvailableMsg)));
      return;
    }

    final ok = await tp.createTransaction(
      fromAccountId: account.id,
      transactionType: 'payment',
      amount: 0,
      description: 'Paiement RSS BANK — Code: $code',
      currency: account.currency,
    );

    if (mounted) {
      if (ok) {
        _codeCtrl.clear();
        await _showSuccessDialog(l);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tp.errorMessage ?? l.paymentError),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _handleGimtelPayment(BuildContext context) async {
    if (_isTrackPay) {
      await _handleTrackPayPayment(context);
    } else {
      await _handleOtherBankPayment(context);
    }
  }

  Future<void> _handleTrackPayPayment(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final email = _emailCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    if (email.isEmpty || amountStr.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.fillAllFields)));
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.amountInvalid)));
      return;
    }

    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ??
        (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.noAccountAvailableMsg)));
      return;
    }

    final recipientName = await tp.resolveTrackPayAccount(email);
    if (recipientName == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tp.errorMessage ?? l.paymentError),
              backgroundColor: AppTheme.errorColor),
        );
      }
      return;
    }

    final ok = await tp.payTrackPay(
        fromAccountId: account.id, email: email, amount: amount);

    if (mounted) {
      if (ok) {
        _emailCtrl.clear();
        _amountCtrl.clear();
        setState(() => _selectedBank = null);
        await _showSuccessDialog(l, amount: amount);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tp.errorMessage ?? l.paymentError),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _handleOtherBankPayment(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final phone = _phoneCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    if (phone.isEmpty || amountStr.isEmpty || _selectedBank == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.fillAllFields)));
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.amountInvalid)));
      return;
    }

    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ??
        (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.noAccountAvailableMsg)));
      return;
    }

    final ok = await tp.createTransaction(
      fromAccountId: account.id,
      transactionType: 'payment',
      amount: amount,
      description: 'Paiement GIMTEL - ${_selectedBank ?? ''}',
      toPhone: phone,
      currency: account.currency,
    );

    if (mounted) {
      if (ok) {
        _phoneCtrl.clear();
        _amountCtrl.clear();
        setState(() => _selectedBank = null);
        await _showSuccessDialog(l, amount: amount);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(tp.errorMessage ?? l.paymentError),
              backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _showSuccessDialog(AppLocalizations l, {double? amount}) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successColor, size: 44),
            ),
            const SizedBox(height: 16),
            Text(l.paymentDoneTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              l.paymentDoneMsg((amount ?? 0).toStringAsFixed(0)),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l.perfectExclaim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
