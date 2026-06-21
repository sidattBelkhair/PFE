// // ============================================================
// // lib/core/services/ocr_service.dart
// // VERSION 3 - OCR intégré dans Face API
// // URL : http://51.20.136.48:8000/api/ocr
// // Auth : Bearer token (OAuth2 — mêmes credentials que Face Service)
// // Field : id_card (+ fallback file/image/document)
// // ============================================================

// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// class OcrResult {
//   final String? identifier;
//   final String? documentType;
//   final String? firstNameLatin;
//   final String? firstNameArabic;
//   final String? lastNameLatin;
//   final String? lastNameArabic;
//   final String? birthDate;
//   final String? birthPlace;
//   final String? gender;
//   final String? nationality;
//   final String? expiryDate;

//   final String status;
//   final double? confidenceScore;
//   final String? engineUsed;

//   final String? faceImageBase64;
//   final List<double>? faceEmbedding;

//   final String? verificationStatus;
//   final bool? databaseMatch;

//   final Map<String, dynamic> raw;

//   OcrResult({
//     this.identifier,
//     this.documentType,
//     this.firstNameLatin,
//     this.firstNameArabic,
//     this.lastNameLatin,
//     this.lastNameArabic,
//     this.birthDate,
//     this.birthPlace,
//     this.gender,
//     this.nationality,
//     this.expiryDate,
//     required this.status,
//     this.confidenceScore,
//     this.engineUsed,
//     this.faceImageBase64,
//     this.faceEmbedding,
//     this.verificationStatus,
//     this.databaseMatch,
//     required this.raw,
//   });

//   factory OcrResult.fromJson(Map<String, dynamic> json) {
//     final data = (json['data'] as Map<String, dynamic>?) ??
//                  (json['result'] as Map<String, dynamic>?) ??
//                  (json['extracted_data'] as Map<String, dynamic>?) ??
//                  json;

//     final verif = (json['verification_result'] as Map<String, dynamic>?) ?? {};
//     final biometric = (json['biometric'] as Map<String, dynamic>?) ??
//                       (json['face'] as Map<String, dynamic>?) ?? {};

//     return OcrResult(
//       identifier: _str(data['identifier']) ??
//                   _str(data['national_id']) ??
//                   _str(data['id_number']) ??
//                   _str(data['cni']) ??
//                   _str(data['nin']) ??
//                   _str(data['document_number']),

//       documentType: _str(data['document_type']) ?? _str(data['type']),

//       firstNameLatin: _str(data['first_name_fl']) ??
//                       _str(data['first_name']) ??
//                       _str(data['firstName']) ??
//                       _str(data['prenom']) ??
//                       _str(data['given_name']),

//       lastNameLatin: _str(data['last_name_fl']) ??
//                      _str(data['last_name']) ??
//                      _str(data['lastName']) ??
//                      _str(data['nom']) ??
//                      _str(data['surname']) ??
//                      _str(data['family_name']),

//       firstNameArabic: _str(data['first_name_ll']) ??
//                        _str(data['first_name_ar']) ??
//                        _str(data['prenom_ar']),

//       lastNameArabic: _str(data['last_name_ll']) ??
//                       _str(data['last_name_ar']) ??
//                       _str(data['nom_ar']),

//       birthDate: _str(data['birth_date']) ??
//                  _str(data['date_of_birth']) ??
//                  _str(data['dob']),

//       birthPlace: _str(data['birth_place']) ?? _str(data['place_of_birth']),
//       gender: _str(data['gender']) ?? _str(data['sex']),
//       nationality: _str(data['nationality']),
//       expiryDate: _str(data['expiry_date']) ?? _str(data['expires_at']),

//       status: _str(json['status']) ?? 'success',
//       confidenceScore: _toDouble(json['confidence_score']) ??
//                        _toDouble(json['confidence']),
//       engineUsed: _str(json['engine_used']) ?? _str(json['engine']),

//       faceImageBase64: _str(biometric['face_image']) ??
//                        _str(data['face_image']) ??
//                        _str(json['face_image']),
//       faceEmbedding: _toListDouble(biometric['embedding'] ?? data['embedding']),

//       verificationStatus: _str(verif['status']),
//       databaseMatch: verif['database_match'] as bool?,

//       raw: json,
//     );
//   }

//   static String? _str(dynamic v) {
//     if (v == null) return null;
//     final s = v.toString().trim();
//     return (s.isEmpty || s.toLowerCase() == 'null') ? null : s;
//   }

//   static double? _toDouble(dynamic v) {
//     if (v == null) return null;
//     if (v is num) return v.toDouble();
//     if (v is String) return double.tryParse(v);
//     return null;
//   }

//   static List<double>? _toListDouble(dynamic v) {
//     if (v is! List) return null;
//     try {
//       return v.map((e) => (e as num).toDouble()).toList();
//     } catch (_) {
//       return null;
//     }
//   }

//   // Getters compat utilisés par les screens KYC
//   String? get firstName => firstNameLatin ?? firstNameArabic;
//   String? get lastName  => lastNameLatin  ?? lastNameArabic;
//   String? get nationalId => identifier;

//   bool get isSuccess =>
//       status.toLowerCase() == 'success' ||
//       status.toLowerCase() == 'ok' ||
//       identifier != null ||
//       firstName != null;

//   bool get hasFaceImage =>
//       faceImageBase64 != null && faceImageBase64!.isNotEmpty;

//   String get fullName {
//     final f = firstName ?? '';
//     final l = lastName  ?? '';
//     return '$f $l'.trim();
//   }

//   String get documentTypeForBackend {
//     switch (documentType?.toLowerCase()) {
//       case 'id_card':
//       case 'cni':
//       case 'national_id': return 'cni';
//       case 'passport':    return 'passport';
//       case 'residence_card':
//       case 'residence':   return 'residence_card';
//       default:            return documentType ?? 'cni';
//     }
//   }
// }


// class OcrService {
//   static const String baseUrl        = 'http://51.20.136.48:8000';
//   static const String extractEndpoint = '/api/ocr';
//   static const String apiKey =
//     'nova_key_3aa656e2bac2ea102ec2c56c196bcf6d';

//   // static const String _tokenKey      = 'face_api_token';
//   // static const String clientId       = 'admin';
//   // static const String clientSecret   = 'admin-secret';

//   late final Dio _dio;

//  OcrService() {
//   _dio = Dio(BaseOptions(
//     baseUrl: baseUrl,
//     connectTimeout: const Duration(seconds: 30),
//     receiveTimeout: const Duration(seconds: 60),
//     headers: {
//       'Secure-Nova-Key': apiKey,
//     },
//   ));
// }
//   // Future<String?> _getCachedToken() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   final token = prefs.getString(_tokenKey);
//   //   if (token != null && token.isNotEmpty) return token;
//   //   return await _requestNewToken();
//   // }

//   // Future<String?> _requestNewToken() async {
//   //   try {
//   //     final formData = FormData.fromMap({
//   //       'grant_type': 'password',
//   //       'username': clientId,
//   //       'password': clientSecret,
//   //     });
//   //     final response = await _dio.post('/token', data: formData);
//   //     if (response.statusCode == 200 && response.data is Map) {
//   //       final token = response.data['access_token']?.toString();
//   //       if (token != null && token.isNotEmpty) {
//   //         final prefs = await SharedPreferences.getInstance();
//   //         await prefs.setString(_tokenKey, token);
//   //         print('[OCR] ✅ Token obtenu');
//   //         return token;
//   //       }
//   //     }
//   //   } on DioException catch (e) {
//   //     print('[OCR] ❌ /token ${e.response?.statusCode}: ${e.response?.data}');
//   //   }
//   //   return null;
//   // }

// //   Future<void> _clearToken() async {
// //     final prefs = await SharedPreferences.getInstance();
// //     await prefs.remove(_tokenKey);
// //   }

// //   Future<OcrResult?> extractFromDocument({
// //     required File imageFile,
// //     String? documentType,
// //   }) async {
// //     for (final fieldName in ['id_card', 'file', 'image', 'document']) {
// //       try {
// //         final formData = FormData.fromMap({
// //           fieldName: await MultipartFile.fromFile(
// //             imageFile.path,
// //             filename: 'document.jpg',
// //           ),
// //         });

// //         final response = await _dio.post(extractEndpoint, data: formData);

// //         print('[OCR] Status: ${response.statusCode} (field="$fieldName")');
// //         print('[OCR] Data: ${response.data}');

// //         if (response.statusCode == 200 && response.data is Map) {
// //           return OcrResult.fromJson(response.data as Map<String, dynamic>);
// //         }
// //       } on DioException catch (e) {
// //         final code = e.response?.statusCode;
// //         if (code == 422 || code == 400) {
// //           print('[OCR] Champ "$fieldName" rejeté ($code), essai suivant...');
// //           continue;
// //         }
// //         print('[OCR] ❌ Erreur $code: ${e.response?.data}');
// //         return null;
// //       }
// //     }
// //     return null;
// //   }
// // }
// ============================================================
// lib/core/services/ocr_service.dart
// VERSION CORRIGÉE
// ============================================================

import 'dart:io';
import 'package:dio/dio.dart';

class OcrResult {
  final String? identifier;
  final String? documentType;

  final String? firstNameLatin;
  final String? firstNameArabic;

  final String? lastNameLatin;
  final String? lastNameArabic;

  final String? birthDate;
  final String? birthPlace;

  final String? gender;
  final String? nationality;
  final String? expiryDate;

  final String status;

  final double? confidenceScore;
  final String? engineUsed;

  final String? faceImageBase64;
  final List<double>? faceEmbedding;

  final String? verificationStatus;
  final bool? databaseMatch;

  final Map<String, dynamic> raw;

  OcrResult({
    this.identifier,
    this.documentType,
    this.firstNameLatin,
    this.firstNameArabic,
    this.lastNameLatin,
    this.lastNameArabic,
    this.birthDate,
    this.birthPlace,
    this.gender,
    this.nationality,
    this.expiryDate,
    required this.status,
    this.confidenceScore,
    this.engineUsed,
    this.faceImageBase64,
    this.faceEmbedding,
    this.verificationStatus,
    this.databaseMatch,
    required this.raw,
  });

  factory OcrResult.fromJson(Map<String, dynamic> json) {
    final data =
        (json['data'] as Map<String, dynamic>?) ??
        (json['result'] as Map<String, dynamic>?) ??
        (json['extracted_data'] as Map<String, dynamic>?) ??
        json;

    final verif =
        (json['verification_result']
                as Map<String, dynamic>?) ??
            {};

    final biometric =
        (json['biometric']
                as Map<String, dynamic>?) ??
            (json['face']
                as Map<String, dynamic>?) ??
            {};

    return OcrResult(
      identifier:
          _str(data['identifier']) ??
          _str(data['national_id']) ??
          _str(data['id_number']) ??
          _str(data['cni']) ??
          _str(data['nin']) ??
          _str(data['document_number']),

      documentType:
          _str(data['document_type']) ??
          _str(data['type']),

      firstNameLatin:
          _str(data['first_name_fl']) ??
          _str(data['first_name']) ??
          _str(data['firstName']) ??
          _str(data['prenom']) ??
          _str(data['given_name']),

      lastNameLatin:
          _str(data['last_name_fl']) ??
          _str(data['last_name']) ??
          _str(data['lastName']) ??
          _str(data['nom']) ??
          _str(data['surname']) ??
          _str(data['family_name']),

      firstNameArabic:
          _str(data['first_name_ll']) ??
          _str(data['first_name_ar']) ??
          _str(data['prenom_ar']),

      lastNameArabic:
          _str(data['last_name_ll']) ??
          _str(data['last_name_ar']) ??
          _str(data['nom_ar']),

      birthDate:
          _str(data['birth_date']) ??
          _str(data['date_of_birth']) ??
          _str(data['dob']),

      birthPlace:
          _str(data['birth_place']) ??
          _str(data['place_of_birth']),

      gender:
          _str(data['gender']) ??
          _str(data['sex']),

      nationality:
          _str(data['nationality']),

      expiryDate:
          _str(data['expiry_date']) ??
          _str(data['expires_at']),

      status:
          _str(json['status']) ?? 'success',

      confidenceScore:
          _toDouble(json['confidence_score']) ??
          _toDouble(json['confidence']),

      engineUsed:
          _str(json['engine_used']) ??
          _str(json['engine']),

      faceImageBase64:
          _str(biometric['face_image']) ??
          _str(data['face_image']) ??
          _str(json['face_image']),

      faceEmbedding:
          _toListDouble(
            biometric['embedding'] ??
                data['embedding'],
          ),

      verificationStatus:
          _str(verif['status']),

      databaseMatch:
          verif['database_match'] as bool?,

      raw: json,
    );
  }

  static String? _str(dynamic v) {
    if (v == null) return null;

    final s = v.toString().trim();

    return (s.isEmpty || s.toLowerCase() == 'null')
        ? null
        : s;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;

    if (v is num) return v.toDouble();

    if (v is String) {
      return double.tryParse(v);
    }

    return null;
  }

  static List<double>? _toListDouble(dynamic v) {
    if (v is! List) return null;

    try {
      return v
          .map((e) => (e as num).toDouble())
          .toList();
    } catch (_) {
      return null;
    }
  }

  String? get firstName =>
      firstNameLatin ?? firstNameArabic;

  String? get lastName =>
      lastNameLatin ?? lastNameArabic;

  String? get nationalId => identifier;

  bool get isSuccess =>
      status.toLowerCase() == 'success' ||
      status.toLowerCase() == 'ok' ||
      identifier != null ||
      firstName != null;

  bool get hasFaceImage =>
      faceImageBase64 != null &&
      faceImageBase64!.isNotEmpty;

  String get fullName {
    final f = firstName ?? '';
    final l = lastName ?? '';

    return '$f $l'.trim();
  }

  String get documentTypeForBackend {
    switch (documentType?.toLowerCase()) {
      case 'id_card':
      case 'cni':
      case 'national_id':
        return 'cni';

      case 'passport':
        return 'passport';

      case 'residence_card':
      case 'residence':
        return 'residence_card';

      default:
        return documentType ?? 'cni';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OCR  →  Face Recognition Secure Service  :  http://51.20.136.48:8000
// Auth :  Secure-Nova-Key  (header — même service que FaceService)
// Endpoint : POST /api/ocr
// Field multipart : "id_card" (+ fallback file/image/document)
// ─────────────────────────────────────────────────────────────────────────────
class OcrService {
  static const String baseUrl = 'http://51.20.136.48:8000';

  static const String extractEndpoint = '/api/ocr';

  static const String apiKey =
      'nova_key_3aa656e2bac2ea102ec2c56c196bcf6d';

  late final Dio _dio;

  OcrService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Secure-Nova-Key': apiKey,
        },
      ),
    );
  }

  Future<OcrResult?> extractFromDocument({
    required File imageFile,
    String? documentType,
  }) async {
    for (final fieldName in ['id_card', 'file', 'image', 'document']) {
      try {
        final formData = FormData.fromMap({
          fieldName: await MultipartFile.fromFile(
            imageFile.path,
            filename: 'document.jpg',
          ),
        });

        final response = await _dio.post(extractEndpoint, data: formData);

        print('[OCR] => ${response.statusCode} (field="$fieldName")');
        print(response.data);

        if (response.statusCode == 200 &&
            response.data is Map<String, dynamic>) {
          return OcrResult.fromJson(response.data);
        }
      } on DioException catch (e) {
        final code = e.response?.statusCode;
        if (code == 422 || code == 400) {
          print('[OCR] Champ "$fieldName" rejeté ($code), essai suivant...');
          continue;
        }
        print('[OCR] ERROR => $code ${e.response?.data}');
        return null;
      }
    }

    return null;
  }
}
