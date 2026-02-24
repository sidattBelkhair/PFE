import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_theme.dart';

/// Shell partagé : bottom nav 5 onglets
class MainShell extends StatelessWidget {
  final Widget child;
  final GoRouterState state;

  const MainShell({Key? key, required this.child, required this.state})
      : super(key: key);

  static const _tabs = ['/home', '/history', '/qr-transactions', '/ma-banque', '/profile'];

  int get _currentIndex {
    final loc = state.matchedLocation;
    final i = _tabs.indexOf(loc);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => context.go(_tabs[i]),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(icon: Icons.home_outlined,           activeIcon: Icons.home_rounded,        label: 'Accueil',         index: 0, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.history_outlined,        activeIcon: Icons.history_rounded,     label: 'Historique',      index: 1, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.qr_code_scanner_rounded, activeIcon: Icons.qr_code_scanner_rounded, label: 'Transactions QR', index: 2, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance,   label: 'Ma banque',       index: 3, current: currentIndex, onTap: onTap),
              _NavItem(icon: Icons.person_outline,          activeIcon: Icons.person_rounded,      label: 'Profil',          index: 4, current: currentIndex, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int current;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? activeIcon : icon,
              size: 24,
              color: selected ? AppTheme.primaryGold : AppTheme.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? AppTheme.primaryGold : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
