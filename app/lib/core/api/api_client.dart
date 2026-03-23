import 'package:dio/dio.dart';

import '../models/backend_readiness.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient _instance = ApiClient._();
  static ApiClient get instance => _instance;

  static const String _baseUrl = 'http://127.0.0.1:8000';

  late final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  Dio get dio => _dio;

  Future<BackendReadiness> fetchBackendReadiness() async {
    final response = await _dio.get('/health');
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        error: 'Invalid health response format',
      );
    }
    return BackendReadiness.fromJson(data);
  }

  Future<bool> isBackendReachable() async {
    try {
      final readiness = await fetchBackendReadiness();
      return readiness.isReachable;
    } catch (_) {
      return false;
    }
  }
}
