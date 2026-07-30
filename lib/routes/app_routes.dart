import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../presentation/home_screen/home_screen.dart';
import '../presentation/sign_up_login_screen/sign_up_login_screen.dart';
import '../presentation/inventory_screen/inventory_screen.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/onboarding_screen/onboarding_screen.dart';
import '../presentation/ai_builder_screen/ai_builder_screen.dart';
import '../widgets/app_scaffold.dart';
import '../presentation/ai_assistant_screen/ai_assistant_screen.dart';
import '../presentation/ar_building_screen/ar_building_screen.dart';
import '../presentation/community_screen/community_screen.dart';
import '../presentation/creator_profile_screen/creator_profile_screen.dart';
import '../presentation/upload_creation_screen/upload_creation_screen.dart';
import '../presentation/profile_screen/profile_screen.dart';
import '../presentation/edit_profile_screen/edit_profile_screen.dart';

/// Route path string constants
class AppRoutes {
  AppRoutes._();

  /// Root — always literal '/'
  static const String initial = '/';

  /// Splash
  static const String splashScreen = '/splash';

  /// Onboarding
  static const String onboardingScreen = '/onboarding';

  /// Auth
  static const String signUpLoginScreen = '/sign-up-login-screen';

  /// Shell tabs
  static const String homeScreen = '/home-screen';
  static const String inventoryScreen = '/inventory-screen';
  static const String aiBuilderScreen = '/ai-builder-screen';
  static const String communityScreen = '/community-screen';
  static const String aiAssistantScreen = '/ai-assistant-screen';
  static const String arBuildingScreen = '/ar-building-screen';

  /// Community sub-routes
  static const String creatorProfileScreen = '/creator-profile-screen';
  static const String uploadCreationScreen = '/upload-creation-screen';

  /// Profile routes
  static const String profileScreen = '/profile-screen';
  static const String editProfileScreen = '/edit-profile-screen';

  /// Routes that require authentication
  static const Set<String> _protectedRoutes = {
    homeScreen,
    inventoryScreen,
    aiBuilderScreen,
    communityScreen,
    aiAssistantScreen,
    arBuildingScreen,
    creatorProfileScreen,
    uploadCreationScreen,
    profileScreen,
    editProfileScreen,
  };

  static bool isProtected(String location) {
    return _protectedRoutes.any((r) => location.startsWith(r));
  }
}

/// Top-level GoRouter instance
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.initial,
  redirect: (context, state) {
    final user = Supabase.instance.client.auth.currentUser;
    final location = state.matchedLocation;

    // Allow splash, onboarding, and auth screens without auth
    final isPublic =
        location == AppRoutes.initial ||
        location == AppRoutes.splashScreen ||
        location == AppRoutes.onboardingScreen ||
        location == AppRoutes.signUpLoginScreen;

    if (!isPublic && user == null) {
      // Redirect unauthenticated users to login
      return AppRoutes.signUpLoginScreen;
    }

    return null;
  },
  routes: [
    // ── Root → Splash ─────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.initial,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    ),

    // ── Splash ────────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.splashScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    ),

    // ── Onboarding ────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.onboardingScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const OnboardingScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
      ),
    ),

    // ── Auth screens (outside shell) ──────────────────────────────────────
    GoRoute(
      path: AppRoutes.signUpLoginScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const SignUpLoginScreen(),
        transitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    ),

    // ── AI Assistant (outside shell — full screen chat) ───────────────────
    GoRoute(
      path: AppRoutes.aiAssistantScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const AiAssistantScreen(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),

    // ── AR Building Assistant ─────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.arBuildingScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ArBuildingScreen(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    ),

    // ── Creator Profile ───────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.creatorProfileScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: CreatorProfileScreen(
          creator: state.extra as Map<String, dynamic>?,
        ),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),

    // ── Profile Screen ────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.profileScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: ProfileScreen(userId: state.extra as String?),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),

    // ── Edit Profile ──────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.editProfileScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const EditProfileScreen(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),

    // ── Upload Creation ───────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.uploadCreationScreen,
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const UploadCreationScreen(),
        transitionDuration: const Duration(milliseconds: 320),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(opacity: animation, child: child),
          );
        },
      ),
    ),

    // ── Shell — StatefulShellRoute.indexedStack for bottom nav ────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.homeScreen,
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const HomeScreen(),
                transitionDuration: const Duration(milliseconds: 280),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.inventoryScreen,
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const InventoryScreen(),
                transitionDuration: const Duration(milliseconds: 280),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.aiBuilderScreen,
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const AiBuilderScreen(),
                transitionDuration: const Duration(milliseconds: 280),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.communityScreen,
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const CommunityScreen(),
                transitionDuration: const Duration(milliseconds: 280),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.03, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
              ),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Temporary placeholder for screens not yet implemented in this build
class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String emoji;

  const _PlaceholderScreen({required this.title, required this.emoji});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.backgroundGradientDark
              : AppTheme.backgroundGradientLight,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming soon',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: isDark
                      ? Colors.white.withAlpha(102)
                      : const Color(0xFF4A4870),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
