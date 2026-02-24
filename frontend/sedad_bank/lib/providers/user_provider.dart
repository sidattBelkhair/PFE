import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/services/api_service.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<UserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchUsers() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('users/');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('results')) {
          _users = (data['results'] as List).map((j) => UserModel.fromJson(j)).toList();
        } else if (data is List) {
          _users = data.map((j) => UserModel.fromJson(j)).toList();
        }
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Erreur lors du chargement des utilisateurs';
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateUserStatus(String userId, String newStatus) async {
    try {
      final response = await _apiService.patch(
        'users/$userId/update-status/',
        data: {'status': newStatus},
      );
      if (response.statusCode == 200) {
        final updated = UserModel.fromJson(response.data);
        final idx = _users.indexWhere((u) => u.id == userId);
        if (idx != -1) {
          _users[idx] = updated;
          notifyListeners();
        }
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['detail'] ?? 'Erreur lors de la mise à jour';
    }
    return false;
  }
}
