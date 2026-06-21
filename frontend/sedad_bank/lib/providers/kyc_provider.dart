// ============================================================
// lib/providers/kyc_provider.dart
// State machine du flow KYC adaptée aux vrais formats d'API
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/ocr_service.dart';
import '../core/services/face_service.dart';
import '../core/services/api_service.dart';

enum DocumentType { passport, nationalId, residenceCard }

extension DocumentTypeX on DocumentType {
  String get apiValue {
    switch (this) {
      case DocumentType.passport: return 'passport';
      case DocumentType.nationalId: return 'id_card';      // ← format API OCR
      case DocumentType.residenceCard: return 'residence_card';
    }
  }
  String get backendValue {
    switch (this) {
      case DocumentType.passport: return 'passport';
      case DocumentType.nationalId: return 'cni';
      case DocumentType.residenceCard: return 'residence_card';
    }
  }
  String get label {
    switch (this) {
      case DocumentType.passport: return 'Passeport';
      case DocumentType.nationalId: return 'Carte d\'identité nationale';
      case DocumentType.residenceCard: return 'Carte de séjour';
    }
  }
  String get description {
    switch (this) {
      case DocumentType.passport: return 'Document de voyage international';
      case DocumentType.nationalId: return 'Pièce d\'identité officielle';
      case DocumentType.residenceCard: return 'Pour les résidents étrangers';
    }
  }
}

enum KycStep { intro, selectDocument, scanRecto, confirmInfo, faceVerify, done }


class KycProvider extends ChangeNotifier {
  final OcrService _ocrService = OcrService();
  final FaceService _faceService = FaceService();
  final ApiService _apiService;

  KycProvider(this._apiService);

  // === State ===
  KycStep _currentStep = KycStep.intro;
  DocumentType? _documentType;
  File? _documentImage;
  OcrResult? _ocrResult;
  File? _idFaceImage;
  File? _faceImage;
  FaceVerifyResult? _verifyResult;
  bool _isLoading = false;
  String? _errorMessage;

  // Champs éditables après OCR
  String? editedFirstName;
  String? editedLastName;
  String? editedNationalId;
  String? editedBirthDate;

  // === Getters ===
  KycStep get currentStep => _currentStep;
  DocumentType? get documentType => _documentType;
  File? get documentImage => _documentImage;
  OcrResult? get ocrResult => _ocrResult;
  File? get faceImage => _faceImage;
  FaceVerifyResult? get verifyResult => _verifyResult;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // === Actions ===

  void selectDocumentType(DocumentType type) {
    _documentType = type;
    _currentStep = KycStep.scanRecto;
    notifyListeners();
  }

  void setDocumentImage(File image) {
    _documentImage = image;
    notifyListeners();
  }

  /// Étape 1 → 2 : OCR
  Future<bool> submitDocumentToOcr() async {
    if (_documentImage == null) {
      _errorMessage = 'Aucune image de document';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final result = await _ocrService.extractFromDocument(
        imageFile: _documentImage!,
        documentType: _documentType?.apiValue,
      );

      if (result == null || !result.isSuccess) {
        _errorMessage = 'Impossible d\'extraire les informations. Vérifiez que la photo est nette et bien éclairée, puis réessayez.';
        return false;
      }

      // Bloquer si aucune information utile extraite
      if (result.identifier == null &&
          result.firstNameLatin == null &&
          result.firstNameArabic == null &&
          result.lastNameLatin == null &&
          result.lastNameArabic == null) {
        _errorMessage =
            'Aucune information lisible. Prenez une photo nette de votre CNI, bien cadrée et éclairée.';
        return false;
      }

      _ocrResult = result;

      // Pré-remplir les champs éditables avec les données extraites
      // (préférer le latin, qui s'affiche mieux dans Flutter)
      editedFirstName = result.firstNameLatin ?? result.firstNameArabic;
      editedLastName = result.lastNameLatin ?? result.lastNameArabic;
      editedNationalId = result.identifier;
      editedBirthDate = result.birthDate;

      _currentStep = KycStep.confirmInfo;
      _errorMessage = null;
      return true;
    } finally {
      _setLoading(false);
    }
  }

  void setFaceImage(File image) {
    _faceImage = image;
    notifyListeners();
  }

  // ── ÉTAPE 2 : Préparation de la vérification faciale ───────────────────────
  // Appelé depuis l'écran "Confirmer infos" quand l'user clique "Confirmer".
  // Plus d'enrôlement biométrique permanent côté serveur (évite le stockage
  // durable de données personnelles non nécessaire) : on prépare juste l'image
  // de référence (visage CNI) qui sera comparée au selfie via /kyc/verify,
  // un endpoint de comparaison 1:1 sans enrollment.
  // Priorité : faceImageBase64 (crop visage par OCR) → fallback : photo CNI entière
  Future<bool> prepareFaceVerification() async {
    final nni = _ocrResult?.identifier;
    if (nni == null || nni.isEmpty) {
      _errorMessage = 'Numéro de CNI introuvable. Reprenez la photo.';
      notifyListeners();
      return false;
    }

    // Choisir l'image de référence : visage cropé ou CNI complète (fallback)
    File? idFaceFile;
    final b64 = _ocrResult?.faceImageBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final clean = b64.contains(',') ? b64.split(',').last : b64;
        final bytes = base64Decode(clean);
        final tmp = await getTemporaryDirectory();
        final f = File('${tmp.path}/cni_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await f.writeAsBytes(bytes);
        idFaceFile = f;
        print('[KYC] Référence → visage cropé par OCR (${bytes.length} bytes)');
      } catch (_) {
        idFaceFile = null;
      }
    }
    // Fallback : photo CNI originale (le serveur détecte lui-même le visage)
    idFaceFile ??= _documentImage;
    if (idFaceFile == null) {
      _errorMessage = 'Aucune image disponible pour la vérification.';
      notifyListeners();
      return false;
    }

    _idFaceImage = idFaceFile;
    _errorMessage = null;

    // Sauvegarde locale (pas côté serveur) du visage + NNI, pour permettre
    // plus tard l'activation optionnelle de "Connect avec Face" depuis le profil.
    await _persistFaceLoginData(nni, idFaceFile);

    _currentStep = KycStep.faceVerify;
    notifyListeners();
    return true;
  }

  // ── ÉTAPE 3 : Verify (selfie ↔ visage CNI), sans enrollment ────────────────
  Future<bool> submitFaceVerification() async {
    if (_faceImage == null) {
      _errorMessage = 'Aucun selfie capturé';
      notifyListeners();
      return false;
    }

    if (_idFaceImage == null) {
      _errorMessage = 'Image de référence manquante. Reprenez la vérification.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final result = await _faceService.kycVerify(
        idImage: _idFaceImage!,
        selfieImage: _faceImage!,
      );

      if (result == null) {
        _errorMessage = 'Erreur de communication avec le service biométrique';
        return false;
      }

      _verifyResult = result;
      final sim = result.similarityScore ?? result.confidence ?? 0.0;
      print('[KYC] kyc/verify => match=${result.match} '
            'similarity=$sim decision=${result.decision}');

      // Marquer KYC complété seulement si match
      if (result.match) {
        _currentStep = KycStep.done;
        await _markKycCompleted(_ocrResult?.identifier ?? '');
      }
      _errorMessage = null;
      return true; // toujours naviguer vers la page résultat
    } finally {
      _setLoading(false);
    }
  }

  /// Envoie le KYC validé au backend Django (persistance serveur)
  Future<bool> submitKycToBackend() async {
    try {
      final sim = _verifyResult?.similarityScore
                ?? _verifyResult?.confidence
                ?? 0.0;
      await _apiService.post('/users/complete-kyc/', data: {
        'document_type':        _documentType?.backendValue,
        'national_id':          editedNationalId ?? _ocrResult?.identifier,
        'extracted_first_name': editedFirstName  ?? _ocrResult?.firstNameLatin,
        'extracted_last_name':  editedLastName   ?? _ocrResult?.lastNameLatin,
        'birth_date':           editedBirthDate  ?? _ocrResult?.birthDate,
        'face_match_confidence': sim,
        'liveness_score':        _verifyResult?.livenessScore ?? 0.0,
        'similarity_score':      _verifyResult?.similarityScore ?? 0.0,
        'ocr_engine':            _ocrResult?.engineUsed,
        'ocr_confidence':        _ocrResult?.confidenceScore,
      });
      return true;
    } catch (e) {
      print('[KYC] Backend submission failed (non bloquant): $e');
      return false;
    }
  }

  /// Sauvegarde le visage enrôlé (CNI/passeport) + le NNI de façon durable,
  /// pour permettre le bouton "Connect avec Face" depuis le profil.
  Future<void> _persistFaceLoginData(String nni, File enrollFile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dest = File('${dir.path}/face_login_enroll.jpg');
      await dest.writeAsBytes(await enrollFile.readAsBytes());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('face_login_nni', nni);
      await prefs.setString('face_login_image_path', dest.path);
    } catch (e) {
      print('[KYC] Persist face-login data failed (non bloquant): $e');
    }
  }

  Future<void> _markKycCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kyc_completed_$userId', true);
    await prefs.setString(
      'kyc_completed_at_$userId',
      DateTime.now().toIso8601String(),
    );
  }

  static Future<bool> isKycCompleted(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('kyc_completed_$userId') ?? false;
  }

  Future<void> skip(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kyc_skipped_$userId', true);
    await prefs.setString(
      'kyc_skipped_at_$userId',
      DateTime.now().toIso8601String(),
    );
    notifyListeners();
  }

  static Future<bool> hasSkipped(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('kyc_skipped_$userId') ?? false;
  }

  void reset() {
    _currentStep = KycStep.intro;
    _documentType = null;
    _documentImage = null;
    _ocrResult = null;
    _idFaceImage = null;
    _faceImage = null;
    _verifyResult = null;
    _errorMessage = null;
    editedFirstName = null;
    editedLastName = null;
    editedNationalId = null;
    editedBirthDate = null;
    notifyListeners();
  }

  void goBack() {
    switch (_currentStep) {
      case KycStep.selectDocument: _currentStep = KycStep.intro; break;
      case KycStep.scanRecto: _currentStep = KycStep.selectDocument; break;
      case KycStep.confirmInfo: _currentStep = KycStep.scanRecto; break;
      case KycStep.faceVerify: _currentStep = KycStep.confirmInfo; break;
      default: break;
    }
    notifyListeners();
  }

  void goToSelectDocument() {
    _currentStep = KycStep.selectDocument;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}