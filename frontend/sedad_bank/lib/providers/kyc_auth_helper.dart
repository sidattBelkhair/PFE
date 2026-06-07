import 'package:shared_preferences/shared_preferences.dart';

class KycAuthHelper {
  static String? extractUserId(dynamic authProvider) {
    if (authProvider == null) return null;

    try {
      final v = (authProvider as dynamic).userId;
      if (v != null && v.toString().isNotEmpty) return v.toString();
    } catch (_) {}

    try {
      final user = (authProvider as dynamic).user;
      if (user != null) {
        final id = _extractIdFromUser(user);
        if (id != null) return id;
      }
    } catch (_) {}

    try {
      final user = (authProvider as dynamic).currentUser;
      if (user != null) {
        final id = _extractIdFromUser(user);
        if (id != null) return id;
      }
    } catch (_) {}

    try {
      final user = (authProvider as dynamic).userData;
      if (user != null) {
        final id = _extractIdFromUser(user);
        if (id != null) return id;
      }
    } catch (_) {}

    return null;
  }

  static String? _extractIdFromUser(dynamic user) {
    if (user == null) return null;
    if (user is Map) {
      final id = user['id'] ?? user['userId'] ?? user['uuid'] ?? user['_id'];
      if (id != null && id.toString().isNotEmpty) return id.toString();
      return null;
    }
    try {
      final v = (user as dynamic).id;
      if (v != null && v.toString().isNotEmpty) return v.toString();
    } catch (_) {}
    try {
      final v = (user as dynamic).userId;
      if (v != null && v.toString().isNotEmpty) return v.toString();
    } catch (_) {}
    return null;
  }

  static Future<String?> fromSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_id') ??
           prefs.getString('auth_user_id') ??
           prefs.getString('current_user_id');
  }

  static Future<String?> getUserId(dynamic authProvider) async {
    final fromProvider = extractUserId(authProvider);
    if (fromProvider != null) return fromProvider;
    return await fromSharedPrefs();
  }
}
