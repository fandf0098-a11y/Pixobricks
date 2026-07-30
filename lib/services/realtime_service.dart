import 'package:supabase_flutter/supabase_flutter.dart';

/// Realtime Subscription Manager for BuildVerse
/// Manages all Supabase realtime channels with proper lifecycle management.
class RealtimeService {
  static RealtimeService? _instance;
  static RealtimeService get instance => _instance ??= RealtimeService._();
  RealtimeService._();

  final Map<String, RealtimeChannel> _channels = {};

  SupabaseClient get _client => Supabase.instance.client;

  // ─── Notifications Channel ───────────────────────────────────────────────

  RealtimeChannel subscribeToNotifications({
    required String userId,
    required void Function(Map<String, dynamic> notification) onNew,
  }) {
    const key = 'notifications';
    _channels[key]?.unsubscribe();

    final channel = _client
        .channel('user_notifications_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNew(Map<String, dynamic>.from(payload.newRecord));
            }
          },
        )
        .subscribe();

    _channels[key] = channel;
    return channel;
  }

  // ─── Posts Feed Channel ──────────────────────────────────────────────────

  RealtimeChannel subscribeToFeed({
    required void Function(Map<String, dynamic> post) onNew,
    required void Function(Map<String, dynamic> post) onUpdated,
    required void Function(String postId) onDeleted,
  }) {
    const key = 'feed';
    _channels[key]?.unsubscribe();

    final channel = _client
        .channel('public_feed')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNew(Map<String, dynamic>.from(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onUpdated(Map<String, dynamic>.from(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'posts',
          callback: (payload) {
            final id = payload.oldRecord['id'] as String?;
            if (id != null) onDeleted(id);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return channel;
  }

  // ─── Comments Channel ────────────────────────────────────────────────────

  RealtimeChannel subscribeToComments({
    required String postId,
    required void Function(Map<String, dynamic> comment) onNew,
    required void Function(String commentId) onDeleted,
  }) {
    final key = 'comments_$postId';
    _channels[key]?.unsubscribe();

    final channel = _client
        .channel('post_comments_$postId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNew(Map<String, dynamic>.from(payload.newRecord));
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'comments',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'post_id',
            value: postId,
          ),
          callback: (payload) {
            final id = payload.oldRecord['id'] as String?;
            if (id != null) onDeleted(id);
          },
        )
        .subscribe();

    _channels[key] = channel;
    return channel;
  }

  // ─── Follows Channel ─────────────────────────────────────────────────────

  RealtimeChannel subscribeToFollows({
    required String userId,
    required void Function(Map<String, dynamic> follow) onNewFollower,
  }) {
    final key = 'follows_$userId';
    _channels[key]?.unsubscribe();

    final channel = _client
        .channel('user_follows_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'follows',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'following_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord.isNotEmpty) {
              onNewFollower(Map<String, dynamic>.from(payload.newRecord));
            }
          },
        )
        .subscribe();

    _channels[key] = channel;
    return channel;
  }

  // ─── Lifecycle ───────────────────────────────────────────────────────────

  void unsubscribe(String key) {
    _channels[key]?.unsubscribe();
    _channels.remove(key);
  }

  void unsubscribeAll() {
    for (final channel in _channels.values) {
      channel.unsubscribe();
    }
    _channels.clear();
  }
}
