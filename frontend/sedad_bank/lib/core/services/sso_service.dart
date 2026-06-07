// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/services.dart';
// import 'package:flutter_appauth/flutter_appauth.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:http/http.dart' as http;

// class SsoException implements Exception {
//   final String message;
//   final String? code;
//   SsoException(this.message, {this.code});
//   @override
//   String toString() => message;
// }

// class SSOService {
//   static const String _clientId    = 'FaACVS7Ds3qjR5i6ynVmhGtzlZ44wan45hgDJwVF';
//   static const String _redirectUrl = 'com.example.sedad_bank://oauth/callback';
//   static const String _issuer      = 'https://sso-backend-6b1e.onrender.com';
//   static const String _authEndpoint  = '$_issuer/o/authorize/';
//   static const String _tokenEndpoint = '$_issuer/o/token/';
//   static const String _userInfoUrl   = '$_issuer/o/userinfo/';

//   final FlutterAppAuth _appAuth = const FlutterAppAuth();
//   final FlutterSecureStorage _storage = const FlutterSecureStorage();

//   // ── Réveille le serveur Render.com (cold start ~5 s) ────────────────────
//   Future<void> _warmUp() async {
//     try {
//       await http
//           .get(Uri.parse('$_issuer/.well-known/openid-configuration'))
//           .timeout(const Duration(seconds: 15));
//     } catch (_) {
//       // on ignore : ce n'est qu'un wake-up, pas bloquant
//     }
//   }

//   // ── Flow principal PKCE ──────────────────────────────────────────────────
//   Future<Map<String, dynamic>> signInWithSSO() async {
//     if (!Platform.isAndroid && !Platform.isIOS) {
//       throw SsoException(
//         'SSO disponible uniquement sur Android et iOS.\nTestez sur votre téléphone.',
//         code: 'unsupported_platform',
//       );
//     }
//     print('[SSO] Warm-up du serveur...');
//     await _warmUp();
//     print('[SSO] Lancement du flow PKCE → clientId=$_clientId  redirect=$_redirectUrl');

//     AuthorizationTokenResponse? result;
//     try {
//       result = await _appAuth.authorizeAndExchangeCode(
//         AuthorizationTokenRequest(
//           _clientId,
//           _redirectUrl,
//           serviceConfiguration: const AuthorizationServiceConfiguration(
//             authorizationEndpoint: _authEndpoint,
//             tokenEndpoint: _tokenEndpoint,
//           ),
//           scopes: ['openid', 'email', 'profile'],
//           allowInsecureConnections: false,
//           promptValues: ['login'],
//         ),
//       );
//     } on PlatformException catch (e) {
//       final msg = e.message ?? '';
//       if (msg.contains('cancel') || msg.contains('User cancelled') || e.code == 'CANCELED') {
//         throw SsoException('Connexion annulée.', code: 'canceled');
//       }
//       if (msg.contains('redirect_uri_mismatch')) {
//         throw SsoException(
//           'Redirect URI non enregistrée sur NovaGard.\nURI : $_redirectUrl',
//           code: 'redirect_uri_mismatch',
//         );
//       }
//       if (msg.contains('invalid_client')) {
//         throw SsoException('Client ID invalide.', code: 'invalid_client');
//       }
//       throw SsoException('Erreur SSO : $msg', code: e.code);
//     } catch (e) {
//       if (e is SocketException) {
//         throw SsoException('Impossible de joindre le serveur SSO.');
//       }
//       if (e is SsoException) rethrow;
//       throw SsoException('Erreur inattendue SSO : $e');
//     }

//     final accessToken = result?.accessToken;
//     if (accessToken == null) {
//       throw SsoException('Aucun token reçu du serveur SSO.');
//     }

//     print('[SSO] Token reçu');

//     // Stocker les tokens de façon sécurisée
//     await _storage.write(key: 'sso_access_token', value: accessToken);
//     final refreshToken = result?.refreshToken;
//     final idToken      = result?.idToken;
//     if (refreshToken != null) {
//       await _storage.write(key: 'sso_refresh_token', value: refreshToken);
//     }
//     if (idToken != null) {
//       await _storage.write(key: 'sso_id_token', value: idToken);
//     }

//     // Récupérer le profil utilisateur depuis /o/userinfo/
//     final userInfo = await _fetchUserInfo(accessToken);
//     print('[SSO] User info: $userInfo');

//     return {
//       'access_token':  accessToken,
//       'id_token':      idToken,
//       'refresh_token': refreshToken,
//       'user_info':     userInfo,
//     };
//   }

//   // ── Récupère le profil utilisateur ─────────────────────────────────────
//   Future<Map<String, dynamic>?> _fetchUserInfo(String accessToken) async {
//     try {
//       final response = await http
//           .get(
//             Uri.parse(_userInfoUrl),
//             headers: {'Authorization': 'Bearer $accessToken'},
//           )
//           .timeout(const Duration(seconds: 15));

//       if (response.statusCode == 200) {
//         return json.decode(response.body) as Map<String, dynamic>;
//       }
//       print('[SSO] /userinfo → HTTP ${response.statusCode}');
//       return null;
//     } catch (e) {
//       print('[SSO] /userinfo erreur : $e');
//       return null;
//     }
//   }

//   // ── Déconnexion ──────────────────────────────────────────────────────────
//   Future<void> signOut() async {
//     await _storage.delete(key: 'sso_access_token');
//     await _storage.delete(key: 'sso_refresh_token');
//     await _storage.delete(key: 'sso_id_token');
//   }

//   Future<bool> isSignedIn() async {
//     final token = await _storage.read(key: 'sso_access_token');
//     return token != null;
//   }
// }
import 'package:url_launcher/url_launcher.dart';

class SSOService {

  Future<void> login() async {

    final url = Uri.parse(
      'http://104.248.61.147:8000/api/auth/sso/start/'
    );

    await launchUrl(url);
  }
}
