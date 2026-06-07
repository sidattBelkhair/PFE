import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';
import '../../providers/language_provider.dart';

class KycConfirmInfoScreen extends StatefulWidget {
  const KycConfirmInfoScreen({super.key});

  @override
  State<KycConfirmInfoScreen> createState() => _KycConfirmInfoScreenState();
}

class _KycConfirmInfoScreenState extends State<KycConfirmInfoScreen> {
  static const Color rssGreen = Color(0xFF0F6E4E);

  Future<void> _confirm() async {
    final kyc = context.read<KycProvider>();
    if (!mounted) return;

    // Loader pendant enroll silencieux
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF0F6E4E)),
      ),
    );

    final ok = await kyc.enrollCniFace();
    if (!mounted) return;
    Navigator.of(context).pop(); // ferme loader

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kyc.errorMessage ?? 'Échec enrôlement CNI'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    kyc.confirmExtractedInfo();
    context.push('/kyc/face-verify');
  }

  @override
  Widget build(BuildContext context) {
    final kyc  = context.watch<KycProvider>();
    final isAr = context.watch<LanguageProvider>().isArabic;
    final ocr  = kyc.ocrResult;

    final title    = isAr ? 'تأكيد المعلومات'    : 'Confirmer vos informations';
    final heading  = isAr ? 'المعلومات المستخرجة' : 'Informations extraites';
    final sub      = isAr
        ? 'تحقق من أن هذه المعلومات تطابق وثيقتك'
        : 'Vérifiez que ces informations correspondent bien à votre document';
    final btnLabel = isAr ? 'تأكيد والمتابعة'    : 'Confirmer et continuer';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // ── header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BackButton(onTap: () => context.pop()),
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const _ProgressDots(activeIndex: 3, total: 4),
                ],
              ),
            ),

            // ── scrollable body ───────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(heading,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(sub,
                        style: const TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 13,
                            height: 1.4)),
                    const SizedBox(height: 14),

                    // confidence badge
                    if (ocr?.confidenceScore != null)
                      _ConfidenceBadge(
                          score: ocr!.confidenceScore!, isAr: isAr),

                    const SizedBox(height: 16),

                    if (ocr == null)
                      _EmptyCard(isAr: isAr)
                    else ...[
                      // ── IDENTITÉ ───────────────────────────────────────
                      _SectionLabel(
                          label: isAr ? 'الهوية' : 'IDENTITÉ'),
                      _InfoCard(children: [
                        _InfoRow(
                          label: isAr ? 'رقم الهوية الوطنية' : 'NNI',
                          value: ocr.identifier,
                          highlight: true,
                        ),
                        _InfoRow(
                          label: isAr ? 'اللقب' : 'Nom',
                          value: isAr
                              ? (ocr.lastNameArabic ?? ocr.lastNameLatin)
                              : (ocr.lastNameLatin  ?? ocr.lastNameArabic),
                          rtl: isAr,
                        ),
                        _InfoRow(
                          label: isAr ? 'الاسم' : 'Prénom',
                          value: isAr
                              ? (ocr.firstNameArabic ?? ocr.firstNameLatin)
                              : (ocr.firstNameLatin  ?? ocr.firstNameArabic),
                          rtl: isAr,
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 16),

                      // ── ÉTAT CIVIL ────────────────────────────────────
                      _SectionLabel(
                          label: isAr ? 'الحالة المدنية' : 'ÉTAT CIVIL'),
                      _InfoCard(children: [
                        _InfoRow(
                          label: isAr ? 'تاريخ الميلاد' : 'Date de naissance',
                          value: ocr.birthDate,
                        ),
                        _InfoRow(
                          label: isAr ? 'مكان الميلاد' : 'Lieu de naissance',
                          value: ocr.birthPlace,
                        ),
                        _InfoRow(
                          label: isAr ? 'الجنس' : 'Sexe',
                          value: _formatGender(ocr.gender, isAr),
                        ),
                        _InfoRow(
                          label: isAr ? 'الجنسية' : 'Nationalité',
                          value: ocr.nationality,
                        ),
                        _InfoRow(
                          label: isAr ? 'تاريخ الانتهاء' : 'Date d\'expiration',
                          value: ocr.expiryDate,
                          isLast: true,
                        ),
                      ]),

                      const SizedBox(height: 12),

                      // note bas
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: rssGreen.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: rssGreen.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                size: 15, color: rssGreen),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isAr
                                    ? 'إذا كانت المعلومات غير صحيحة، ارجع وأعد تصوير الوثيقة.'
                                    : 'Si des informations sont incorrectes, revenez en arrière et reprenez la photo.',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: rssGreen,
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── bouton confirmer ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (ocr == null || kyc.isLoading) ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rssGreen,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: Text(btnLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _formatGender(String? g, bool isAr) {
    if (g == null) return null;
    switch (g.toUpperCase()) {
      case 'M':
        return isAr ? 'ذكر (M)' : 'Masculin (M)';
      case 'F':
        return isAr ? 'أنثى (F)' : 'Féminin (F)';
      default:
        return g;
    }
  }
}

// ── sous-widgets ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF999999),
                  letterSpacing: 0.8)),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: Color(0xFFE5E7EB), height: 1),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String? value;
  final bool highlight;
  final bool rtl;
  final bool isLast;

  const _InfoRow({
    required this.label,
    this.value,
    this.highlight = false,
    this.rtl = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final display = (value != null && value!.isNotEmpty) ? value! : '—';
    final missing = display == '—';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF777777))),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  display,
                  textDirection:
                      rtl ? TextDirection.rtl : TextDirection.ltr,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        highlight ? FontWeight.bold : FontWeight.w500,
                    color: missing
                        ? const Color(0xFFBBBBBB)
                        : highlight
                            ? const Color(0xFF0F6E4E)
                            : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0xFFF0F0F0)),
      ],
    );
  }
}

class _ConfidenceBadge extends StatelessWidget {
  final double score;
  final bool isAr;
  const _ConfidenceBadge({required this.score, required this.isAr});

  @override
  Widget build(BuildContext context) {
    final pct   = (score * 100).toStringAsFixed(0);
    final good  = score >= 0.7;
    final color = good ? const Color(0xFF0F6E4E) : const Color(0xFFD97706);
    final bg    = good ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
    final label = isAr
        ? 'دقة الاستخراج : $pct%'
        : 'Confiance extraction : $pct%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              good
                  ? Icons.verified_outlined
                  : Icons.warning_amber_outlined,
              size: 14,
              color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final bool isAr;
  const _EmptyCard({required this.isAr});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(
          isAr
              ? 'لم يتم استخراج أي معلومات'
              : 'Aucune information extraite',
          style: const TextStyle(color: Color(0xFF999999)),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: const Icon(Icons.arrow_back_ios_new, size: 16),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final int activeIndex;
  final int total;
  const _ProgressDots({required this.activeIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i + 1 <= activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? const Color(0xFF0F6E4E)
                : const Color(0xFFD0D5DD),
          ),
        );
      }),
    );
  }
}
