import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';

class KycSuccessScreen extends StatelessWidget {
  const KycSuccessScreen({super.key});

  static const Color rssGreen = Color(0xFF0F6E4E);

  @override
  Widget build(BuildContext context) {
    final kyc    = context.watch<KycProvider>();
    final enroll = kyc.enrollResult;
    final verify = kyc.verifyResult;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),

              // ── animation succès ────────────────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (ctx, value, _) => Transform.scale(
                  scale: value,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: rssGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: rssGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 44,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              const Text(
                'Vérification réussie !',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Votre identité a été vérifiée avec succès. Toutes les fonctionnalités de votre compte sont maintenant disponibles.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0xFF666666), fontSize: 14, height: 1.5),
              ),

              const SizedBox(height: 28),

              // ── scores biométriques ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 8,
                        offset: Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résultats biométriques',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF444444)),
                    ),
                    const SizedBox(height: 14),

                    // ── Enroll scores ────────────────────────────────────
                    if (enroll != null) ...[
                      _ScoreRow(
                        label: enroll.alreadyEnrolled
                            ? 'Enrôlement'
                            : 'Liveness (anti-spoofing)',
                        value: enroll.alreadyEnrolled
                            ? null
                            : enroll.livenessScore,
                        badge: enroll.alreadyEnrolled
                            ? 'Déjà enrôlé'
                            : null,
                        badgeColor: rssGreen,
                        threshold: 0.3,
                      ),
                      if (!enroll.alreadyEnrolled)
                        _ScoreRow(
                          label: 'Qualité photo',
                          value: enroll.qualityScore,
                          threshold: 0.5,
                        ),
                    ],

                    // ── Verify scores ────────────────────────────────────
                    if (verify != null) ...[
                      const Divider(height: 20, color: Color(0xFFF0F0F0)),
                      _ScoreRow(
                        label: 'Similarité visage',
                        value: verify.similarityScore,
                        threshold: 0.75,
                      ),
                      _ScoreRow(
                        label: 'Liveness (vérif.)',
                        value: verify.livenessScore,
                        threshold: 0.2,
                      ),
                      _ScoreRow(
                        label: 'Décision',
                        value: null,
                        badge: verify.decision ?? '—',
                        badgeColor: verify.match
                            ? rssGreen
                            : const Color(0xFFD97706),
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(flex: 2),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rssGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Accéder à mon compte',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => context.push('/kyc/debug'),
                icon: const Icon(Icons.bug_report_outlined,
                    size: 16, color: Color(0xFF999999)),
                label: const Text(
                  'Voir les détails techniques (debug)',
                  style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double? value;
  final String? badge;
  final Color badgeColor;
  final double threshold;

  const _ScoreRow({
    required this.label,
    this.value,
    this.badge,
    this.badgeColor = const Color(0xFF0F6E4E),
    this.threshold = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final pct = value != null ? (value! * 100).toStringAsFixed(0) : null;
    final good = value == null ? true : value! >= threshold;
    final barColor =
        good ? const Color(0xFF0F6E4E) : const Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF777777))),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(badge!,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: badgeColor)),
                )
              else if (pct != null)
                Text('$pct%',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: barColor)),
            ],
          ),
          if (value != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value!.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
