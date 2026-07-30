import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/cache/simple_cache.dart';
import '../core/logging/app_logger.dart';
import '../services/supabase_service.dart';

/// App-level auth state — tracks the current Supabase user
class AppAuthState {
  final User? user;
  final bool isLoading;
  final bool isInitialized;

  const AppAuthState({
    this.user,
    this.isLoading = false,
    this.isInitialized = false,
  });

  bool get isAuthenticated => user != null;

  AppAuthState copyWith({
    User? user,
    bool? isLoading,
    bool? isInitialized,
    bool clearUser = false,
  }) {
    return AppAuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier() : super(const AppAuthState()) {
    _init();
  }

  void _init() {
    final currentUser = SupabaseService.instance.currentUser;
    state = AppAuthState(user: currentUser, isInitialized: true);

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          AppLogger.authEvent(data.event.name, userId: data.session?.user.id);
          state = state.copyWith(user: data.session?.user, isInitialized: true);
          break;
        case AuthChangeEvent.signedOut:
          AppLogger.authEvent('signed_out');
          // Clear all caches on sign-out for security
          SimpleCache.clear();
          state = const AppAuthState(isInitialized: true);
          break;
        default:
          break;
      }
    });
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      AppLogger.authEvent('sign_out_attempt', userId: state.user?.id);
      await Supabase.instance.client.auth.signOut();
      SimpleCache.clear();
      state = const AppAuthState(isInitialized: true);
      AppLogger.authEvent('sign_out_success');
    } catch (e) {
      AppLogger.authError('sign_out', e);
      state = state.copyWith(isLoading: false);
    }
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>(
  (ref) => AuthNotifier(),
);

/// Simple stream provider for auth state changes
final authStateStreamProvider = StreamProvider<User?>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange.map(
    (event) => event.session?.user,
  );
});
