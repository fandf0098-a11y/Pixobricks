import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import './core/cache/simple_cache.dart';
import './core/logging/app_logger.dart';
import './providers/auth_provider.dart';
import './services/offline_sync_service.dart';
import './services/supabase_service.dart';
import './widgets/offline_banner.dart';
import 'core/app_export.dart';
import 'providers/auth_provider.dart' hide AuthState;

void main() {
  // Wrap everything in a Zone to catch uncaught async errors
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ── Supabase ──────────────────────────────────────────────────────────
      try {
        await SupabaseService.initialize();
        AppLogger.info('Supabase initialised');
      } catch (e, st) {
        AppLogger.crash(
          'Failed to initialise Supabase',
          error: e,
          stackTrace: st,
        );
      }

      // ── Offline Sync ──────────────────────────────────────────────────────
      try {
        await OfflineSyncService.instance.initialize();
        AppLogger.info('OfflineSyncService initialised');
      } catch (e, st) {
        AppLogger.error(
          'Failed to initialise OfflineSyncService',
          error: e,
          stackTrace: st,
        );
      }

      // ── Cache eviction on startup ─────────────────────────────────────────
      SimpleCache.evictExpired();

      bool hasShownError = false;

      // 🚨 CRITICAL: Custom error handling - DO NOT REMOVE
      ErrorWidget.builder = (FlutterErrorDetails details) {
        AppLogger.error(
          'Flutter render error',
          error: details.exception,
          stackTrace: details.stack,
          context: details.context?.toString(),
        );

        if (!hasShownError) {
          hasShownError = true;
          Future.delayed(const Duration(seconds: 5), () {
            hasShownError = false;
          });
          return CustomErrorWidget(errorDetails: details);
        }
        return const SizedBox.shrink();
      };

      // ── Flutter framework error handler ───────────────────────────────────
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.crash(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack ?? StackTrace.empty,
          context: details.context?.toString(),
        );
        FlutterError.presentError(details);
      };

      // 🚨 CRITICAL: Device orientation lock - DO NOT REMOVE
      await Future.wait([
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
      ]);

      GoRouter.optionURLReflectsImperativeAPIs = true;
      runApp(const ProviderScope(child: MyApp()));
    },
    (error, stackTrace) {
      // Catch all uncaught async errors in the zone
      AppLogger.crash(
        'Uncaught async error',
        error: error,
        stackTrace: stackTrace,
      );
    },
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to auth state changes and refresh router
    ref.listen<AppAuthState>(authProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated) {
        appRouter.refresh();
      }
    });

    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp.router(
          title: 'buildverse',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          // 🚨 CRITICAL: NEVER REMOVE OR MODIFY
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.0)),
              child: OfflineBanner(child: child!),
            );
          },
          // 🚨 END CRITICAL SECTION
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
        );
      },
    );
  }
}
