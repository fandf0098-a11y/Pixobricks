import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cache/simple_cache.dart';
import '../core/logging/app_logger.dart';
import '../core/network/retry_helper.dart';
import '../services/supabase_service.dart';

/// Represents the current authenticated user's profile state
class UserProfileState {
  final Map<String, dynamic>? profile;
  final bool isLoading;
  final String? error;

  const UserProfileState({this.profile, this.isLoading = false, this.error});

  UserProfileState copyWith({
    Map<String, dynamic>? profile,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return UserProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  // Convenience getters
  String get displayName =>
      profile?['full_name'] as String? ??
      profile?['username'] as String? ??
      'Builder';
  String get username => profile?['username'] as String? ?? '';
  String? get avatarUrl => profile?['avatar_url'] as String?;
  int get level => profile?['experience_level'] as int? ?? 1;
  int get xp => profile?['xp'] as int? ?? 0;
  int get xpToNextLevel => profile?['xp_to_next_level'] as int? ?? 1000;
  double get xpProgress =>
      xpToNextLevel > 0 ? (xp / xpToNextLevel).clamp(0.0, 1.0) : 0.0;
  int get gems => profile?['gems'] as int? ?? 0;
  int get followers => profile?['followers_count'] as int? ?? 0;
  int get following => profile?['following_count'] as int? ?? 0;
  int get hoursBuilt => profile?['hours_built'] as int? ?? 0;
  int get piecesScanned => profile?['pieces_scanned'] as int? ?? 0;
  int get buildingStreak => profile?['building_streak'] as int? ?? 0;
  String get badge => profile?['badge'] as String? ?? '';
  String get badgeColor => profile?['badge_color'] as String? ?? '#6C63FF';
  String get experienceLevelLabel =>
      profile?['experience_level_label'] as String? ?? 'Beginner';
  List<String> get favouriteThemes {
    final raw = profile?['favourite_themes'];
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    return [];
  }
}

class UserProfileNotifier extends StateNotifier<UserProfileState> {
  UserProfileNotifier() : super(const UserProfileState()) {
    _init();
  }

  void _init() {
    final user = SupabaseService.instance.currentUser;
    if (user != null) {
      loadProfile();
    }
    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        loadProfile();
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = const UserProfileState();
      }
    });
  }

  Future<void> loadProfile() async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;

    // Return cached profile immediately while refreshing in background
    final cacheKey = 'user_profile_$userId';
    final cached = SimpleCache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      state = state.copyWith(profile: cached, isLoading: false);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await RetryHelper.retry(
        () => SupabaseService.instance.fetchCreatorProfile(userId),
        maxAttempts: 3,
      );
      SimpleCache.set(cacheKey, profile, ttl: const Duration(minutes: 10));
      state = state.copyWith(profile: profile, isLoading: false);
    } catch (e, st) {
      AppLogger.error('Failed to load user profile', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;
    try {
      await SupabaseService.instance.updateUserProfile(userId, updates);
      // Merge updates into current profile and refresh cache
      final updated = Map<String, dynamic>.from(state.profile ?? {})
        ..addAll(updates);
      SimpleCache.set(
        'user_profile_$userId',
        updated,
        ttl: const Duration(minutes: 10),
      );
      state = state.copyWith(profile: updated);
    } catch (e, st) {
      AppLogger.error(
        'Failed to update user profile',
        error: e,
        stackTrace: st,
      );
      state = state.copyWith(error: e.toString());
    }
  }

  void clearProfile() {
    state = const UserProfileState();
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfileState>(
      (ref) => UserProfileNotifier(),
    );
