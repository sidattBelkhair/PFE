import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kyc_auth_helper.dart';

class KycIntroScreen extends StatelessWidget {
  const KycIntroScreen({super.key});

  static const Color rssGreen = Color(0xFF0F6E4E);

  @override
  Widget build(BuildContext context) {
    final kyc  = context.read<KycProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),

              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: rssGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  size: 48,
                  color: rssGreen,
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'Vérification rapide et sécurisée',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Complétez quelques étapes simples pour vérifier votre identité et débloquer toutes les fonctionnalités.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.4),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.access_time,
                          color: Color(0xFF666666), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Temps estimé',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text('2-5 minutes',
                            style: TextStyle(
                                color: Color(0xFF666666), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Étapes de vérification',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              const _StepRow(
                icon: Icons.description_outlined,
                title: 'Scannez votre document',
                subtitle:
                    'Prenez des photos de votre carte d\'identité ou passeport',
              ),
              const _StepRow(
                icon: Icons.person_outline,
                title: 'Confirmez vos informations',
                subtitle:
                    'Vérifiez et confirmez vos informations personnelles',
              ),
              const _StepRow(
                icon: Icons.camera_alt_outlined,
                title: 'Vérifiez que c\'est vous',
                subtitle: 'Scan facial rapide pour la sécurité',
                isLast: true,
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(Icons.info_outline,
                        size: 18, color: Color(0xFF666666)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vos documents sont traités de manière sécurisée et ne seront pas partagés sans votre consentement, sauf si la loi l\'exige.',
                        style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 12.5,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    kyc.goToSelectDocument();
                    context.push('/kyc/select-document');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rssGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Démarrer la vérification',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () async {
                  final confirmed = await _showSkipDialog(context);
                  if (confirmed == true) {
                    final userId = await KycAuthHelper.getUserId(auth);
                    if (userId != null) {
                      await kyc.skip(userId);
                    }
                    if (context.mounted) {
                      context.go('/home');
                    }
                  }
                },
                child: const Text(
                  'Passer pour l\'instant',
                  style: TextStyle(color: Color(0xFF666666)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _showSkipDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Passer la vérification ?'),
        content: const Text(
          'Vous pourrez compléter la vérification plus tard depuis votre profil. '
          'Certaines fonctionnalités resteront limitées tant que votre identité n\'est pas vérifiée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Passer'),
          ),
        ],
      ),
    );
  }
}


class _StepRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isLast;

  const _StepRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Icon(icon, color: const Color(0xFF666666), size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: const Color(0xFFE5E7EB),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 13,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
