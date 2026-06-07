import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser;
    _firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(l.profile),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryGold),
              onPressed: () => setState(() => _isEditing = true),
            ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          final user = auth.currentUser;
          if (user == null) {
            return Center(child: Text(l.error));
          }
          final initials =
              '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'
                  .toUpperCase();

          return SingleChildScrollView(
            child: Column(
              children: [
                // En-tête doré
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withOpacity(0.25),
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 30,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.getFullName(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          user.role == 'admin' ? 'Administrateur' : 'Client',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Infos / formulaire
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _isEditing ? _buildForm(auth, l) : _buildInfoCard(user, l),
                ),

                const SizedBox(height: 20),

                // Switcher de langue
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildLanguageCard(l),
                ),

                const SizedBox(height: 10),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _ProfileAction(
                        icon: Icons.lock_outline,
                        label: l.changePassword,
                        onTap: () => context.push('/change-password'),
                      ),
                      const SizedBox(height: 10),
                      _ProfileAction(
                        icon: Icons.notifications_outlined,
                        label: 'Paramètres des notifications',
                        onTap: () {},
                      ),
                      const SizedBox(height: 10),
                      _ProfileAction(
                        icon: Icons.help_outline,
                        label: 'Aide & Support',
                        onTap: () {},
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                          label: Text(
                            l.logout,
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _logout(context, auth, l),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageCard(AppLocalizations l) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.language, color: AppTheme.primaryGold, size: 22),
              const SizedBox(width: 14),
              Text(
                l.language,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const Spacer(),
              // Bouton FR
              _LangButton(
                label: 'FR',
                selected: !lang.isArabic,
                onTap: () => lang.setLocale(const Locale('fr')),
              ),
              const SizedBox(width: 8),
              // Bouton AR
              _LangButton(
                label: 'AR',
                selected: lang.isArabic,
                onTap: () => lang.setLocale(const Locale('ar')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard(user, AppLocalizations l) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _InfoRow(label: l.firstName, value: user.firstName, icon: Icons.person_outline),
          const Divider(indent: 56, height: 1),
          _InfoRow(label: l.lastName, value: user.lastName, icon: Icons.person_outline),
          const Divider(indent: 56, height: 1),
          _InfoRow(label: l.email, value: user.email, icon: Icons.email_outlined),
          const Divider(indent: 56, height: 1),
          _InfoRow(
            label: l.phone,
            value: user.phoneNumber ?? '-',
            icon: Icons.phone_outlined,
          ),
          const Divider(indent: 56, height: 1),
          _InfoRow(
            label: 'Statut',
            value: user.status,
            icon: Icons.verified_user_outlined,
            valueColor: user.status == 'active' ? AppTheme.successColor : AppTheme.errorColor,
          ),
        ],
      ),
    );
  }

  Widget _buildForm(AuthProvider auth, AppLocalizations l) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _firstNameCtrl,
            decoration: InputDecoration(
              labelText: l.firstName,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.isEmpty) ? l.required : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lastNameCtrl,
            decoration: InputDecoration(
              labelText: l.lastName,
              prefixIcon: const Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.isEmpty) ? l.required : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l.phone,
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
          ),
          if (auth.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(auth.errorMessage!, style: const TextStyle(color: AppTheme.errorColor)),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: Text(l.cancel),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : () => _save(auth, l),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(l.save),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(AuthProvider auth, AppLocalizations l) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
    );
    if (ok && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.success),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context, AuthProvider auth, AppLocalizations l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.logout),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.logout),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await auth.logout();
      if (mounted) context.go('/login');
    }
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LangButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryGold : AppTheme.textHint,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: valueColor ?? AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ProfileAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGold, size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}
