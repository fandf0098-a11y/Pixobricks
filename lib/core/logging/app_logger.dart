import 'package:flutter/foundation.dart';

/// AppLogger — structured, levelled logging for BuildVerse.
/// In debug mode, logs to console. In release mode, errors are captured
/// silently and can be forwarded to a remote service (Sentry, etc.).
class AppLogger {
  AppLogger._();

  static const String _tag = 'BuildVerse';

  // ── Remote error capture hook ─────────────────────────────────────────────
  // Set this in main() to forward errors to Sentry, Crashlytics, etc.
  static void Function(Object error, StackTrace stackTrace)? onCrash;
  static void Function(String message, Object? error)? onError;

  // ── Log levels ────────────────────────────────────────────────────────────

  static void debug(String message, {String? context}) {
    if (kDebugMode) {
      _log('DEBUG', message, context: context);
    }
  }

  static void info(String message, {String? context}) {
    if (kDebugMode) {
      _log('INFO', message, context: context);
    }
  }

  static void warning(String message, {String? context, Object? error}) {
    if (kDebugMode) {
      _log('WARN', message, context: context, error: error);
    }
    // Forward to remote logging in release mode
    if (!kDebugMode && error != null) {
      onError?.call(message, error);
    }
  }

  static void error(
    String message, {
    String? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (kDebugMode) {
      _log('ERROR', message, context: context, error: error);
      if (stackTrace != null) {
        debugPrint('  StackTrace: $stackTrace');
      }
    }
    // Forward to remote error tracking in release mode
    if (!kDebugMode && error != null && stackTrace != null) {
      onCrash?.call(error, stackTrace);
    } else if (!kDebugMode && error != null) {
      onError?.call(message, error);
    }
  }

  static void crash(
    String message, {
    required Object error,
    required StackTrace stackTrace,
    String? context,
  }) {
    if (kDebugMode) {
      _log('CRASH', message, context: context, error: error);
      debugPrint('  StackTrace: $stackTrace');
    }
    // Forward to crash reporting service in release mode
    onCrash?.call(error, stackTrace);
  }

  // ── Auth-specific helpers ─────────────────────────────────────────────────

  static void authEvent(String event, {String? userId}) {
    info('Auth: $event', context: userId != null ? 'user=$userId' : null);
  }

  static void authError(String event, Object error) {
    AppLogger.error('Auth failure: $event', error: error, context: 'auth');
  }

  // ── Network helpers ───────────────────────────────────────────────────────

  static void networkError(String endpoint, Object error, {int? statusCode}) {
    AppLogger.error(
      'Network error on $endpoint${statusCode != null ? ' [$statusCode]' : ''}',
      error: error,
      context: 'network',
    );
  }

  static void networkRetry(String endpoint, int attempt, int maxAttempts) {
    warning(
      'Retrying $endpoint (attempt $attempt/$maxAttempts)',
      context: 'network',
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────

  static void _log(
    String level,
    String message, {
    String? context,
    Object? error,
  }) {
    final timestamp = DateTime.now().toIso8601String();
    final ctx = context != null ? ' [$context]' : '';
    final err = error != null ? ' | error: $error' : '';
    debugPrint('[$_tag][$level][$timestamp]$ctx $message$err');
  }
}
