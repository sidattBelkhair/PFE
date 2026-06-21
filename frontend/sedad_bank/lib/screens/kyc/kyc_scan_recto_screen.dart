// ============================================================
// lib/screens/kyc/kyc_scan_recto_screen.dart
// Capture du recto du document via caméra ou galerie
// ============================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/kyc_provider.dart';
import '../../widgets/camera_capture_screen.dart';

class KycScanRectoScreen extends StatefulWidget {
  const KycScanRectoScreen({super.key});

  @override
  State<KycScanRectoScreen> createState() => _KycScanRectoScreenState();
}

class _KycScanRectoScreenState extends State<KycScanRectoScreen> {
  static const Color rssGreen = Color(0xFF0F6E4E);
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final file = await openCameraCapture(context, title: 'Photo du document');
        if (file != null && mounted) {
          context.read<KycProvider>().setDocumentImage(file);
        }
        return;
      }
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (image != null) {
        context.read<KycProvider>().setDocumentImage(File(image.path));
      }
    } catch (e) {
      if (mounted) {
        final l = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.errorWithDetail(e.toString()))),
        );
      }
    }
  }

  Future<void> _showImageSourceDialog() async {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.chooseSource,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: rssGreen),
                title: Text(l.takePhoto),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: rssGreen),
                title: Text(l.fromGallery),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final kyc = context.read<KycProvider>();
    final success = await kyc.submitDocumentToOcr();
    if (!mounted) return;

    if (success) {
      context.push('/kyc/confirm-info');
    } else {
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(kyc.errorMessage ?? l.ocrError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final kyc = context.watch<KycProvider>();
    final image = kyc.documentImage;
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BackButton(onTap: () => Navigator.of(context).pop()),
                  Text(l.kycScanRectoTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  _ProgressDots(activeIndex: 2, total: 4),
                ],
              ),
              const SizedBox(height: 28),

              Text(
                l.kycCheckPhotoHeading,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                l.kycCheckPhotoSubtitle,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),

              // Zone image
              Expanded(
                child: GestureDetector(
                  onTap: _showImageSourceDialog,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: image == null
                            ? const Color(0xFFE5E7EB)
                            : rssGreen,
                        width: image == null ? 1 : 2,
                      ),
                    ),
                    child: image == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: rssGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.add_a_photo_outlined,
                                    color: rssGreen, size: 32),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l.tapToTakePhoto,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l.orChooseFromGallery,
                                style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                              ),
                            ],
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.file(image, fit: BoxFit.cover),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (image != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _Check(l.checkTextReadable),
                      _Check(l.checkNoGlare),
                      _Check(l.checkCornersVisible),
                      _Check(l.checkImageSharp),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: image == null || kyc.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: rssGreen,
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: kyc.isLoading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(
                          l.perfectButton,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              if (image != null)
                TextButton(
                  onPressed: kyc.isLoading
                      ? null
                      : () => context.read<KycProvider>().setDocumentImage(File('')),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF0F6E4E)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
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
        width: 40, height: 40,
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
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? const Color(0xFF1A1A1A) : const Color(0xFFD0D5DD),
          ),
        );
      }),
    );
  }
}
