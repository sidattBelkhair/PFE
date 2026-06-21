// // ============================================================
// // lib/core/services/face_service.dart
// // Service pour Face Recognition Secure Service
// // URL : http://51.20.136.48:8000
// // Auth : OAuth2 password grant (username/password)
// // ============================================================

// import 'dart:io';
// import 'package:dio/dio.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// /// Résultat d'un enrôlement biométrique.
// /// Réponse réelle de l'API (testée) :
// /// {
// ///   "status": "success",
// ///   "user_id": "test-sidatt",
// ///   "liveness_score": 0.43271,
// ///   "quality_score": 0.8131
// /// }
// class FaceEnrollResult {
//   final String status;
//   final String? userId;
//   final double? livenessScore;
//   final double? qualityScore;
//   final Map<String, dynamic> raw;

//   FaceEnrollResult({
//     required this.status,
//     this.userId,
//     this.livenessScore,
//     this.qualityScore,
//     required this.raw,
//   });

//   factory FaceEnrollResult.fromJson(Map<String, dynamic> json) {
//     return FaceEnrollResult(
//       status: json['status']?.toString() ?? 'unknown',
//       userId: json['user_id']?.toString(),
//       livenessScore: _toDouble(json['liveness_score']),
//       qualityScore: _toDouble(json['quality_score']),
//       raw: json,
//     );
//   }

//   static double? _toDouble(dynamic v) {
//     if (v == null) return null;
//     if (v is num) return v.toDouble();
//     if (v is String) return double.tryParse(v);
//     return null;
//   }

//   bool get isSuccess => status.toLowerCase() == 'success';

//   /// Confidence globale = min(liveness, quality)
//   /// liveness < 0.5 = potentiel spoofing
//   /// quality < 0.5 = photo de mauvaise qualité
//   double get confidence {
//     final l = livenessScore ?? 0.0;
//     final q = qualityScore ?? 0.0;
//     return l < q ? l : q;
//   }
// }


// /// Résultat d'une vérification (verify).
// class FaceVerifyResult {
//   final bool match;
//   final double? confidence;
//   final String? userId;
//   final String? message;
//   final Map<String, dynamic> raw;

//   FaceVerifyResult({
//     required this.match,
//     this.confidence,
//     this.userId,
//     this.message,
//     required this.raw,
//   });

//   factory FaceVerifyResult.fromJson(dynamic data) {
//     if (data is Map) {
//       final map = data as Map<String, dynamic>;
//       final status = map['status']?.toString().toLowerCase() ?? '';
//       return FaceVerifyResult(
//         match: status == 'success' ||
//                status == 'match' ||
//                status == 'verified' ||
//                map['match'] == true ||
//                map['matched'] == true,
//         confidence: _toDouble(
//           map['confidence'] ?? map['score'] ?? map['similarity'] ?? map['match_score']
//         ),
//         userId: map['user_id']?.toString(),
//         message: map['message']?.toString() ?? map['detail']?.toString(),
//         raw: map,
//       );
//     }
//     return FaceVerifyResult(match: false, raw: {'response': data.toString()});
//   }

//   static double? _toDouble(dynamic v) {
//     if (v == null) return null;
//     if (v is num) return v.toDouble();
//     if (v is String) return double.tryParse(v);
//     return null;
//   }
// }


// class FaceService {
//   static const String apiKey =
//     'nova_key_3aa656e2bac2ea102ec2c56c196bcf6d';
//   static const String baseUrl = 'http://51.20.136.48:8000';

//   // ✅ Credentials TESTÉS et confirmés fonctionnels
//   // (À mettre dans un .env en production, ici en dur pour le PFE)
//   // static const String clientId = 'admin';
//   // static const String clientSecret = 'admin-secret';

//   // static const String _tokenKey = 'face_api_token';

//   late final Dio _dio;
  

//   // FaceService() {
//   //   _dio = Dio(BaseOptions(
//   //     baseUrl: baseUrl,
//   //     connectTimeout: const Duration(seconds: 20),
//   //     receiveTimeout: const Duration(seconds: 60),
//   //   ));

//   //   _dio.interceptors.add(InterceptorsWrapper(
//   //     onRequest: (options, handler) async {
//   //       // Skip auth header sur /token
//   //       if (!options.path.contains('/token')) {
//   //         final token = await _getCachedToken();
//   //         if (token != null && token.isNotEmpty) {
//   //           options.headers['Authorization'] = 'Bearer $token';
//   //         }
//   //       }
//   //       return handler.next(options);
//   //     },
//   //     onError: (error, handler) async {
//   //       // Retry une fois sur 401 avec un nouveau token
//   //       if (error.response?.statusCode == 401 &&
//   //           error.requestOptions.extra['retried'] != true) {
//   //         print('[FaceService] 401 → demande nouveau token...');
//   //         await _clearToken();
//   //         final newToken = await _requestNewToken();
//   //         if (newToken != null) {
//   //           error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
//   //           error.requestOptions.extra['retried'] = true;
//   //           try {
//   //             final response = await _dio.fetch(error.requestOptions);
//   //             return handler.resolve(response);
//   //           } catch (_) {}
//   //         }
//   //       }
//   //       return handler.next(error);
//   //     },
//   //   ));
//   // }
//       FaceService() {
//       _dio = Dio(BaseOptions(
//        baseUrl: baseUrl,
//        connectTimeout: const Duration(seconds: 20),
//        receiveTimeout: const Duration(seconds: 60),
//        headers: {
//        'Secure-Nova-Key': apiKey,
//       },
//    ));
//   } 

//   // ============================================================
//   // Token OAuth2
//   // ============================================================

//   // Future<String?> _getCachedToken() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   final token = prefs.getString(_tokenKey);
//   //   if (token != null && token.isNotEmpty) return token;
//   //   return await _requestNewToken();
//   // }

//   // Future<String?> _requestNewToken() async {
//   //   try {
//   //     // Format testé qui marche : multipart form
//   //     final formData = FormData.fromMap({
//   //       'grant_type': 'password',
//   //       'username': clientId,
//   //       'password': clientSecret,
//   //     });

//   //     final response = await _dio.post('/token', data: formData);

//   //     if (response.statusCode == 200) {
//   //       final data = response.data;
//   //       String? token;
//   //       if (data is Map) {
//   //         token = data['access_token']?.toString();
//   //       }
//   //       if (token != null && token.isNotEmpty) {
//   //         final prefs = await SharedPreferences.getInstance();
//   //         await prefs.setString(_tokenKey, token);
//   //         print('[FaceService] ✅ Token obtenu');
//   //         return token;
//   //       }
//   //     }
//   //   } on DioException catch (e) {
//   //     print('[FaceService] ❌ /token ${e.response?.statusCode}: ${e.response?.data}');
//   //   }
//   //   return null;
//   // }

//   // Future<void> _clearToken() async {
//   //   final prefs = await SharedPreferences.getInstance();
//   //   await prefs.remove(_tokenKey);
//   // }

//   // ============================================================
//   // Enrôlement
//   // ============================================================

//   /// Enregistre le visage d'un utilisateur. À appeler une fois.
//   Future<FaceEnrollResult?> enroll({
//     required String userId,
//     required File imageFile,
//     String? deviceId,
//   }) async {
//     try {
//       final formData = FormData.fromMap({
//         'user_id': userId,
//         'device_id': deviceId ?? 'flutter-rss-bank',
//         'file': await MultipartFile.fromFile(
//           imageFile.path,
//           filename: 'enroll.jpg',
//         ),
//       });

//       final response = await _dio.post('/face/enroll', data: formData);
//       print('[FaceService] Enroll: ${response.statusCode} ${response.data}');

//       if (response.statusCode == 200 && response.data is Map) {
//         return FaceEnrollResult.fromJson(response.data as Map<String, dynamic>);
//       }
//     } on DioException catch (e) {
//       print('[FaceService] ❌ Enroll error: ${e.response?.statusCode} ${e.response?.data}');
//     }
//     return null;
//   }

//   // ============================================================
//   // Vérification
//   // ============================================================

//   Future<FaceVerifyResult?> verify({
//     required String userId,
//     required File imageFile,
//   }) async {
//     try {
//       final formData = FormData.fromMap({
//         'user_id': userId,
//         'file': await MultipartFile.fromFile(
//           imageFile.path,
//           filename: 'verify.jpg',
//         ),
//       });

//       final response = await _dio.post('/face/verify', data: formData);
//       print('[FaceService] Verify: ${response.statusCode} ${response.data}');

//       if (response.statusCode == 200) {
//         return FaceVerifyResult.fromJson(response.data);
//       }
//     } on DioException catch (e) {
//       print('[FaceService] ❌ Verify error: ${e.response?.statusCode} ${e.response?.data}');
//       if (e.response?.statusCode == 404) {
//         return FaceVerifyResult(
//           match: false,
//           message: 'Utilisateur non enrôlé',
//           raw: {'error': 'not_enrolled'},
//         );
//       }
//     }
//     return null;
//   }

//   Future<void> clearToken() async => _clearToken();
// }
// ============================================================
// lib/core/services/face_service.dart
// VERSION CORRIGÉE
// ============================================================

import 'dart:io';
import 'package:dio/dio.dart';

// Verify API response shape:
// {
//   "status": "failed", "decision": "allow"/"deny",
//   "scores": { "similarity_score": 0.92, "liveness_score": 0.43, "confidence": 0.87 }
// }
class FaceVerifyResult {
  final bool match;
  final String? decision;
  final double? similarityScore;
  final double? livenessScore;
  final double? confidence;
  final String? userId;
  final String? message;
  final Map<String, dynamic> raw;

  FaceVerifyResult({
    required this.match,
    this.decision,
    this.similarityScore,
    this.livenessScore,
    this.confidence,
    this.userId,
    this.message,
    required this.raw,
  });

  factory FaceVerifyResult.fromJson(dynamic data) {
    if (data is Map) {
      final map = data as Map<String, dynamic>;
      final scores = (map['scores'] as Map<String, dynamic>?) ?? {};
      final decision = map['decision']?.toString().toLowerCase() ?? '';
      final status   = map['status']?.toString().toLowerCase() ?? '';

      return FaceVerifyResult(
        match: decision == 'allow' ||
            status == 'success' ||
            status == 'match' ||
            map['match'] == true,
        decision: map['decision']?.toString(),
        similarityScore: _toDouble(scores['similarity_score'] ?? map['similarity_score']),
        livenessScore:   _toDouble(scores['liveness_score']   ?? map['liveness_score']),
        confidence:      _toDouble(scores['confidence']        ?? map['confidence']),
        userId:  map['user_id']?.toString(),
        message: map['message']?.toString() ?? map['detail']?.toString(),
        raw: map,
      );
    }
    return FaceVerifyResult(match: false, raw: {'response': data.toString()});
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

class FaceService {
  static const String baseUrl = 'http://51.20.136.48:8000';

  static const String apiKey =
      'nova_key_3aa656e2bac2ea102ec2c56c196bcf6d';

  late final Dio _dio;

  FaceService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Secure-Nova-Key': apiKey,
        },
      ),
    );
  }

  // ============================================================
  // KYC VERIFY — comparaison 1:1 (pièce d'identité ↔ selfie) SANS enrollment
  // ni stockage permanent côté serveur (POST /kyc/verify, image1 + image2).
  // ============================================================

  Future<FaceVerifyResult?> kycVerify({
    required File idImage,
    required File selfieImage,
  }) async {
    try {
      final formData = FormData.fromMap({
        'image1': await MultipartFile.fromFile(
          idImage.path,
          filename: 'id.jpg',
        ),
        'image2': await MultipartFile.fromFile(
          selfieImage.path,
          filename: 'selfie.jpg',
        ),
      });

      final response = await _dio.post(
        '/kyc/verify',
        data: formData,
      );

      print('[FaceService] KycVerify => ${response.statusCode}');
      print(response.data);

      if (response.statusCode == 200) {
        final data = response.data is Map
            ? Map<String, dynamic>.from(response.data as Map)
            : response.data;
        return FaceVerifyResult.fromJson(data);
      }
    } on DioException catch (e) {
      print('[FaceService] KycVerify ERROR => ${e.response?.statusCode} ${e.response?.data}');
    }

    return null;
  }
}