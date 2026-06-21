import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/services/api_service.dart';
import '../core/services/sso_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final SSOService _ssoService = SSOService();

  UserModel? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  bool _sessionLoaded = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;
  bool get sessionLoaded => _sessionLoaded;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get isStaff => _currentUser?.role == 'agent';

  /// Extrait un message d'erreur lisible depuis la réponse DRF
  String _extractError(DioException e, String fallback) {
    // Erreurs réseau / timeout
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Délai de connexion dépassé. Vérifiez votre connexion internet.';
      case DioExceptionType.connectionError:
        return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
      default:
        break;
    }

    final data = e.response?.data;
    final code = e.response?.statusCode;

    if (data == null) return '$fallback (HTTP $code)';
    if (data is String && data.isNotEmpty) return data;
    if (data is Map) {
      if (data.containsKey('non_field_errors')) {
        final errors = data['non_field_errors'];
        if (errors is List && errors.isNotEmpty) return errors.first.toString();
      }
      if (data.containsKey('detail')) return data['detail'].toString();
      if (data.containsKey('error'))  return data['error'].toString();
      if (data.containsKey('message')) return data['message'].toString();
      final firstKey = data.keys.first;
      final val = data[firstKey];
      if (val is List && val.isNotEmpty) return '${firstKey}: ${val.first}';
      return data.toString();
    }
    return '$fallback (HTTP $code)';
  }

  /// Restaure la session depuis SharedPreferences au démarrage de l'app
  Future<void> loadSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');
      final refresh = prefs.getString('refresh_token');

      if (token != null) {
        _accessToken = token;
        _refreshToken = refresh;

        final response = await _apiService.get('users/me/');
        if (response.statusCode == 200) {
          _currentUser = UserModel.fromJson(response.data);
        } else {
          await _clearSession(prefs);
        }
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final refreshed = await refreshToken();
        if (!refreshed) {
          final prefs = await SharedPreferences.getInstance();
          await _clearSession(prefs);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await _clearSession(prefs);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await _clearSession(prefs);
    }

    _sessionLoaded = true;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _clearSession(SharedPreferences prefs) async {
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('logged_via_sso');
    // 'user_id' et les clés 'face_login_*' sont conservées : elles permettent
    // de proposer la connexion par visage sur l'écran de login après déconnexion.
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
  }

  Future<bool> register({
    required String email,
    required String password,
    required String passwordConfirm,
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        'auth/register/',
        data: {
          'email': email.trim(),
          'password': password,
          'password_confirm': passwordConfirm,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone_number': phoneNumber.trim(),
        },
      );

      if (response.statusCode == 201) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Erreur lors de l\'inscription');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        'auth/login/',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access'];
        _refreshToken = data['refresh'];
        _currentUser = UserModel.fromJson(data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('user_id', _currentUser!.id);

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Erreur lors de la connexion');
    } catch (e) {
      _errorMessage = 'Erreur inattendue : $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// ─── CONNEXION VIA SSO ──────────────────────────────────────────
  // Future<bool> loginWithSSO() async {
  //   _isLoading = true;
  //   _errorMessage = null;
  //   notifyListeners();

  //   try {
  //     // 1. Lancer le flow SSO PKCE
  //     await _ssoService.login();
  //     if (ssoResult == null) {
  //       _errorMessage = 'Connexion SSO annulée ou échouée';
  //       _isLoading = false;
  //       notifyListeners();
  //       return false;
  //     }

  //     final ssoAccessToken = ssoResult['access_token'] as String?;
  //     if (ssoAccessToken == null) {
  //       _errorMessage = 'Token SSO manquant';
  //       _isLoading = false;
  //       notifyListeners();
  //       return false;
  //     }

      // 2. Envoyer le token au backend RSS Bank
  //     final response = await _apiService.post(
  //       'auth/sso-login/',
  //       data: {'sso_access_token': ssoAccessToken},
  //     );

  //     if (response.statusCode == 200) {
  //       final data = response.data;
  //       _accessToken = data['access'];
  //       _refreshToken = data['refresh'];
  //       _currentUser = UserModel.fromJson(data['user']);

  //       final prefs = await SharedPreferences.getInstance();
  //       await prefs.setString('access_token', _accessToken!);
  //       await prefs.setString('refresh_token', _refreshToken!);
  //       await prefs.setString('user_id', _currentUser!.id);
  //       await prefs.setBool('logged_via_sso', true);

  //       _isLoading = false;
  //       notifyListeners();
  //       return true;
  //     }
  //   } catch (e) {
  //     _errorMessage = e.toString();
  //   } on DioException catch (e) {
  //     _errorMessage = _extractError(e, 'Erreur connexion SSO');
  //   } catch (e) {
  //     _errorMessage = 'Erreur SSO: $e';
  //   }

  //   _isLoading = false;
  //   notifyListeners();
  //   return false;
  // }
  Future<bool> loginWithSSO() async {
  _isLoading = true;
  _errorMessage = null;
  notifyListeners();

  try {
    await _ssoService.login();
  } catch (e) {
    _errorMessage = e.toString();
  }

  _isLoading = false;
  notifyListeners();
  return false;
}

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final wasSso = prefs.getBool('logged_via_sso') ?? false;
    if (wasSso) {
      // await _ssoService.signOut();
    }
    await _clearSession(prefs);
    notifyListeners();
  }

  Future<bool> refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refresh = prefs.getString('refresh_token');

      if (refresh == null) {
        await logout();
        return false;
      }

      final response = await _apiService.post(
        'auth/token/refresh/',
        data: {'refresh': refresh},
      );

      if (response.statusCode == 200) {
        _accessToken = response.data['access'];
        await prefs.setString('access_token', _accessToken!);
        notifyListeners();
        return true;
      }
    } catch (_) {
      await logout();
    }
    return false;
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
    required String newPasswordConfirm,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        'users/change_password/',
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
          'new_password_confirm': newPasswordConfirm,
        },
      );
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Erreur lors du changement de mot de passe');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> verifyEmail(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiService.post(
        'auth/verify-email/',
        data: {'email': email, 'code': code},
      );
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Code incorrect');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> resendOtp(String email, String type) async {
    try {
      await _apiService.post(
        'auth/resend-otp/',
        data: {'email': email, 'type': type},
      );
    } catch (_) {}
  }

  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiService.post(
        'auth/forgot-password/',
        data: {'email': email},
      );
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Erreur lors de l\'envoi');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> resetPassword(String email, String code, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiService.post(
        'auth/reset-password/',
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
          'new_password_confirm': newPassword,
        },
      );
      if (response.statusCode == 200) {
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Code incorrect ou expiré');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    required String phoneNumber,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.patch(
        'users/${_currentUser?.id}/',
        data: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'phone_number': phoneNumber.trim(),
        },
      );

      if (response.statusCode == 200) {
        _currentUser = UserModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Erreur lors de la mise à jour');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// ─── CONNEXION PAR VISAGE ────────────────────────────────────────
  /// Indique si l'utilisateur courant a activé la connexion par visage.
  Future<bool> isFaceLoginEnabled() async {
    if (_currentUser == null) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('face_login_enabled_${_currentUser!.id}') ?? false;
  }

  /// Indique si une connexion par visage est disponible pour le dernier
  /// utilisateur connecté (utilisable depuis l'écran de login, avant token).
  Future<bool> isFaceLoginAvailable() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');
    final nni = prefs.getString('face_login_nni');
    if (userId == null || nni == null) return false;
    return prefs.getBool('face_login_enabled_$userId') ?? false;
  }

  /// Bouton "Connect avec Face" du profil : envoie la photo de référence
  /// (visage extrait pendant le KYC) au backend Django, qui la conserve pour
  /// pouvoir la comparer via /kyc/verify à chaque connexion. Aucun enrôlement
  /// biométrique permanent côté service de reconnaissance faciale tiers.
  Future<bool> enrollFaceLogin() async {
    if (_currentUser == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final nni = prefs.getString('face_login_nni');
      final imagePath = prefs.getString('face_login_image_path');

      if (nni == null || imagePath == null || !File(imagePath).existsSync()) {
        _errorMessage =
            'Aucune photo de vérification disponible. Refaites la vérification KYC.';
        return false;
      }

      final formData = FormData.fromMap({
        'national_id': nni,
        'file': await MultipartFile.fromFile(imagePath, filename: 'reference.jpg'),
      });

      final response = await _apiService.postForm('auth/face-login/enroll/', formData);

      if (response.statusCode != 200 && response.statusCode != 201) {
        _errorMessage = 'Échec de l\'activation de la connexion par visage.';
        return false;
      }

      await prefs.setBool('face_login_enabled_${_currentUser!.id}', true);
      return true;
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Échec de l\'activation de la connexion par visage');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tente une connexion par reconnaissance faciale : envoie le selfie et le
  /// NNI au backend, qui effectue lui-même la vérification biométrique
  /// auprès du service de reconnaissance faciale puis renvoie des tokens JWT.
  Future<bool> loginWithFace(File selfie) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final nni = prefs.getString('face_login_nni');
      if (nni == null) {
        _errorMessage = 'Connexion par visage non configurée.';
        return false;
      }

      final formData = FormData.fromMap({
        'national_id': nni,
        'file': await MultipartFile.fromFile(selfie.path, filename: 'selfie.jpg'),
      });

      final response = await _apiService.postForm('auth/face-login/', formData);

      if (response.statusCode == 200) {
        final data = response.data;
        _accessToken = data['access'];
        _refreshToken = data['refresh'];
        _currentUser = UserModel.fromJson(data['user']);

        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('user_id', _currentUser!.id);
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _extractError(e, 'Erreur lors de la connexion par visage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}

