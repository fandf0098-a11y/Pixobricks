import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/logging/app_logger.dart';

/// Offline Sync Service for BuildVerse
/// Queues mutations locally when offline, syncs when connectivity returns.
class OfflineSyncService {
  static OfflineSyncService? _instance;
  static OfflineSyncService get instance =>
      _instance ??= OfflineSyncService._();
  OfflineSyncService._();

  static const String _queueKey = 'buildverse_sync_queue';
  static const String _lastSyncKey = 'buildverse_last_sync';

  final _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isSyncing = false;
  bool _isOnline = true;

  final _syncStatusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get syncStatus => _syncStatusController.stream;

  // ─── Initialization ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((
      results,
    ) async {
      final wasOffline = !_isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);
      if (wasOffline && _isOnline) {
        await _flushQueue();
      }
    });

    // Attempt initial flush if online
    if (_isOnline) {
      await _flushQueue();
    }
  }

  void dispose() {
    _connectivitySub?.cancel();
    _syncStatusController.close();
  }

  bool get isOnline => _isOnline;

  // ─── Queue Management ────────────────────────────────────────────────────

  Future<void> enqueue({
    required String tableName,
    required String operation,
    required Map<String, dynamic> payload,
    String? recordId,
  }) async {
    final entry = SyncEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tableName: tableName,
      operation: operation,
      payload: payload,
      recordId: recordId,
      createdAt: DateTime.now(),
    );

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    raw.add(jsonEncode(entry.toJson()));
    await prefs.setStringList(_queueKey, raw);

    _syncStatusController.add(
      SyncStatus(
        pendingCount: raw.length,
        isOnline: _isOnline,
        isSyncing: _isSyncing,
      ),
    );

    // If online, try to flush immediately
    if (_isOnline && !_isSyncing) {
      await _flushQueue();
    }
  }

  Future<List<SyncEntry>> getPendingEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey) ?? [];
    return raw.map((e) => SyncEntry.fromJson(jsonDecode(e))).toList();
  }

  Future<int> getPendingCount() async {
    final entries = await getPendingEntries();
    return entries.length;
  }

  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getString(_lastSyncKey);
    return ts != null ? DateTime.tryParse(ts) : null;
  }

  // ─── Flush Queue ─────────────────────────────────────────────────────────

  Future<SyncResult> _flushQueue() async {
    if (_isSyncing) return SyncResult(processed: 0, failed: 0);
    final entries = await getPendingEntries();
    if (entries.isEmpty) return SyncResult(processed: 0, failed: 0);

    _isSyncing = true;
    _syncStatusController.add(
      SyncStatus(
        pendingCount: entries.length,
        isOnline: _isOnline,
        isSyncing: true,
      ),
    );

    int processed = 0;
    int failed = 0;
    final remaining = <SyncEntry>[];

    for (final entry in entries) {
      if (entry.retryCount >= 3) {
        // Permanently failed — drop it and log
        AppLogger.warning(
          'Dropping sync entry after 3 retries',
          context: '${entry.tableName}/${entry.operation}/${entry.id}',
        );
        continue;
      }
      try {
        await _applyEntry(entry);
        processed++;
        AppLogger.debug(
          'Synced entry ${entry.id}',
          context: '${entry.tableName}/${entry.operation}',
        );
      } catch (e) {
        AppLogger.networkRetry(
          '${entry.tableName}/${entry.operation}',
          entry.retryCount + 1,
          3,
        );
        remaining.add(entry.copyWith(retryCount: entry.retryCount + 1));
        failed++;
      }
    }

    // Persist remaining entries
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _queueKey,
      remaining.map((e) => jsonEncode(e.toJson())).toList(),
    );
    await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

    _isSyncing = false;
    _syncStatusController.add(
      SyncStatus(
        pendingCount: remaining.length,
        isOnline: _isOnline,
        isSyncing: false,
        lastSyncTime: DateTime.now(),
      ),
    );

    return SyncResult(processed: processed, failed: failed);
  }

  Future<SyncResult> manualSync() async {
    if (!_isOnline) {
      return SyncResult(
        processed: 0,
        failed: 0,
        error: 'No internet connection',
      );
    }
    return _flushQueue();
  }

  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
    _syncStatusController.add(
      SyncStatus(pendingCount: 0, isOnline: _isOnline, isSyncing: false),
    );
  }

  // ─── Apply Entry to Supabase ─────────────────────────────────────────────

  Future<void> _applyEntry(SyncEntry entry) async {
    final client = Supabase.instance.client;
    switch (entry.operation) {
      case 'insert':
        await client.from(entry.tableName).insert(entry.payload);
        break;
      case 'update':
        if (entry.recordId == null) {
          throw Exception('Missing record_id for update');
        }
        await client
            .from(entry.tableName)
            .update(entry.payload)
            .eq('id', entry.recordId!);
        break;
      case 'delete':
        if (entry.recordId == null) {
          throw Exception('Missing record_id for delete');
        }
        await client.from(entry.tableName).delete().eq('id', entry.recordId!);
        break;
      default:
        throw Exception('Unknown operation: ${entry.operation}');
    }
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class SyncEntry {
  final String id;
  final String tableName;
  final String operation;
  final Map<String, dynamic> payload;
  final String? recordId;
  final DateTime createdAt;
  final int retryCount;

  const SyncEntry({
    required this.id,
    required this.tableName,
    required this.operation,
    required this.payload,
    this.recordId,
    required this.createdAt,
    this.retryCount = 0,
  });

  SyncEntry copyWith({int? retryCount}) => SyncEntry(
    id: id,
    tableName: tableName,
    operation: operation,
    payload: payload,
    recordId: recordId,
    createdAt: createdAt,
    retryCount: retryCount ?? this.retryCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'table_name': tableName,
    'operation': operation,
    'payload': payload,
    'record_id': recordId,
    'created_at': createdAt.toIso8601String(),
    'retry_count': retryCount,
  };

  factory SyncEntry.fromJson(Map<String, dynamic> json) => SyncEntry(
    id: json['id'] as String,
    tableName: json['table_name'] as String,
    operation: json['operation'] as String,
    payload: Map<String, dynamic>.from(json['payload'] as Map),
    recordId: json['record_id'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    retryCount: (json['retry_count'] as int?) ?? 0,
  );
}

class SyncStatus {
  final int pendingCount;
  final bool isOnline;
  final bool isSyncing;
  final DateTime? lastSyncTime;

  const SyncStatus({
    required this.pendingCount,
    required this.isOnline,
    required this.isSyncing,
    this.lastSyncTime,
  });
}

class SyncResult {
  final int processed;
  final int failed;
  final String? error;

  const SyncResult({required this.processed, required this.failed, this.error});
}
