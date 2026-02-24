import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class RegisterStep2Screen extends StatefulWidget {
  const RegisterStep2Screen({Key? key}) : super(key: key);

  @override
  State<RegisterStep2Screen> createState() => _RegisterStep2ScreenState();
}

class _RegisterStep2ScreenState extends State<RegisterStep2Screen> {
  bool _idUploaded = false;
  bool _selfieUploaded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/register');
            }
          },
        ),
        title: const Text(
          'Vérification KYC',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vérification d\'identité',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pour sécuriser votre compte, nous avons besoin de vérifier votre identité.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.lightGold,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryGold),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Téléchargez une pièce d\'identité valide et prenez un selfie pour vérification.',
                        style: TextStyle(fontSize: 13, color: AppTheme.darkGold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              _UploadCard(
                icon: Icons.badge_outlined,
                title: 'Pièce d\'identité',
                subtitle: 'CNI, Passeport ou Permis de conduire',
                uploaded: _idUploaded,
                onTap: () => setState(() => _idUploaded = !_idUploaded),
              ),
              const SizedBox(height: 16),

              _UploadCard(
                icon: Icons.camera_alt_outlined,
                title: 'Selfie',
                subtitle: 'Photo de votre visage avec la pièce d\'identité',
                uploaded: _selfieUploaded,
                onTap: () => setState(() => _selfieUploaded = !_selfieUploaded),
              ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_idUploaded && _selfieUploaded)
                      ? () => context.go('/home')
                      : null,
                  child: const Text('Terminer la vérification'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.go('/home'),
                  child: const Text(
                    'Ignorer pour l\'instant',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool uploaded;
  final VoidCallback onTap;

  const _UploadCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.uploaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: uploaded ? AppTheme.successColor : AppTheme.dividerColor,
            width: uploaded ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: uploaded
                    ? AppTheme.successColor.withOpacity(0.1)
                    : AppTheme.lightGold,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                uploaded ? Icons.check_circle_outline : icon,
                color: uploaded ? AppTheme.successColor : AppTheme.primaryGold,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: uploaded ? AppTheme.successColor : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
              color: uploaded ? AppTheme.successColor : AppTheme.primaryGold,
            ),
          ],
        ),
      ),
    );
  }
}
