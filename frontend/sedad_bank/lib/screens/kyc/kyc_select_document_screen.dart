// ============================================================
// lib/screens/kyc/kyc_select_document_screen.dart
// Sélection du type de document : passeport / CNI / carte séjour
// ============================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';

class KycSelectDocumentScreen extends StatefulWidget {
  const KycSelectDocumentScreen({super.key});

  @override
  State<KycSelectDocumentScreen> createState() => _KycSelectDocumentScreenState();
}

class _KycSelectDocumentScreenState extends State<KycSelectDocumentScreen> {
  static const Color rssGreen = Color(0xFF0F6E4E);

  DocumentType? _selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header avec back + progress dots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  const Text(
                    'Sélectionner le document',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  _ProgressDots(activeIndex: 1, total: 4),
                ],
              ),
              const SizedBox(height: 28),

              const Text(
                'Choisissez votre type de document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sélectionnez le document que vous souhaitez utiliser pour la vérification.',
                style: TextStyle(color: Color(0xFF666666), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 28),

              _DocumentCard(
                icon: Icons.flight_outlined,
                title: 'Passeport',
                description: 'Document de voyage international',
                selected: _selected == DocumentType.passport,
                onTap: () => setState(() => _selected = DocumentType.passport),
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                icon: Icons.credit_card_outlined,
                title: 'Carte d\'identité nationale',
                description: 'Pièce d\'identité officielle',
                selected: _selected == DocumentType.nationalId,
                onTap: () => setState(() => _selected = DocumentType.nationalId),
              ),
              const SizedBox(height: 12),
              _DocumentCard(
                icon: Icons.home_outlined,
                title: 'Carte de séjour',
                description: 'Pour les résidents étrangers',
                selected: _selected == DocumentType.residenceCard,
                onTap: () => setState(() => _selected = DocumentType.residenceCard),
              ),

              const SizedBox(height: 24),
              const Text(
                'Assurez-vous que votre document est valide et non expiré.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF666666), fontSize: 12),
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selected == null
                      ? null
                      : () {
                          context.read<KycProvider>().selectDocumentType(_selected!);
                          context.push('/kyc/scan-recto');
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rssGreen,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Suivant',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
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
  final int activeIndex;  // 1-indexed
  final int total;
  const _ProgressDots({required this.activeIndex, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final isActive = i + 1 <= activeIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFFD0D5DD),
          ),
        );
      }),
    );
  }
}


class _DocumentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _DocumentCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  static const Color rssGreen = Color(0xFF0F6E4E);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? rssGreen : const Color(0xFFE5E7EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: rssGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}
