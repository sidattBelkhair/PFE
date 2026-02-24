import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/services/api_service.dart';
import '../models/account_model.dart';

class AccountProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AccountModel> _accounts = [];
  AccountModel? _selectedAccount;
  bool _isLoading = false;
  String? _errorMessage;

  List<AccountModel> get accounts => _accounts;
  AccountModel? get selectedAccount => _selectedAccount;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchAccounts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get('accounts/');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data.containsKey('results')) {
          _accounts = (data['results'] as List)
              .map((json) => AccountModel.fromJson(json))
              .toList();
        } else if (data is List) {
          _accounts = data.map((json) => AccountModel.fromJson(json)).toList();
        }

        if (_accounts.isNotEmpty && _selectedAccount == null) {
          _selectedAccount = _accounts.firstWhere(
            (acc) => acc.isDefault,
            orElse: () => _accounts.first,
          );
        }
      }
    } on DioException catch (e) {
      _errorMessage = e.message ?? 'Erreur lors du chargement des comptes';
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectAccount(AccountModel account) {
    _selectedAccount = account;
    notifyListeners();
  }

  Future<bool> createAccount({
    required String accountName,
    required String accountType,
    required String currency,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        'accounts/',
        data: {
          'account_name': accountName,
          'account_type': accountType,
          'currency': currency,
        },
      );

      if (response.statusCode == 201) {
        final newAccount = AccountModel.fromJson(response.data);
        _accounts.add(newAccount);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['detail'] ?? e.message ?? 'Erreur lors de la création du compte';
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Créditer un compte (dépôt) via POST /accounts/{id}/deposit/
  Future<bool> depositToAccount({
    required String accountId,
    required double amount,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        'accounts/$accountId/deposit/',
        data: {'amount': amount},
      );
      if (response.statusCode == 200) {
        final updated = AccountModel.fromJson(response.data);
        final idx = _accounts.indexWhere((a) => a.id == accountId);
        if (idx != -1) _accounts[idx] = updated;
        if (_selectedAccount?.id == accountId) _selectedAccount = updated;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data?['error'] ?? e.message ?? 'Erreur lors du dépôt';
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}