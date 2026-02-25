import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  late Dio _dio;

  /// Android emulator → 10.0.2.2 ; iOS simulator / desktop → 127.0.0.1
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000/api/';
    return 'http://127.0.0.1:8000/api/';
  }

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
    
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          // Handle token refresh
        }
        return handler.next(error);
      },
    ));
  }
  
  Future<Response> post(String endpoint, {required Map<String, dynamic> data}) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      throw e;
    }
  }
  
  Future<Response> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    try {
      final response = await _dio.get(endpoint, queryParameters: queryParameters);
      return response;
    } on DioException catch (e) {
      throw e;
    }
  }
  
  Future<Response> put(String endpoint, {required Map<String, dynamic> data}) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      throw e;
    }
  }
  
  Future<Response> patch(String endpoint, {required Map<String, dynamic> data}) async {
    try {
      final response = await _dio.patch(endpoint, data: data);
      return response;
    } on DioException catch (e) {
      throw e;
    }
  }

  Future<Response> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return response;
    } on DioException catch (e) {
      throw e;
    }
  }
}