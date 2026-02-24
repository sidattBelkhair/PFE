import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class PlusServicesScreen extends StatelessWidget {
  const PlusServicesScreen({Key? key}) : super(key: key);

  static const _services = [
    {'title': 'Transferts international',  'icon': Icons.public_outlined,           'color': Color(0xFFC49B2A)},
    {'title': 'Elkiss',                    'icon': Icons.local_activity_outlined,    'color': Color(0xFFC49B2A)},
    {'title': 'Paiement de masse',         'icon': Icons.groups_outlined,            'color': Color(0xFFC49B2A)},
    {'title': 'Airtime international',     'icon': Icons.add_ic_call_outlined,       'color': Color(0xFFC49B2A)},
    {'title': 'Cartes cadeaux',            'icon': Icons.card_giftcard_outlined,     'color': Color(0xFFC49B2A)},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: const Text(
          'Plus de services',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.textPrimary),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: _services.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final s = _services[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 6),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppTheme.lightGold,
                shape: BoxShape.circle,
              ),
              child: Icon(s['icon'] as IconData, color: AppTheme.primaryGold, size: 22),
            ),
            title: Text(
              s['title'] as String,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15, color: AppTheme.textPrimary),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${s['title']} — Bientôt disponible')),
            ),
          );
        },
      ),
    );
  }
}
