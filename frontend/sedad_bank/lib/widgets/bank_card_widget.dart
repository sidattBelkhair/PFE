import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/account_model.dart';

class BankCardWidget extends StatefulWidget {
  final AccountModel account;
  final String userName;

  const BankCardWidget({Key? key, required this.account, required this.userName}) : super(key: key);

  @override
  State<BankCardWidget> createState() => _BankCardWidgetState();
}

class _BankCardWidgetState extends State<BankCardWidget> {
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkGold.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Cercles décoratifs
          Positioned(right: -20, top: -40,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.06)),
            ),
          ),
          Positioned(right: 30, bottom: -40,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
            ),
          ),

          // Contenu
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                // ── Ligne 1 : Logo + Toggle ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'بنك RSS',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'RSS BANK',
                          style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 2),
                        ),
                      ],
                    ),
                    // Toggle switch
                    GestureDetector(
                      onTap: () => setState(() => _balanceVisible = !_balanceVisible),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 46, height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: _balanceVisible
                              ? Colors.white.withOpacity(0.9)
                              : Colors.white.withOpacity(0.25),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _balanceVisible ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _balanceVisible ? AppTheme.primaryGold : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Ligne 2 : QR icon + Solde ──────────────────────────
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 54),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Solde', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(
                          _balanceVisible
                              ? '${widget.account.balance.toStringAsFixed(2)} ${widget.account.currency}'
                              : '•••• ••',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const Spacer(),

                // ── Ligne 3 : Numéro + Nom ─────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.account.accountNumber.length > 12
                          ? widget.account.accountNumber.substring(0, 12)
                          : widget.account.accountNumber,
                      style: const TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 2),
                    ),
                    Text(
                      widget.userName,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
