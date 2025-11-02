import 'dart:async';
import 'dart:math';

import 'package:http/http.dart' as http;

class ApiRequestExecutor {
  ApiRequestExecutor({
    required http.Client client,
    this.connectTimeout = const Duration(seconds: 2),
    this.receiveTimeout = const Duration(seconds: 3),
    this.maxRetries = 2,
    Duration? jitterBase,
  })  : _client = client,
        _jitterBase = jitterBase ?? const Duration(milliseconds: 350);

  final http.Client _client;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final int maxRetries;
  final Duration _jitterBase;

  Duration get _requestTimeout => connectTimeout + receiveTimeout;

  Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) {
    return _execute(() => _client.get(uri, headers: headers));
  }

  Future<T> _execute<T>(Future<T> Function() runner) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        final result = await runner().timeout(_requestTimeout);
        if (result is http.Response &&
            _shouldRetryStatus(result.statusCode) &&
            attempt <= maxRetries) {
          await _sleepWithJitter(attempt);
          continue;
        }
        return result;
      } on TimeoutException {
        if (attempt > maxRetries) rethrow;
        await _sleepWithJitter(attempt);
      } on http.ClientException {
        if (attempt > maxRetries) rethrow;
        await _sleepWithJitter(attempt);
      }
    }
  }

  Future<void> _sleepWithJitter(int attempt) async {
    final multiplier = 1 << (attempt - 1);
    final baseMillis = _jitterBase.inMilliseconds * multiplier;
    final random = Random();
    final jitter = random.nextInt(_jitterBase.inMilliseconds);
    final delay = Duration(milliseconds: baseMillis.toInt() + jitter);
    await Future.delayed(delay);
  }

  bool _shouldRetryStatus(int statusCode) {
    return statusCode == 429 || statusCode >= 500;
  }
}
