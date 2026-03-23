import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/models/background_check_result.dart';

// ---------------------------------------------------------------------------
// Event model
// ---------------------------------------------------------------------------

enum CheckStep { scraping, parsingBio, osint, complete, error }

class BackgroundCheckEvent {
  final CheckStep step;
  final String status;   // 'started' | 'done' | 'failed'
  final String message;
  final String? severity;
  final BackgroundCheckResult? result;

  const BackgroundCheckEvent({
    required this.step,
    required this.status,
    required this.message,
    this.severity,
    this.result,
  });

  factory BackgroundCheckEvent.fromJson(Map<String, dynamic> json) {
    final stepStr = json['step'] as String? ?? 'error';
    final step = _stepFromString(stepStr);
    final resultJson = json['result'];
    return BackgroundCheckEvent(
      step: step,
      status: json['status'] as String? ?? 'done',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String?,
      result: resultJson != null
          ? BackgroundCheckResult.fromJson(resultJson as Map<String, dynamic>)
          : null,
    );
  }

  static CheckStep _stepFromString(String s) {
    switch (s) {
      case 'scraping':
        return CheckStep.scraping;
      case 'parsing_bio':
        return CheckStep.parsingBio;
      case 'osint':
        return CheckStep.osint;
      case 'complete':
        return CheckStep.complete;
      default:
        return CheckStep.error;
    }
  }

  /// Whether this event represents a red flag finding.
  bool get isFlag =>
      step == CheckStep.osint &&
      status == 'done' &&
      severity != null &&
      severity != 'low';
}

// ---------------------------------------------------------------------------
// StreamProvider
// ---------------------------------------------------------------------------

/// Streams [BackgroundCheckEvent]s from the SSE endpoint.
///
/// Pass a Map with:
///   'profile_url'  (required)
///   'username'     (optional)
///   'platform'     (optional)
///   'phone'        (optional)
final backgroundCheckStreamProvider = StreamProvider.autoDispose
    .family<BackgroundCheckEvent, Map<String, String>>(
  (ref, params) => _streamBackgroundCheck(params),
);

Stream<BackgroundCheckEvent> _streamBackgroundCheck(
    Map<String, String> params) async* {
  final dio = ApiClient.instance.dio;

  final queryParams = <String, String>{};
  for (final entry in params.entries) {
    if (entry.value.isNotEmpty) {
      queryParams[entry.key] = entry.value;
    }
  }

  Response<ResponseBody> response;
  try {
    response = await dio.get<ResponseBody>(
      '/background-check/stream',
      queryParameters: queryParams,
      options: Options(
        responseType: ResponseType.stream,
        receiveTimeout: const Duration(minutes: 5),
        headers: {'Accept': 'text/event-stream'},
      ),
    );
  } catch (e) {
    yield BackgroundCheckEvent(
      step: CheckStep.error,
      status: 'failed',
      message: 'Could not connect to backend: $e',
      severity: 'high',
    );
    return;
  }

  final buffer = StringBuffer();

  await for (final chunk in response.data!.stream) {
    buffer.write(utf8.decode(chunk, allowMalformed: true));
    final raw = buffer.toString();
    buffer.clear();

    // SSE messages are separated by \n\n; lines start with "data: "
    final lines = raw.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.startsWith('data: ')) {
        final jsonStr = line.substring(6).trim();
        if (jsonStr.isEmpty) continue;
        try {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
          yield BackgroundCheckEvent.fromJson(decoded);
        } catch (_) {
          // malformed — skip
        }
      } else if (line.isNotEmpty) {
        // incomplete line — re-buffer it (will be prepended to next chunk)
        buffer.write(line);
        if (i < lines.length - 1) buffer.write('\n');
      }
    }
  }
}
