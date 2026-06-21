import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l    = AppLocalizations.of(context)!;

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

              Text(
                l.kycIntroTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                l.kycIntroSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.4),
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
                      children: [
                        Text(l.kycEstimatedTime,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(l.kycEstimatedTimeValue,
                            style: const TextStyle(
                                color: Color(0xFF666666), fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l.kycStepsTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              _StepRow(
                icon: Icons.description_outlined,
                title: l.kycStep1Title,
                subtitle: l.kycStep1Subtitle,
              ),
              _StepRow(
                icon: Icons.person_outline,
                title: l.kycStep2Title,
                subtitle: l.kycStep2Subtitle,
              ),
              _StepRow(
                icon: Icons.camera_alt_outlined,
                title: l.kycStep3Title,
                subtitle: l.kycStep3Subtitle,
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
                  children: [
                    const Icon(Icons.info_outline,
                        size: 18, color: Color(0xFF666666)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l.kycPrivacyNote,
                        style: const TextStyle(
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
                  child: Text(
                    l.kycStartVerification,
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                child: Text(
                  l.kycSkipForNow,
                  style: const TextStyle(color: Color(0xFF666666)),
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
    final l = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(l.kycSkipDialogTitle),
        content: Text(l.kycSkipDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.kycSkipConfirm),
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
