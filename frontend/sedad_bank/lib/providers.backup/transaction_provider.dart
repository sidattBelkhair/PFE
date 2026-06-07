import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../core/services/api_service.dart';
import '../models/transaction_model.dart';

class TransactionProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<TransactionModel> _transactions = [];
  TransactionModel? _lastTransaction;
  bool _isLoading = false;
  String? _errorMessage;

  List<TransactionModel> get transactions => _transactions;
  TransactionModel? get lastTransaction => _lastTransaction;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Extrait le message d'erreur lisible depuis une réponse backend DRF
  String _parseError(DioException e, String fallback) {
    final d = e.response?.data;
    if (d == null) return e.message ?? fallback;
    // ["message"] — ValidationError levée sans clé
    if (d is List && d.isNotEmpty) return d.first.toString();
    if (d is Map) {
      if (d.containsKey('non_field_errors')) {
        final v = d['non_field_errors'];
        return v is List ? v.first.toString() : v.toString();
      }
      if (d.containsKey('detail')) return d['detail'].toString();
      if (d.containsKey('error')) return d['error'].toString();
      // premier champ de validation
      final first = d.values.first;
      return first is List ? first.first.toString() : first.toString();
    }
    return e.message ?? fallback;
  }

  Future<void> fetchTransactions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch sent transactions
      final sentResponse = await _apiService.get('transactions/');
      final List<TransactionModel> sentTxs = [];
      if (sentResponse.statusCode == 200) {
        final data = sentResponse.data;
        final list = data is Map && data.containsKey('results')
            ? data['results'] as List
            : data is List
                ? data
                : [];
        sentTxs.addAll(list.map((j) => TransactionModel.fromJson(j, isCredit: false)));
      }

      // Fetch received transactions (deposits/incoming transfers)
      final receivedResponse = await _apiService.get('transactions/received/');
      final List<TransactionModel> receivedTxs = [];
      if (receivedResponse.statusCode == 200) {
        final data = receivedResponse.data;
        final list = data is Map && data.containsKey('results')
            ? data['results'] as List
            : data is List
                ? data
                : [];
        receivedTxs.addAll(list.map((j) => TransactionModel.fromJson(j, isCredit: true)));
      }

      // Merge and sort by date descending
      final all = [...sentTxs, ...receivedTxs];
      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _transactions = all;
    } on DioException catch (e) {
      _errorMessage = _parseError(e, 'Erreur lors du chargement des transactions');
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendTransfer({
    required String fromAccountId,
    required String toPhone,
    required double amount,
    required String description,
    String currency = 'MRU',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        'transactions/',
        data: {
          'from_account': fromAccountId,
          'to_phone': toPhone,
          'amount': amount,
          'currency': currency,
          'description': description,
          'transaction_type': 'transfer',
        },
      );

      if (response.statusCode == 201) {
        final newTransaction = TransactionModel.fromJson(response.data, isCredit: false);
        _transactions.insert(0, newTransaction);
        _lastTransaction = newTransaction;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _parseError(e, 'Erreur lors du virement');
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> createTransaction({
    required String fromAccountId,
    required String transactionType,
    required double amount,
    required String description,
    String? toPhone,
    String currency = 'MRU',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> data = {
        'from_account': fromAccountId,
        'transaction_type': transactionType,
        'amount': amount,
        'currency': currency,
        'description': description,
      };
      if (toPhone != null && toPhone.isNotEmpty) data['to_phone'] = toPhone;

      final response = await _apiService.post('transactions/', data: data);
      if (response.statusCode == 201) {
        final tx = TransactionModel.fromJson(response.data, isCredit: false);
        _transactions.insert(0, tx);
        _lastTransaction = tx;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on DioException catch (e) {
      _errorMessage = _parseError(e, 'Erreur lors de la transaction');
    } catch (e) {
      _errorMessage = 'Erreur inattendue: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}
