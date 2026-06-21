import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';
import '../../widgets/camera_capture_screen.dart';

class KycFaceVerifyScreen extends StatefulWidget {
  const KycFaceVerifyScreen({super.key});

  @override
  State<KycFaceVerifyScreen> createState() => _KycFaceVerifyScreenState();
}

class _KycFaceVerifyScreenState extends State<KycFaceVerifyScreen> {
  static const Color rssGreen = Color(0xFF0F6E4E);

  Future<void> _takeSelfie() async {
    final l = AppLocalizations.of(context)!;
    try {
      final file = await openCameraCapture(
        context,
        title: l.selfieVerificationTitle,
        preferFrontCamera: true,
      );
      if (file != null && mounted) {
        context.read<KycProvider>().setFaceImage(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.cameraError(e.toString()))),
        );
      }
    }
  }

  Future<void> _submit() async {
    final kyc = context.read<KycProvider>();
    final l = AppLocalizations.of(context)!;

    final gotResponse = await kyc.submitFaceVerification();
    if (!mounted) return;

    if (!gotResponse) {
      // Erreur réseau pure (pas de réponse du serveur)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kyc.errorMessage ?? l.networkError),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    // On a un résultat (match ou non) → envoyer au backend puis afficher la page résultat
    if (kyc.verifyResult?.match == true) {
      await kyc.submitKycToBackend();
      if (!mounted) return;
    }
    context.go('/kyc/result');
  }

  @override
  Widget build(BuildContext context) {
    final kyc   = context.watch<KycProvider>();
    final image = kyc.faceImage;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BackButton(onTap: () => context.pop()),
                  Text(l.faceVerifyHeaderTitle,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const _ProgressDots(activeIndex: 4, total: 4),
                ],
              ),
              const SizedBox(height: 28),

              Text(l.faceVerifyHeading,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                l.faceVerifySubtitle,
                style: const TextStyle(
                    color: Color(0xFF666666), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _takeSelfie,
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: image == null
                              ? const Color(0xFFE5E7EB)
                              : rssGreen,
                          width: image == null ? 2 : 4,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: image == null
                          ? Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color:
                                        rssGreen.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(36),
                                  ),
                                  child: const Icon(
                                    Icons.face_outlined,
                                    color: rssGreen,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l.tapToTakeSelfie,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : ClipOval(
                              child: Image.file(image,
                                  fit: BoxFit.cover),
                            ),
                    ),
                  ),
                ),
              ),

              if (image != null && !kyc.isLoading) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _Check(l.checkFaceCentered),
                      _Check(l.checkGoodLighting),
                      _Check(l.checkNoGlassesMask),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      image == null || kyc.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rssGreen,
                    disabledBackgroundColor:
                        const Color(0xFFCCCCCC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: kyc.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          image == null
                              ? l.takeSelfieButton
                              : l.validateIdentityButton,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              if (image != null)
                TextButton(
                  onPressed: kyc.isLoading ? null : _takeSelfie,
                  child: Text(
                    l.retake,
                    style: const TextStyle(color: Color(0xFF666666)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


class _Check extends StatelessWidget {
  final String label;
  const _Check(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle,
              size: 18, color: Color(0xFF0F6E4E)),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 13))),
        ],
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
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFD0D5DD),
          ),
        );
      }),
    );
  }
}
