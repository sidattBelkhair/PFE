import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final initials = user != null
        ? '${user.firstName.isNotEmpty ? user.firstName[0] : ''}${user.lastName.isNotEmpty ? user.lastName[0] : ''}'.toUpperCase()
        : 'SB';
    final fullName = user != null ? '${user.firstName} ${user.lastName}' : 'Utilisateur';

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          // En-tête utilisateur
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 24,
              bottom: 24,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.cardGoldStart, AppTheme.cardGoldEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.25),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user?.email != null)
                        Text(
                          user!.email,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Items menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.home_outlined,
                  title: 'Accueil',
                  onTap: () { Navigator.pop(context); context.go('/home'); },
                ),

                _DrawerItem(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Mes comptes',
                  onTap: () { Navigator.pop(context); context.go('/home'); },
                ),
                _DrawerItem(
                  icon: Icons.swap_horiz_outlined,
                  title: 'Virement',
                  onTap: () { Navigator.pop(context); context.push('/transfer'); },
                ),
                _DrawerItem(
                  icon: Icons.phone_android_outlined,
                  title: 'Recharge téléphonique',
                  onTap: () { Navigator.pop(context); context.push('/recharge'); },
                ),
                _DrawerItem(
                  icon: Icons.atm_rounded,
                  title: 'Retraits',
                  onTap: () { Navigator.pop(context); context.push('/retraits'); },
                ),
                _DrawerItem(
                  icon: Icons.payments_outlined,
                  title: 'Paiement de masse',
                  onTap: () { Navigator.pop(context); },
                ),
                _DrawerItem(
                  icon: Icons.business_center_outlined,
                  title: 'Opérations bancaires',
                  onTap: () { Navigator.pop(context); },
                ),
                _DrawerItem(
                  icon: Icons.contacts_outlined,
                  title: 'Contacts',
                  onTap: () { Navigator.pop(context); },
                ),
                _DrawerItem(
                  icon: Icons.notifications_outlined,
                  title: 'Notifications',
                  onTap: () { Navigator.pop(context); },
                ),
                _DrawerItem(
                  icon: Icons.location_on_outlined,
                  title: 'Nos agences',
                  onTap: () { Navigator.pop(context); },
                ),
                if (auth.isAdmin) ...[
                  const Divider(indent: 16, endIndent: 16),
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Administration',
                    onTap: () { Navigator.pop(context); context.go('/admin'); },
                  ),
                ],
                const Divider(indent: 16, endIndent: 16),
                // Sélecteur de langue
                Consumer<LanguageProvider>(
                  builder: (context, lang, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Langue',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.lightGold,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              _LangButton(
                                label: 'Français',
                                selected: !lang.isArabic,
                                onTap: () => lang.setLocale(const Locale('fr')),
                              ),
                              _LangButton(
                                label: 'العربية',
                                selected: lang.isArabic,
                                onTap: () => lang.setLocale(const Locale('ar')),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Déconnexion
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.errorColor),
            title: const Text(
              'Déconnexion',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              await context.read<AuthProvider>().logout();
              if (context.mounted) context.go('/login');
            },
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerItem({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryGold, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textHint, size: 18),
      onTap: onTap,
      horizontalTitleGap: 8,
    );
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryGold : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
