import 'dart:async';
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SsoException implements Exception {
  final String message;
  final String? code;
  SsoException(this.message, {this.code});
  @override
  String toString() => message;
}

class SSOService {
  static const String _backend = 'http://104.248.61.147:8000';
  static const String _startUrl = '$_backend/api/auth/sso/start/';
  static const String _exchangeUrl = '$_backend/api/auth/sso/exchange/';
  static const String _callbackScheme = 'com.example.sedadbank';
  static const String _callbackHost = 'sso-callback';

  final AppLinks _appLinks = AppLinks();
  Completer<Uri>? _activeCompleter;
  StreamSubscription<Uri>? _activeSub;

  void cancel() {
    _activeSub?.cancel();
    _activeSub = null;
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.completeError(SsoException('Connexion SSO annulée.', code: 'cancelled'));
    }
    _activeCompleter = null;
  }

  /// Lance le flow SSO dans le navigateur, attend le deep link de retour
  /// (com.example.sedadbank://sso-callback?token=XXX) puis échange ce
  /// jeton à usage unique contre les JWT de l'app.
  Future<Map<String, dynamic>> login() async {
    cancel();
    final callbackFuture = _waitForCallback();

    final launched = await launchUrl(
      Uri.parse(_startUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw SsoException('Impossible d\'ouvrir le navigateur pour le SSO.');
    }

    final Uri callbackUri = await callbackFuture.timeout(
      const Duration(minutes: 3),
      onTimeout: () => throw SsoException('Connexion SSO expirée.', code: 'timeout'),
    );

    final error = callbackUri.queryParameters['error'];
    if (error != null) {
      throw SsoException(
        callbackUri.queryParameters['message'] ?? 'Erreur SSO',
        code: error,
      );
    }

    final token = callbackUri.queryParameters['token'];
    if (token == null) {
      throw SsoException('Jeton SSO manquant dans la réponse.');
    }

    return _exchangeToken(token);
  }

  Future<Uri> _waitForCallback() {
    final completer = Completer<Uri>();
    _activeCompleter = completer;

    _activeSub = _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == _callbackScheme && uri.host == _callbackHost) {
        _activeSub?.cancel();
        _activeSub = null;
        _activeCompleter = null;
        if (!completer.isCompleted) completer.complete(uri);
      }
    }, onError: (e) {
      _activeSub?.cancel();
      _activeSub = null;
      _activeCompleter = null;
      if (!completer.isCompleted) {
        completer.completeError(SsoException('Erreur lors de l\'écoute du retour SSO : $e'));
      }
    });

    return completer.future;
  }

  Future<Map<String, dynamic>> _exchangeToken(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse(_exchangeUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'token': token}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        throw SsoException('Jeton invalide ou expiré.', code: 'exchange_failed');
      }

      return json.decode(response.body) as Map<String, dynamic>;
    } on SsoException {
      rethrow;
    } catch (e) {
      throw SsoException('Impossible de finaliser la connexion SSO : $e');
    }
  }
}
