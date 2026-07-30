import 'dart:async';
import 'package:flutter/foundation.dart';

/// RetryHelper — exponential back-off retry for network/API calls.
/// Prevents cascading failures and handles transient errors gracefully.
class RetryHelper {
  RetryHelper._();

  /// Retries [operation] up to [maxAttempts] times with exponential back-off.
  ///
  /// [retryIf] — optional predicate; if provided, only retries when it returns true.
  /// [onRetry] — optional callback invoked before each retry attempt.
  static Future<T> retry<T>(
    Future<T> Function() operation, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    double backoffFactor = 2.0,
    Duration maxDelay = const Duration(seconds: 10),
    bool Function(Object error)? retryIf,
    void Function(Object error, int attempt)? onRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempt++;

        // Don't retry if we've exhausted attempts
        if (attempt >= maxAttempts) rethrow;

        // Don't retry if the error is not retryable
        if (retryIf != null && !retryIf(e)) rethrow;

        // Don't retry auth errors (wrong credentials, etc.)
        if (_isNonRetryableError(e)) rethrow;

        onRetry?.call(e, attempt);

        if (kDebugMode) {
          debugPrint(
            '[RetryHelper] Attempt $attempt failed: $e. '
            'Retrying in ${delay.inMilliseconds}ms...',
          );
        }

        await Future.delayed(delay);
        delay = Duration(
          milliseconds: (delay.inMilliseconds * backoffFactor).round(),
        );
        if (delay > maxDelay) delay = maxDelay;
      }
    }
  }

  /// Determines if an error should NOT be retried.
  static bool _isNonRetryableError(Object error) {
    final message = error.toString().toLowerCase();
    // Auth errors, validation errors, and 4xx client errors are not retryable
    return message.contains('invalid login credentials') ||
        message.contains('email not confirmed') ||
        message.contains('user already registered') ||
        message.contains('invalid email') ||
        message.contains('password') ||
        message.contains('unauthorized') ||
        message.contains('forbidden') ||
        message.contains('not found') ||
        message.contains('422') ||
        message.contains('400') ||
        message.contains('401') ||
        message.contains('403') ||
        message.contains('404');
  }
}
