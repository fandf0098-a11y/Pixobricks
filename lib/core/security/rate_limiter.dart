
/// RateLimiter — prevents brute-force attacks on auth and API endpoints.
/// Tracks attempt counts per key (e.g. email address) with a sliding window.
class RateLimiter {
  RateLimiter._();

  static final Map<String, _RateLimitEntry> _entries = {};

  /// Default: max 5 attempts per 15 minutes.
  static const int _maxAttempts = 5;
  static const Duration _window = Duration(minutes: 15);
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Returns true if the action is allowed, false if rate-limited.
  static bool checkAndRecord(String key) {
    _cleanup();
    final entry = _entries[key];

    if (entry != null && entry.isLockedOut) {
      return false;
    }

    if (entry == null) {
      _entries[key] = _RateLimitEntry(
        attempts: 1,
        firstAttempt: DateTime.now(),
        lockedUntil: null,
      );
      return true;
    }

    // Reset window if expired
    if (DateTime.now().difference(entry.firstAttempt) > _window) {
      _entries[key] = _RateLimitEntry(
        attempts: 1,
        firstAttempt: DateTime.now(),
        lockedUntil: null,
      );
      return true;
    }

    final newCount = entry.attempts + 1;
    if (newCount > _maxAttempts) {
      _entries[key] = entry.copyWith(
        attempts: newCount,
        lockedUntil: DateTime.now().add(_lockoutDuration),
      );
      return false;
    }

    _entries[key] = entry.copyWith(attempts: newCount);
    return true;
  }

  /// Returns remaining lockout duration, or null if not locked.
  static Duration? getLockoutRemaining(String key) {
    final entry = _entries[key];
    if (entry == null || !entry.isLockedOut) return null;
    final remaining = entry.lockedUntil!.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  /// Returns a human-readable lockout message.
  static String? getLockoutMessage(String key) {
    final remaining = getLockoutRemaining(key);
    if (remaining == null) return null;
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    if (minutes > 0) {
      return 'Too many attempts. Try again in ${minutes}m ${seconds}s.';
    }
    return 'Too many attempts. Try again in ${seconds}s.';
  }

  /// Reset attempts for a key (e.g. on successful login).
  static void reset(String key) {
    _entries.remove(key);
  }

  static void _cleanup() {
    final now = DateTime.now();
    _entries.removeWhere((key, entry) {
      if (entry.lockedUntil != null && now.isAfter(entry.lockedUntil!)) {
        return true;
      }
      if (now.difference(entry.firstAttempt) > _window * 2) {
        return true;
      }
      return false;
    });
  }
}

class _RateLimitEntry {
  final int attempts;
  final DateTime firstAttempt;
  final DateTime? lockedUntil;

  const _RateLimitEntry({
    required this.attempts,
    required this.firstAttempt,
    required this.lockedUntil,
  });

  bool get isLockedOut =>
      lockedUntil != null && DateTime.now().isBefore(lockedUntil!);

  _RateLimitEntry copyWith({
    int? attempts,
    DateTime? firstAttempt,
    DateTime? lockedUntil,
  }) {
    return _RateLimitEntry(
      attempts: attempts ?? this.attempts,
      firstAttempt: firstAttempt ?? this.firstAttempt,
      lockedUntil: lockedUntil ?? this.lockedUntil,
    );
  }
}
