import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/transaction_model.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../core/theme/app_theme.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _phoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _selectedBank;
  final _formKey = GlobalKey<FormState>();

  static const _banks = ['Banque Centrale de Mauritanie', 'BNM', 'BMCI', 'Attijari', 'Chinguibank', 'GBM', 'BCI'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().fetchTransactions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l.transfer),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
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
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4)],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: AppTheme.textPrimary,
                unselectedLabelColor: AppTheme.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
        .where((t) => t.transactionType == 'transfer' && !t.isCredit)
        .toList();
    final seen = <String>{};
    final recentTransfers = <TransactionModel>[];
    for (final t in recents) {
      final key = t.toAccountName.isNotEmpty ? t.toAccountName : (t.toBeneficiaryName ?? t.id);
      if (seen.add(key)) recentTransfers.add(t);
      if (recentTransfers.length == 6) break;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.transferRssbankHint,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l.phone,
                suffixIcon: const Icon(Icons.contacts_outlined),
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
              validator: (v) => (v == null || v.isEmpty) ? l.phoneRequired : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l.amount,
                suffixText: 'MRU',
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
              validator: (v) {
                if (v == null || v.isEmpty) return l.amountRequired;
                final d = double.tryParse(v);
                if (d == null || d <= 0) return l.amountInvalid;
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: InputDecoration(
                labelText: l.labelOptional,
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
            const SizedBox(height: 28),
            Consumer<TransactionProvider>(
              builder: (context, tp, _) => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: tp.isLoading ? null : () => _submitRssbank(context),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: tp.isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(l.sendButton, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
            if (recentTransfers.isNotEmpty) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppTheme.dividerColor)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(l.orDivider, style: const TextStyle(color: AppTheme.textHint, fontSize: 12)),
                  ),
                  const Expanded(child: Divider(color: AppTheme.dividerColor)),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                l.sendAgainTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recentTransfers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final t = recentTransfers[i];
                    final name = t.toBeneficiaryName ?? t.toAccountName;
                    final phone = t.toAccountName;
                    return GestureDetector(
                      onTap: () => setState(() => _phoneCtrl.text = phone),
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
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            if (phone.isNotEmpty)
                              Text(phone, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _selectedBank,
            hint: Text(l.chooseBankHint),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            items: _banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
            onChanged: (v) => setState(() => _selectedBank = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l.phone,
              suffixIcon: const Icon(Icons.contacts_outlined),
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
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l.amount,
              suffixText: 'MRU',
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
          const SizedBox(height: 28),
          Consumer<TransactionProvider>(
            builder: (context, tp, _) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: tp.isLoading ? null : () => _submitGimtel(context),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                child: tp.isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(l.sendButton, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRssbank(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    final l = AppLocalizations.of(context)!;
    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.noAccountSelected)));
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
          SnackBar(content: Text(tp.errorMessage ?? l.transferError), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _submitGimtel(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final phone = _phoneCtrl.text.trim();
    final amountStr = _amountCtrl.text.trim();
    if (phone.isEmpty || amountStr.isEmpty || _selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.fillAllFields)));
      return;
    }
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.amountInvalid)));
      return;
    }
    final ap = context.read<AccountProvider>();
    final tp = context.read<TransactionProvider>();
    final account = ap.selectedAccount ?? (ap.accounts.isNotEmpty ? ap.accounts.first : null);
    if (account == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.noAccountSelected)));
      return;
    }
    final ok = await tp.sendTransfer(
      fromAccountId: account.id,
      toPhone: phone,
      amount: amount,
      description: 'Virement GIMTEL - ${_selectedBank ?? ''}',
    );
    if (mounted) {
      if (ok) {
        context.push('/transfer-confirmation');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tp.errorMessage ?? l.transferError), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }
}
