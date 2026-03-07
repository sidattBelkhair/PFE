import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({Key? key, required this.email}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _secondsLeft = 600;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = 600);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _codeControllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _code => _codeControllers.map((c) => c.text).join();

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onCodeChanged(int index, String value) {
    if (value.length == 1 && index < 5) _focusNodes[index + 1].requestFocus();
    if (value.isEmpty && index > 0) _focusNodes[index - 1].requestFocus();
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (_code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.verificationCode),
        backgroundColor: AppTheme.errorColor,
      ));
      return;
    }
    final auth = context.read<AuthProvider>();
    final ok = await auth.resetPassword(widget.email, _code, _passwordCtrl.text);
    if (!mounted) return;
    if (ok) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.successColor, size: 64),
              const SizedBox(height: 16),
              Text(l.passwordReset,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(l.passwordResetSuccess, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => context.go('/login'),
                child: Text(l.connect,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(auth.errorMessage ?? l.error),
        backgroundColor: AppTheme.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.go('/forgot-password'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.lock_outline_rounded,
                      color: AppTheme.primaryGreen, size: 28),
                ),
                const SizedBox(height: 24),
                Text(l.resetPassword,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Text(
                  '${l.resetPasswordSentTo} ${widget.email}',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 32),

                Text(l.verificationCode,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (i) => SizedBox(
                      width: 46,
                      height: 56,
                      child: TextField(
                        controller: _codeControllers[i],
                        focusNode: _focusNodes[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppTheme.dividerColor)),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: AppTheme.primaryGreen, width: 2)),
                        ),
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                        onChanged: (v) => _onCodeChanged(i, v),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _secondsLeft > 0
                        ? '${l.codeExpireIn} $_timerText'
                        : l.codeExpired,
                    style: TextStyle(
                      color: _secondsLeft > 0
                          ? AppTheme.textSecondary
                          : AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: l.newPassword,
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryGreen, width: 2)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.required;
                    if (v.length < 8) return l.minPassword;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: l.confirmPassword,
                    prefixIcon: const Icon(Icons.lock_outline,
                        color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppTheme.textSecondary),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: AppTheme.dividerColor)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppTheme.primaryGreen, width: 2)),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return l.passwordMismatch;
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: auth.isLoading ? null : _reset,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(l.resetButton,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
