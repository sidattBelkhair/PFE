import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';

class KycResultScreen extends StatelessWidget {
  const KycResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kyc    = context.watch<KycProvider>();
    final verify = kyc.verifyResult;

    final bool accepted  = verify?.match ?? false;
    final double sim     = verify?.similarityScore ?? verify?.confidence ?? 0.0;
    final String pct     = '${(sim * 100).toStringAsFixed(0)}%';
    final String decision = verify?.decision?.toUpperCase() ?? (accepted ? 'MATCH' : 'NO_MATCH');

    final Color primary  = accepted ? const Color(0xFF0F6E4E) : const Color(0xFFDC2626);
    final Color bgColor  = accepted ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2);
    final IconData icon  = accepted ? Icons.verified_user : Icons.cancel_outlined;
    final String title   = accepted ? 'Identité vérifiée' : 'Vérification échouée';
    final String subtitle = accepted
        ? 'Votre selfie correspond à votre CNI. Votre compte est maintenant actif.'
        : 'Votre selfie ne correspond pas à votre CNI. Vous pouvez réessayer ou contacter le support.';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),

              // ── Icône animée ────────────────────────────────────────────
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, __) => Transform.scale(
                  scale: v,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: Colors.white, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Titre ───────────────────────────────────────────────────
              Text(
                title,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primary),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 14, height: 1.5),
              ),

              const SizedBox(height: 32),

              // ── Carte résultat ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
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
                  children: [
                    // Score de similarité
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Similarité',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF777777))),
                        Text(
                          pct,
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: sim.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor: AlwaysStoppedAnimation(primary),
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(color: Color(0xFFF0F0F0)),
                    const SizedBox(height: 16),

                    // Décision
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Décision API',
                            style: TextStyle(
                                fontSize: 14, color: Color(0xFF777777))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: primary.withOpacity(0.3)),
                          ),
                          child: Text(
                            decision,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: primary),
                          ),
                        ),
                      ],
                    ),

                    // Liveness si disponible
                    if (verify?.livenessScore != null) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Liveness',
                              style: TextStyle(
                                  fontSize: 14, color: Color(0xFF777777))),
                          Text(
                            '${((verify!.livenessScore!) * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A)),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Bouton accueil ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Retour à l\'accueil',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              if (!accepted) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/kyc/face-verify'),
                  child: const Text(
                    'Réessayer avec un nouveau selfie',
                    style: TextStyle(color: Color(0xFF666666), fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
