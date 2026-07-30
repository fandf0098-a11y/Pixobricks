import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SimpleCache — lightweight in-memory + persistent cache for API responses.
/// Reduces redundant network calls and improves perceived performance.
class SimpleCache {
  SimpleCache._();

  static final Map<String, _CacheEntry> _memoryCache = {};

  // ── In-memory cache ───────────────────────────────────────────────────────

  /// Store a value in memory with an optional TTL.
  static void set<T>(
    String key,
    T value, {
    Duration ttl = const Duration(minutes: 5),
  }) {
    _memoryCache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl),
    );
  }

  /// Retrieve a value from memory. Returns null if missing or expired.
  static T? get<T>(String key) {
    final entry = _memoryCache[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiresAt)) {
      _memoryCache.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  /// Invalidate a specific key.
  static void invalidate(String key) {
    _memoryCache.remove(key);
  }

  /// Invalidate all keys matching a prefix.
  static void invalidatePrefix(String prefix) {
    _memoryCache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all cached entries.
  static void clear() {
    _memoryCache.clear();
  }

  /// Remove all expired entries.
  static void evictExpired() {
    final now = DateTime.now();
    _memoryCache.removeWhere((_, entry) => now.isAfter(entry.expiresAt));
  }

  // ── Persistent cache (SharedPreferences) ──────────────────────────────────

  static const String _persistPrefix = 'bv_cache_';

  static Future<void> persistString(
    String key,
    String value, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
      await prefs.setString('$_persistPrefix${key}_val', value);
      await prefs.setInt('$_persistPrefix${key}_exp', expiresAt);
    } catch (e) {
      if (kDebugMode) debugPrint('[SimpleCache] persistString error: $e');
    }
  }

  static Future<String?> getPersistedString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiresAt = prefs.getInt('$_persistPrefix${key}_exp');
      if (expiresAt == null) return null;
      if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await prefs.remove('$_persistPrefix${key}_val');
        await prefs.remove('$_persistPrefix${key}_exp');
        return null;
      }
      return prefs.getString('$_persistPrefix${key}_val');
    } catch (e) {
      if (kDebugMode) debugPrint('[SimpleCache] getPersistedString error: $e');
      return null;
    }
  }

  static Future<void> clearPersisted(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_persistPrefix${key}_val');
      await prefs.remove('$_persistPrefix${key}_exp');
    } catch (_) {}
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  const _CacheEntry({required this.value, required this.expiresAt});
}
