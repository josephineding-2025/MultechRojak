import 'package:dio/dio.dart';

String formatApiError(Object error, {String? fallbackMessage}) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }
  }

  final text = error.toString().trim();
  if (text.isNotEmpty) {
    return text;
  }

  return fallbackMessage ?? 'Something went wrong. Please try again.';
}
