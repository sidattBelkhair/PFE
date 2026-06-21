// ============================================================
// lib/widgets/camera_capture_screen.dart
// Écran générique de prise de photo via caméra (mobile + desktop)
// Retourne un File (chemin de la photo) via Navigator.pop
// ============================================================

import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Ouvre l'écran caméra et retourne le fichier capturé, ou null si annulé.
Future<File?> openCameraCapture(
  BuildContext context, {
  String title = 'Prendre une photo',
  bool preferFrontCamera = false,
}) {
  return Navigator.of(context).push<File>(
    MaterialPageRoute(
      builder: (_) => CameraCaptureScreen(
        title: title,
        preferFrontCamera: preferFrontCamera,
      ),
    ),
  );
}

class CameraCaptureScreen extends StatefulWidget {
  final String title;
  final bool preferFrontCamera;

  const CameraCaptureScreen({
    super.key,
    this.title = 'Prendre une photo',
    this.preferFrontCamera = false,
  });

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;
  bool _capturing = false;
  bool _useGalleryFallback = false;

  @override
  void initState() {
    super.initState();
    _initFuture = _initCamera();
  }

  /// Sur Linux desktop, le package `camera` n'a pas d'implémentation native :
  /// on bascule sur la galerie / sélecteur de fichier pour pouvoir tester le flow.
  Future<void> _pickFromGalleryFallback() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (image != null) {
      Navigator.of(context).pop(File(image.path));
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initCamera() async {
    if (!kIsWeb && Platform.isLinux) {
      setState(() => _useGalleryFallback = true);
      return;
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Aucune caméra détectée sur cet appareil.');
        return;
      }

      CameraDescription selected = cameras.first;
      if (widget.preferFrontCamera) {
        selected = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      } else {
        selected = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = 'Erreur caméra : $e');
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || _capturing) return;
    setState(() => _capturing = true);
    try {
      final picture = await controller.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(picture.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la capture : $e')),
      );
      setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_useGalleryFallback) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined,
                        color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Caméra non disponible sur ce poste.\nChoisissez une image depuis le système.',
                      style: TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _pickFromGalleryFallback,
                      child: const Text('Choisir une image'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final controller = _controller;
          if (controller == null || !controller.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Center(child: CameraPreview(controller)),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: _capturing ? null : _capture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: Colors.white24, width: 4),
                      ),
                      child: _capturing
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
