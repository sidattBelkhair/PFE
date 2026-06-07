import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';

// Écran de debug KYC — à supprimer après la soutenance
class KycDebugScreen extends StatelessWidget {
  const KycDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final kyc    = context.watch<KycProvider>();
    final ocr    = kyc.ocrResult;
    final enroll = kyc.enrollResult;
    final verify = kyc.verifyResult;
    final b64    = ocr?.faceImageBase64;

    Widget faceWidget;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final clean = b64.contains(',') ? b64.split(',').last : b64;
        faceWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            base64Decode(clean),
            width: 160,
            height: 200,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        faceWidget = const Text('❌ Décodage base64 échoué',
            style: TextStyle(color: Colors.red));
      }
    } else {
      faceWidget = Container(
        width: 160,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
            child: Text('Aucun visage\nextrait',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text('DEBUG — KYC biométrique'),
        backgroundColor: const Color(0xFF0F6E4E),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── OCR ─────────────────────────────────────────────────────
            _Section(
              title: '1. OCR — Infos extraites',
              color: const Color(0xFF0F6E4E),
              rows: [
                _kv('NNI (user_id Face API)', ocr?.identifier),
                _kv('Prénom (Fr)', ocr?.firstNameLatin),
                _kv('Nom (Fr)',    ocr?.lastNameLatin),
                _kv('Prénom (Ar)', ocr?.firstNameArabic),
                _kv('Nom (Ar)',    ocr?.lastNameArabic),
                _kv('Naissance',   ocr?.birthDate),
                _kv('Sexe',        ocr?.gender),
                _kv('Nationalité', ocr?.nationality),
                _kv('Confiance OCR',
                    ocr?.confidenceScore != null
                        ? '${(ocr!.confidenceScore! * 100).toStringAsFixed(0)}%'
                        : null),
                _kv('face_base64 size',
                    b64 != null ? '${b64.length} chars' : 'ABSENT ❌'),
              ],
            ),

            const SizedBox(height: 16),

            // ── Visage CNI ───────────────────────────────────────────────
            _Section(
              title: '2. Visage extrait de la CNI',
              color: const Color(0xFF1E40AF),
              rows: const [],
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    faceWidget,
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Ce visage est utilisé pour\nl\'enrôlement.\n\n'
                        'Il doit correspondre à\nla photo sur la CNI.',
                        style: TextStyle(
                            fontSize: 13, color: Color(0xFF555555)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Enroll ───────────────────────────────────────────────────
            _Section(
              title: '3. Enroll — POST /face/enroll',
              color: const Color(0xFF7C3AED),
              rows: [
                _kv('user_id envoyé', ocr?.identifier),
                _kv('Status',         enroll?.status),
                _kv('Déjà enrôlé',    enroll?.alreadyEnrolled.toString()),
                _kv('Liveness score',
                    enroll?.livenessScore != null
                        ? '${(enroll!.livenessScore! * 100).toStringAsFixed(0)}%'
                        : null),
                _kv('Quality score',
                    enroll?.qualityScore != null
                        ? '${(enroll!.qualityScore! * 100).toStringAsFixed(0)}%'
                        : null),
              ],
            ),

            const SizedBox(height: 16),

            // ── Verify ───────────────────────────────────────────────────
            _Section(
              title: '4. Verify — POST /face/verify',
              color: const Color(0xFFB45309),
              rows: [
                _kv('user_id envoyé',   ocr?.identifier),
                _kv('Match',            verify?.match.toString()),
                _kv('Decision',         verify?.decision),
                _kv('Similarité',
                    verify?.similarityScore != null
                        ? '${(verify!.similarityScore! * 100).toStringAsFixed(0)}%'
                        : null),
                _kv('Liveness (verify)',
                    verify?.livenessScore != null
                        ? '${(verify!.livenessScore! * 100).toStringAsFixed(0)}%'
                        : null),
              ],
            ),

            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                '⚠️  Cet écran est réservé au développement.\nSupprimer kyc_debug_screen.dart avant la mise en production.',
                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String?> _kv(String k, String? v) => {k: v};
}

class _Section extends StatelessWidget {
  final String title;
  final Color color;
  final List<Map<String, String?>> rows;
  final Widget? child;

  const _Section({
    required this.title,
    required this.color,
    required this.rows,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: color)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...rows.map((m) {
                  final k = m.keys.first;
                  final v = m.values.first;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 140,
                          child: Text(k,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF777777))),
                        ),
                        Expanded(
                          child: Text(
                            v ?? '—',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: v != null
                                  ? const Color(0xFF1A1A1A)
                                  : const Color(0xFFBBBBBB),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (child != null) child!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
