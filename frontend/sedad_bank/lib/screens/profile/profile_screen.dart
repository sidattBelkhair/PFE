import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Mon Profil'),
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
            return const Center(child: Text('Utilisateur non trouvé'));
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
                  child: _isEditing ? _buildForm(auth) : _buildInfoCard(user),
                ),

                const SizedBox(height: 20),

                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _ProfileAction(
                        icon: Icons.lock_outline,
                        label: 'Changer le mot de passe',
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
                          label: const Text(
                            'Déconnexion',
                            style: TextStyle(color: AppTheme.errorColor),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.errorColor),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _logout(context, auth),
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

  Widget _buildInfoCard(user) {
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
          _InfoRow(label: 'Prénom', value: user.firstName, icon: Icons.person_outline),
          const Divider(indent: 56, height: 1),
          _InfoRow(label: 'Nom', value: user.lastName, icon: Icons.person_outline),
          const Divider(indent: 56, height: 1),
          _InfoRow(label: 'Email', value: user.email, icon: Icons.email_outlined),
          const Divider(indent: 56, height: 1),
          _InfoRow(
            label: 'Téléphone',
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

  Widget _buildForm(AuthProvider auth) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _firstNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Prénom',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _lastNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone',
              prefixIcon: Icon(Icons.phone_outlined),
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
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : () => _save(auth),
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child:
                              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await auth.updateProfile(
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      phoneNumber: _phoneCtrl.text.trim(),
    );
    if (ok && mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnexion'),
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
