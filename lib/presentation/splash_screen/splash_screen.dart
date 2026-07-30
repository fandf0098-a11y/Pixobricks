import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _particleController;
  late AnimationController _textController;
  late AnimationController _exitController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _glowPulse;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _exitOpacity;

  final List<_Particle> _particles = [];
  final math.Random _random = math.Random();

  static const String _onboardingKey = 'bv_onboarding_complete';

  @override
  void initState() {
    super.initState();
    _generateParticles();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _glowPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.easeInOut),
    );
    _textOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _startSequence();
  }

  void _generateParticles() {
    for (int i = 0; i < 20; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size: _random.nextDouble() * 6 + 2,
          speed: _random.nextDouble() * 0.3 + 0.1,
          opacity: _random.nextDouble() * 0.6 + 0.2,
          color: _random.nextBool() ? AppTheme.primary : AppTheme.secondary,
        ),
      );
    }
  }

  Future<bool> _hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_onboardingKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 900));
    _textController.forward();
    await Future.delayed(const Duration(milliseconds: 1800));
    _exitController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        context.go(AppRoutes.homeScreen);
      } else {
        final onboardingDone = await _hasCompletedOnboarding();
        if (mounted) {
          if (onboardingDone) {
            context.go(AppRoutes.signUpLoginScreen);
          } else {
            context.go(AppRoutes.onboardingScreen);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _particleController.dispose();
    _textController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: AppTheme.backgroundGradientDark,
              ),
            ),

            // Animated particles
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: _ParticlePainter(
                    particles: _particles,
                    progress: _particleController.value,
                  ),
                );
              },
            ),

            // Glow orb behind logo
            Center(
              child: AnimatedBuilder(
                animation: _glowPulse,
                builder: (context, _) {
                  return Container(
                    width: 200 * _glowPulse.value,
                    height: 200 * _glowPulse.value,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primary.withOpacity(0.3 * _glowPulse.value),
                          AppTheme.secondary.withOpacity(
                            0.1 * _glowPulse.value,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Logo + text center
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo mark
                  AnimatedBuilder(
                    animation: _logoController,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Hero(
                            tag: 'buildverse_logo',
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primary,
                                    AppTheme.secondary,
                                    AppTheme.tertiary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primary.withAlpha(128),
                                    blurRadius: 40,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: AppTheme.secondary.withAlpha(77),
                                    blurRadius: 60,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '🧱',
                                  style: TextStyle(fontSize: 48),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // App name
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textOpacity,
                      child: Column(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppTheme.primaryGradient.createShader(bounds),
                            child: Text(
                              'BuildVerse',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Build. Scan. Create.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withAlpha(128),
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Particle system ───────────────────────────────────────────────────────────

class _Particle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;
  final Color color;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  const _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y - p.speed * progress) % 1.0;
      final paint = Paint()
        ..color = p.color.withOpacity(
          p.opacity * (1 - (y - 0.5).abs() * 2).clamp(0.0, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
