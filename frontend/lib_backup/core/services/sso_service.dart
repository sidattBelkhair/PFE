import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class SSOService {
  static const String clientId = 'FaACVS7Ds3qjR5i6ynVmhGtzlZ44wan45hgDJwVF';
  static const String redirectUrl = 'com.example.sedad_bank:/oauth/callback';
  static const String issuer = 'https://sso-backend-6b1e.onrender.com';
  static const String authEndpoint = '$issuer/o/authorize/';
  static const String tokenEndpoint = '$issuer/o/token/';
  static const String userInfoEndpoint = '$issuer/o/userinfo/';

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>?> signInWithSSO() async {
    try {
      print('[SSO] Starting auth flow...');
      print('[SSO] clientId=$clientId');
      print('[SSO] redirectUrl=$redirectUrl');

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          clientId,
          redirectUrl,
          serviceConfiguration: const AuthorizationServiceConfiguration(
            authorizationEndpoint: authEndpoint,
            tokenEndpoint: tokenEndpoint,
          ),
          scopes: ['openid', 'profile', 'email'],
          allowInsecureConnections: false,
        ),
      );

      if (result == null || result.accessToken == null) {
        print('[SSO] ❌ Pas de token reçu');
        return null;
      }

      print('[SSO] ✅ Token reçu');
      await _storage.write(key: 'sso_access_token', value: result.accessToken);
      if (result.refreshToken != null) {
        await _storage.write(key: 'sso_refresh_token', value: result.refreshToken);
      }
      if (result.idToken != null) {
        await _storage.write(key: 'sso_id_token', value: result.idToken);
      }

      final userInfo = await _fetchUserInfo(result.accessToken!);
      print('[SSO] User info: $userInfo');

      return {
        'access_token': result.accessToken,
        'id_token': result.idToken,
        'refresh_token': result.refreshToken,
        'user_info': userInfo,
      };
    } catch (e, stack) {
      print('[SSO] ❌ Erreur: $e');
      print('[SSO] Stack: $stack');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchUserInfo(String accessToken) async {
    try {
      final response = await http.get(
        Uri.parse(userInfoEndpoint),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      print('[SSO] userinfo HTTP ${response.statusCode}');
      return null;
    } catch (e) {
      print('[SSO] userinfo error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _storage.delete(key: 'sso_access_token');
    await _storage.delete(key: 'sso_refresh_token');
    await _storage.delete(key: 'sso_id_token');
  }

  Future<bool> isSignedIn() async {
    final token = await _storage.read(key: 'sso_access_token');
    return token != null;
  }
}
