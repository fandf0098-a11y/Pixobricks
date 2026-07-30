import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cache/simple_cache.dart';
import '../core/logging/app_logger.dart';
import '../core/network/retry_helper.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static Future<void> initialize() async {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be defined using --dart-define.',
      );
    }
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  SupabaseClient get client => Supabase.instance.client;

  // ─── Auth helpers ──────────────────────────────────────────────────────────
  User? get currentUser => client.auth.currentUser;
  String? get currentUserId => client.auth.currentUser?.id;

  // ─── INVENTORY ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchInventoryItems() async {
    final userId = currentUserId;
    if (userId == null) return [];

    // Return cached result if fresh
    final cacheKey = 'inventory_$userId';
    final cached = SimpleCache.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await RetryHelper.retry(
        () => client
            .from('inventory_items')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        maxAttempts: 3,
      );
      final result = List<Map<String, dynamic>>.from(response);
      SimpleCache.set(cacheKey, result, ttl: const Duration(minutes: 3));
      return result;
    } on PostgrestException catch (e) {
      AppLogger.networkError('inventory_items', e);
      throw Exception('Failed to fetch inventory: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> addInventoryItem(
    Map<String, dynamic> item,
  ) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    try {
      final response = await client
          .from('inventory_items')
          .insert({...item, 'user_id': userId})
          .select()
          .single();
      // Invalidate cache on mutation
      SimpleCache.invalidate('inventory_$userId');
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.networkError('inventory_items/insert', e);
      throw Exception('Failed to add inventory item: ${e.message}');
    }
  }

  Future<void> updateInventoryItem(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      await client
          .from('inventory_items')
          .update(updates)
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
      SimpleCache.invalidate('inventory_$currentUserId');
    } on PostgrestException catch (e) {
      AppLogger.networkError('inventory_items/update', e);
      throw Exception('Failed to update inventory item: ${e.message}');
    }
  }

  Future<void> deleteInventoryItem(String id) async {
    try {
      await client
          .from('inventory_items')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
      SimpleCache.invalidate('inventory_$currentUserId');
    } on PostgrestException catch (e) {
      AppLogger.networkError('inventory_items/delete', e);
      throw Exception('Failed to delete inventory item: ${e.message}');
    }
  }

  Future<void> toggleInventoryFavorite(String id, bool isFavorite) async {
    await updateInventoryItem(id, {'is_favorite': isFavorite});
  }

  // ─── AI BUILDS ─────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAiBuilds() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final cacheKey = 'ai_builds_$userId';
    final cached = SimpleCache.get<List<Map<String, dynamic>>>(cacheKey);
    if (cached != null) return cached;

    try {
      final response = await RetryHelper.retry(
        () => client
            .from('ai_builds')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false),
        maxAttempts: 3,
      );
      final result = List<Map<String, dynamic>>.from(response);
      SimpleCache.set(cacheKey, result, ttl: const Duration(minutes: 5));
      return result;
    } on PostgrestException catch (e) {
      AppLogger.networkError('ai_builds', e);
      throw Exception('Failed to fetch AI builds: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> saveAiBuild(Map<String, dynamic> build) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    try {
      final response = await client
          .from('ai_builds')
          .insert({...build, 'user_id': userId})
          .select()
          .single();
      SimpleCache.invalidate('ai_builds_$userId');
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      AppLogger.networkError('ai_builds/insert', e);
      throw Exception('Failed to save AI build: ${e.message}');
    }
  }

  Future<void> deleteAiBuild(String id) async {
    try {
      await client
          .from('ai_builds')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
      SimpleCache.invalidate('ai_builds_$currentUserId');
    } on PostgrestException catch (e) {
      AppLogger.networkError('ai_builds/delete', e);
      throw Exception('Failed to delete AI build: ${e.message}');
    }
  }

  // ─── POSTS ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchPosts({
    String? postType,
    String? orderBy,
    int limit = 20,
    int offset = 0,
  }) async {
    // Only cache first page of default feed
    final cacheKey =
        'posts_${postType ?? 'all'}_${orderBy ?? 'created_at'}_$offset';
    if (offset == 0) {
      final cached = SimpleCache.get<List<Map<String, dynamic>>>(cacheKey);
      if (cached != null) return cached;
    }

    try {
      var query = client
          .from('posts')
          .select(
            '*, user_profiles(id, full_name, username, avatar_url, badge, badge_color)',
          );

      if (postType != null) {
        query = query.eq('post_type', postType);
      }

      final col = orderBy ?? 'created_at';
      final response = await RetryHelper.retry(
        () => query
            .order(col, ascending: false)
            .range(offset, offset + limit - 1),
        maxAttempts: 3,
      );

      final result = List<Map<String, dynamic>>.from(response);
      if (offset == 0) {
        SimpleCache.set(cacheKey, result, ttl: const Duration(minutes: 2));
      }
      return result;
    } on PostgrestException catch (e) {
      AppLogger.networkError('posts', e);
      throw Exception('Failed to fetch posts: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createPost(Map<String, dynamic> post) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    try {
      final response = await client
          .from('posts')
          .insert({...post, 'user_id': userId})
          .select(
            '*, user_profiles(id, full_name, username, avatar_url, badge, badge_color)',
          )
          .single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create post: ${e.message}');
    }
  }

  Future<void> deletePost(String id) async {
    try {
      await client
          .from('posts')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete post: ${e.message}');
    }
  }

  // ─── LIKES ─────────────────────────────────────────────────────────────────

  Future<bool> isPostLiked(String postId) async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      final response = await client
          .from('post_likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> likePost(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client.from('post_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
      await client.rpc('increment_likes', params: {'post_uuid': postId});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // ignore duplicate
    }
  }

  Future<void> unlikePost(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client
          .from('post_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      await client.rpc('decrement_likes', params: {'post_uuid': postId});
    } on PostgrestException catch (e) {
      throw Exception('Failed to unlike post: ${e.message}');
    }
  }

  Future<Set<String>> fetchLikedPostIds() async {
    final userId = currentUserId;
    if (userId == null) return {};
    try {
      final response = await client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', userId);
      return Set<String>.from(
        (response as List).map((r) => r['post_id'] as String),
      );
    } catch (_) {
      return {};
    }
  }

  // ─── BOOKMARKS ─────────────────────────────────────────────────────────────

  Future<bool> isPostBookmarked(String postId) async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      final response = await client
          .from('post_bookmarks')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> bookmarkPost(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client.from('post_bookmarks').insert({
        'post_id': postId,
        'user_id': userId,
      });
      await client.rpc('increment_bookmarks', params: {'post_uuid': postId});
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> unbookmarkPost(String postId) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client
          .from('post_bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      await client.rpc('decrement_bookmarks', params: {'post_uuid': postId});
    } on PostgrestException catch (e) {
      throw Exception('Failed to unbookmark post: ${e.message}');
    }
  }

  Future<Set<String>> fetchBookmarkedPostIds() async {
    final userId = currentUserId;
    if (userId == null) return {};
    try {
      final response = await client
          .from('post_bookmarks')
          .select('post_id')
          .eq('user_id', userId);
      return Set<String>.from(
        (response as List).map((r) => r['post_id'] as String),
      );
    } catch (_) {
      return {};
    }
  }

  // ─── CREATOR PROFILES ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCreatorProfile(String userId) async {
    try {
      final response = await client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response != null ? Map<String, dynamic>.from(response) : null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch creator profile: ${e.message}');
    }
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      await client.from('user_profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to update user profile: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCreators({
    String? searchQuery,
    int limit = 20,
  }) async {
    try {
      var query = client.from('user_profiles').select();
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$searchQuery%,username.ilike.%$searchQuery%',
        );
      }
      final response = await query.order('xp', ascending: false).limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch creators: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCreatorPosts(String userId) async {
    try {
      final response = await client
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch creator posts: ${e.message}');
    }
  }

  Future<int> fetchFollowerCount(String userId) async {
    try {
      final response = await client
          .from('follows')
          .select('id')
          .eq('following_id', userId)
          .limit(0);
      return response.length;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> isFollowing(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return false;
    try {
      final response = await client
          .from('follows')
          .select('id')
          .eq('follower_id', userId)
          .eq('following_id', targetUserId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> followCreator(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client.from('follows').insert({
        'follower_id': userId,
        'following_id': targetUserId,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow;
    }
  }

  Future<void> unfollowCreator(String targetUserId) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client
          .from('follows')
          .delete()
          .eq('follower_id', userId)
          .eq('following_id', targetUserId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to unfollow: ${e.message}');
    }
  }

  Future<Set<String>> fetchFollowingIds() async {
    final userId = currentUserId;
    if (userId == null) return {};
    try {
      final response = await client
          .from('follows')
          .select('following_id')
          .eq('follower_id', userId);
      return Set<String>.from(
        (response as List).map((r) => r['following_id'] as String),
      );
    } catch (_) {
      return {};
    }
  }

  // ─── STORAGE ───────────────────────────────────────────────────────────────

  /// Upload avatar image. Returns public URL.
  Future<String> uploadAvatar(String filePath, List<int> bytes) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    final ext = filePath.split('.').last.toLowerCase();
    final storagePath = '$userId/avatar.$ext';
    try {
      await client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: true),
          );
      return client.storage.from('avatars').getPublicUrl(storagePath);
    } on StorageException catch (e) {
      throw Exception('Failed to upload avatar: ${e.message}');
    }
  }

  /// Upload post media (image/video). Returns public URL.
  Future<String> uploadPostMedia(String filePath, List<int> bytes) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = filePath.split('.').last.toLowerCase();
    final storagePath = '$userId/post_$ts.$ext';
    try {
      await client.storage
          .from('post-media')
          .uploadBinary(
            storagePath,
            Uint8List.fromList(bytes),
            fileOptions: const FileOptions(upsert: false),
          );
      return client.storage.from('post-media').getPublicUrl(storagePath);
    } on StorageException catch (e) {
      throw Exception('Failed to upload post media: ${e.message}');
    }
  }

  /// Delete a file from a storage bucket.
  Future<void> deleteStorageFile(String bucket, String path) async {
    try {
      await client.storage.from(bucket).remove([path]);
    } on StorageException catch (e) {
      throw Exception('Failed to delete file: ${e.message}');
    }
  }

  // ─── COMMENTS ──────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchComments(
    String postId, {
    String? parentId,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      var query = client
          .from('comments')
          .select(
            '*, user_profiles(id, full_name, username, avatar_url, badge, badge_color)',
          )
          .eq('post_id', postId);

      if (parentId != null) {
        query = query.eq('parent_id', parentId);
      } else {
        query = query.isFilter('parent_id', null);
      }

      final response = await query
          .order('created_at', ascending: true)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch comments: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    try {
      final response = await client
          .from('comments')
          .insert({
            'post_id': postId,
            'user_id': userId,
            'content': content,
            if (parentId != null) 'parent_id': parentId,
          })
          .select(
            '*, user_profiles(id, full_name, username, avatar_url, badge, badge_color)',
          )
          .single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to create comment: ${e.message}');
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await client
          .from('comments')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete comment: ${e.message}');
    }
  }

  Future<void> updateComment(String id, String content) async {
    try {
      await client
          .from('comments')
          .update({'content': content, 'is_edited': true})
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to update comment: ${e.message}');
    }
  }

  // ─── NOTIFICATIONS ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchNotifications({
    int limit = 30,
    int offset = 0,
    bool unreadOnly = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    try {
      var query = client
          .from('notifications')
          .select(
            '*, actor:user_profiles!actor_id(id, full_name, username, avatar_url)',
          )
          .eq('user_id', userId);

      if (unreadOnly) {
        query = query.eq('is_read', false);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch notifications: ${e.message}');
    }
  }

  Future<int> fetchUnreadNotificationCount() async {
    final userId = currentUserId;
    if (userId == null) return 0;
    try {
      final response = await client.rpc(
        'get_unread_notification_count',
        params: {'p_user_id': userId},
      );
      return (response as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await client
          .from('notifications')
          .update({'is_read': true})
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark notification read: ${e.message}');
    }
  }

  Future<void> markAllNotificationsRead() async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client.rpc(
        'mark_all_notifications_read',
        params: {'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw Exception('Failed to mark all notifications read: ${e.message}');
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await client
          .from('notifications')
          .delete()
          .eq('id', id)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to delete notification: ${e.message}');
    }
  }

  // ─── PUSH TOKENS ───────────────────────────────────────────────────────────

  Future<void> registerPushToken(String token, String platform) async {
    final userId = currentUserId;
    if (userId == null) return;
    try {
      await client.from('push_tokens').upsert({
        'user_id': userId,
        'token': token,
        'platform': platform,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,token');
    } on PostgrestException catch (e) {
      throw Exception('Failed to register push token: ${e.message}');
    }
  }

  Future<void> deactivatePushToken(String token) async {
    try {
      await client
          .from('push_tokens')
          .update({'is_active': false})
          .eq('token', token)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to deactivate push token: ${e.message}');
    }
  }

  // ─── BUILD SESSIONS ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> startBuildSession({String? aiBuildId}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    try {
      final response = await client
          .from('build_sessions')
          .insert({
            'user_id': userId,
            if (aiBuildId != null) 'ai_build_id': aiBuildId,
            'started_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to start build session: ${e.message}');
    }
  }

  Future<void> endBuildSession(
    String sessionId, {
    required int durationMin,
    int piecesUsed = 0,
    String notes = '',
  }) async {
    try {
      await client
          .from('build_sessions')
          .update({
            'ended_at': DateTime.now().toIso8601String(),
            'duration_min': durationMin,
            'pieces_used': piecesUsed,
            'notes': notes,
          })
          .eq('id', sessionId)
          .eq('user_id', currentUserId ?? '');
    } on PostgrestException catch (e) {
      throw Exception('Failed to end build session: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchBuildSessions({
    int limit = 20,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];
    try {
      final response = await client
          .from('build_sessions')
          .select('*, ai_builds(id, title, image_url)')
          .eq('user_id', userId)
          .order('started_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch build sessions: ${e.message}');
    }
  }

  // ─── COLLECTION ITEMS ──────────────────────────────────────────────────────

  Future<void> addPostToCollection(String collectionId, String postId) async {
    try {
      await client.from('collection_items').insert({
        'collection_id': collectionId,
        'post_id': postId,
      });
      await client
          .from('collections')
          .update({'piece_count': client.rpc('increment_collection_count')})
          .eq('id', collectionId);
    } on PostgrestException catch (e) {
      if (e.code != '23505') {
        throw Exception('Failed to add post to collection: ${e.message}');
      }
    }
  }

  Future<void> removePostFromCollection(
    String collectionId,
    String postId,
  ) async {
    try {
      await client
          .from('collection_items')
          .delete()
          .eq('collection_id', collectionId)
          .eq('post_id', postId);
    } on PostgrestException catch (e) {
      throw Exception('Failed to remove post from collection: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCollectionItems(
    String collectionId, {
    int limit = 30,
  }) async {
    try {
      final response = await client
          .from('collection_items')
          .select(
            '*, posts(*, user_profiles(id, full_name, username, avatar_url))',
          )
          .eq('collection_id', collectionId)
          .order('added_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch collection items: ${e.message}');
    }
  }

  // ─── POST REMIXES ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> remixPost({
    required String originalPostId,
    required Map<String, dynamic> newPost,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');
    try {
      // Create the new post
      final createdPost = await createPost({...newPost, 'user_id': userId});
      // Record the remix relationship
      await client.from('post_remixes').insert({
        'original_id': originalPostId,
        'remix_id': createdPost['id'],
      });
      return createdPost;
    } on PostgrestException catch (e) {
      throw Exception('Failed to remix post: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchPostRemixes(
    String originalPostId,
  ) async {
    try {
      final response = await client
          .from('post_remixes')
          .select(
            '*, posts!remix_id(*, user_profiles(id, full_name, username, avatar_url))',
          )
          .eq('original_id', originalPostId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch remixes: ${e.message}');
    }
  }

  // ─── APP CONFIG ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchAppConfig(String key) async {
    try {
      final response = await client
          .from('app_config')
          .select('value')
          .eq('key', key)
          .maybeSingle();
      return response != null
          ? Map<String, dynamic>.from(response['value'] as Map)
          : null;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch app config: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> fetchAllAppConfig() async {
    try {
      final response = await client.from('app_config').select('key, value');
      final result = <String, dynamic>{};
      for (final row in response as List) {
        result[row['key'] as String] = row['value'];
      }
      return result;
    } on PostgrestException catch (e) {
      throw Exception('Failed to fetch app config: ${e.message}');
    }
  }

  // ─── BACKUP ────────────────────────────────────────────────────────────────

  /// Calls the backup-user-data Edge Function and returns the JSON snapshot.
  Future<Map<String, dynamic>> exportUserBackup() async {
    try {
      final response = await client.functions.invoke('backup-user-data');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Unexpected backup response format');
    } catch (e) {
      throw Exception('Failed to export backup: $e');
    }
  }

  // ─── SYNC QUEUE (server-side) ──────────────────────────────────────────────

  /// Triggers the process-sync-queue Edge Function for server-side processing.
  Future<Map<String, dynamic>> triggerServerSyncQueue() async {
    try {
      final response = await client.functions.invoke('process-sync-queue');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'success': true};
    } catch (e) {
      throw Exception('Failed to trigger sync queue: $e');
    }
  }

  // ─── SEARCH ────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> globalSearch(String query) async {
    if (query.trim().isEmpty) return {'posts': [], 'creators': []};
    try {
      final postsQuery = client
          .from('posts')
          .select(
            'id, title, description, image_url, likes_count, post_type, user_profiles(id, full_name, username, avatar_url)',
          )
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('likes_count', ascending: false)
          .limit(10);

      final creatorsQuery = client
          .from('user_profiles')
          .select(
            'id, full_name, username, avatar_url, badge, xp, followers_count',
          )
          .or('full_name.ilike.%$query%,username.ilike.%$query%')
          .order('xp', ascending: false)
          .limit(10);

      final results = await Future.wait([postsQuery, creatorsQuery]);
      return {
        'posts': List<Map<String, dynamic>>.from(results[0] as List),
        'creators': List<Map<String, dynamic>>.from(results[1] as List),
      };
    } on PostgrestException catch (e) {
      throw Exception('Search failed: ${e.message}');
    }
  }
}
