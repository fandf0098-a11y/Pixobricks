import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  static const String _onboardingKey = 'bv_onboarding_complete';

  static const List<_OnboardingPage> _pages = [
    _OnboardingPage(
      emoji: '🧱',
      title: 'Scan Your Bricks',
      subtitle:
          'Point your camera at any brick collection and our AI instantly identifies, counts, and catalogues every piece.',
      gradient: [Color(0xFF6C63FF), Color(0xFF9B94FF)],
      accentColor: Color(0xFF6C63FF),
      tag: 'onboard_scan',
    ),
    _OnboardingPage(
      emoji: '🤖',
      title: 'AI-Powered Builds',
      subtitle:
          'Describe your dream creation and watch our AI generate step-by-step building instructions using only your available bricks.',
      gradient: [Color(0xFF00D4FF), Color(0xFF0099BB)],
      accentColor: Color(0xFF00D4FF),
      tag: 'onboard_ai',
    ),
    _OnboardingPage(
      emoji: '🥽',
      title: 'Build in AR',
      subtitle:
          'See your creation come to life in augmented reality before you build it. Place, rotate, and scale in your real world.',
      gradient: [Color(0xFFFF6B9D), Color(0xFFD44080)],
      accentColor: Color(0xFFFF6B9D),
      tag: 'onboard_ar',
    ),
    _OnboardingPage(
      emoji: '🌍',
      title: 'Share with the World',
      subtitle:
          'Join millions of builders. Share your creations, discover community builds, and compete in daily challenges.',
      gradient: [Color(0xFF2ECC71), Color(0xFF1A9E55)],
      accentColor: Color(0xFF2ECC71),
      tag: 'onboard_community',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _markOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
    } catch (_) {
      // Non-critical — proceed even if prefs fail
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
      );
    } else {
      _markOnboardingComplete();
      context.go(AppRoutes.signUpLoginScreen);
    }
  }

  void _skip() {
    _markOnboardingComplete();
    context.go(AppRoutes.signUpLoginScreen);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Stack(
        children: [
          // Animated background
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.backgroundDark,
                  page.accentColor.withAlpha(38),
                  AppTheme.backgroundDark,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // Decorative orb
          Positioned(
            top: -60,
            right: -60,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [page.accentColor.withAlpha(64), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo
                      Hero(
                        tag: 'buildverse_logo',
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                              colors: [AppTheme.primary, AppTheme.secondary],
                            ),
                          ),
                          child: const Center(
                            child: Text('🧱', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Skip onboarding',
                        child: TextButton(
                          onPressed: _skip,
                          child: Text(
                            'Skip',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withAlpha(128),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final p = _pages[index];
                      return _OnboardingPageView(
                        page: p,
                        floatAnimation: _floatAnimation,
                        isTablet: isTablet,
                      );
                    },
                  ),
                ),

                // Bottom controls
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    MediaQuery.of(context).padding.bottom + 32,
                  ),
                  child: Column(
                    children: [
                      // Page indicators
                      Semantics(
                        label: 'Page ${_currentPage + 1} of ${_pages.length}',
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_pages.length, (i) {
                            final isActive = i == _currentPage;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: isActive ? 28 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                color: isActive
                                    ? page.accentColor
                                    : Colors.white.withAlpha(51),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // CTA button
                      _AnimatedButton(
                        onTap: _nextPage,
                        gradient: LinearGradient(colors: page.gradient),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentPage == _pages.length - 1
                                  ? "Let's Build!"
                                  : 'Continue',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Onboarding page view ──────────────────────────────────────────────────────

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;
  final Animation<double> floatAnimation;
  final bool isTablet;

  const _OnboardingPageView({
    required this.page,
    required this.floatAnimation,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 64 : 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Floating emoji illustration
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (context, _) {
              return Transform.translate(
                offset: Offset(0, floatAnimation.value),
                child: Hero(
                  tag: page.tag,
                  child: Container(
                    width: isTablet ? 180 : 140,
                    height: isTablet ? 180 : 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: page.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.accentColor.withAlpha(77),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        page.emoji,
                        style: TextStyle(fontSize: isTablet ? 72 : 56),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: isTablet ? 48 : 40),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTablet ? 32 : 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: isTablet ? 16 : 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withAlpha(179),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated button ───────────────────────────────────────────────────────────

class _AnimatedButton extends StatefulWidget {
  final VoidCallback onTap;
  final LinearGradient gradient;
  final Widget child;

  const _AnimatedButton({
    required this.onTap,
    required this.gradient,
    required this.child,
  });

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.reverse(),
      onTapUp: (_) {
        _controller.forward();
        widget.onTap();
      },
      onTapCancel: () => _controller.forward(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withAlpha(77),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color accentColor;
  final String tag;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accentColor,
    required this.tag,
  });
}
