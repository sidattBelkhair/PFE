import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
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
    final data = e.response?.data;
    if (data == null) return fallback;
    if (data is String) return data;
    if (data is Map) {
      // non_field_errors: ["message"]
      if (data.containsKey('non_field_errors')) {
        final errors = data['non_field_errors'];
        if (errors is List && errors.isNotEmpty) return errors.first.toString();
      }
      // detail: "message"
      if (data.containsKey('detail')) return data['detail'].toString();
      // { email: ["..."], password: ["..."] }
      final firstKey = data.keys.first;
      final val = data[firstKey];
      if (val is List && val.isNotEmpty) return '${firstKey}: ${val.first}';
      return data.toString();
    }
    return fallback;
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

        // Vérifier que le token est encore valide en récupérant l'utilisateur
        final response = await _apiService.get('users/me/');
        if (response.statusCode == 200) {
          _currentUser = UserModel.fromJson(response.data);
        } else {
          await _clearSession(prefs);
        }
      }
    } on DioException catch (e) {
      // Token expiré → essayer le refresh
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
    await prefs.remove('user_id');
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
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
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
}
