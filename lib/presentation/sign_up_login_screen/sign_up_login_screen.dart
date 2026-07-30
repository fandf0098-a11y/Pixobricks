import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_export.dart';
import '../../core/logging/app_logger.dart';
import '../../core/security/input_validator.dart';
import '../../core/security/rate_limiter.dart';
import '../../providers/user_profile_provider.dart';

/// Sign Up / Login Screen — no AppBar, no BottomNav, no Drawer
/// Auth screen is outside the StatefulShellRoute shell
class SignUpLoginScreen extends ConsumerStatefulWidget {
  const SignUpLoginScreen({super.key});

  @override
  ConsumerState<SignUpLoginScreen> createState() => _SignUpLoginScreenState();
}

class _SignUpLoginScreenState extends ConsumerState<SignUpLoginScreen>
    with TickerProviderStateMixin {
  // Form state
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _nameController = TextEditingController();

  late AnimationController _bgController;
  late AnimationController _cardController;
  late AnimationController _particleController;
  late Animation<double> _cardEntrance;

  // Particle system
  final List<_Particle> _particles = [];
  static const int _particleCount = 18;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardEntrance = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    );

    _cardController.forward();

    // Generate particles
    final rng = math.Random(42);
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(
        _Particle(
          x: rng.nextDouble(),
          y: rng.nextDouble(),
          radius: rng.nextDouble() * 3 + 1.5,
          speed: rng.nextDouble() * 0.3 + 0.1,
          opacity: rng.nextDouble() * 0.5 + 0.2,
          phase: rng.nextDouble() * math.pi * 2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    _cardController.dispose();
    _particleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
    _cardController.reset();
    _cardController.forward();
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // ── Rate limiting ────────────────────────────────────────────────────
    final rateLimitKey = 'auth_${_emailController.text.trim().toLowerCase()}';
    if (!RateLimiter.checkAndRecord(rateLimitKey)) {
      final msg =
          RateLimiter.getLockoutMessage(rateLimitKey) ??
          'Too many attempts. Please try again later.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    // ── Sanitise inputs ──────────────────────────────────────────────────
    final email = InputValidator.sanitizeText(
      _emailController.text,
    ).toLowerCase();
    final password = _passwordController.text;
    final name = InputValidator.sanitizeText(_nameController.text);

    try {
      if (_isLogin) {
        AppLogger.authEvent('sign_in_attempt');
        await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        AppLogger.authEvent('sign_in_success');
      } else {
        AppLogger.authEvent('sign_up_attempt');
        await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': name},
        );
        AppLogger.authEvent('sign_up_success');
      }

      // Reset rate limiter on success
      RateLimiter.reset(rateLimitKey);

      if (mounted) {
        ref.read(userProfileProvider.notifier).loadProfile();
        setState(() => _isLoading = false);
        context.go(AppRoutes.homeScreen);
      }
    } on AuthException catch (e) {
      AppLogger.authError(_isLogin ? 'sign_in' : 'sign_up', e);
      if (mounted) {
        setState(() => _isLoading = false);
        // Show user-friendly message without leaking internal details
        final userMessage = _mapAuthError(e.message);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e, st) {
      AppLogger.error(
        'Auth unexpected error',
        error: e,
        stackTrace: st,
        context: 'sign_up_login',
      );
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Something went wrong. Please try again.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  /// Maps raw Supabase auth error messages to user-friendly strings.
  /// Avoids leaking internal implementation details to the UI.
  String _mapAuthError(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid email or password')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Please verify your email address before signing in.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already been registered')) {
      return 'An account with this email already exists. Try signing in.';
    }
    if (lower.contains('password should be at least')) {
      return 'Password must be at least 8 characters.';
    }
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (lower.contains('network') || lower.contains('connection')) {
      return 'Network error. Please check your connection and try again.';
    }
    return 'Authentication failed. Please try again.';
  }

  void _fillDemo() {
    _emailController.text = 'builder@buildverse.app';
    _passwordController.text = 'BrickMaster2026!';
    if (!_isLogin) {
      _nameController.text = 'Alex Builder';
      _confirmController.text = 'BrickMaster2026!';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      body: Stack(
        children: [
          // ── Animated gradient background ──────────────────────────────
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, _) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Color.lerp(
                              const Color(0xFF0D0B1E),
                              const Color(0xFF1A0B3E),
                              _bgController.value,
                            )!,
                            Color.lerp(
                              const Color(0xFF0B1A3E),
                              const Color(0xFF0D1A2E),
                              _bgController.value,
                            )!,
                          ]
                        : [
                            Color.lerp(
                              const Color(0xFFF0EEFF),
                              const Color(0xFFE8F4FF),
                              _bgController.value,
                            )!,
                            Color.lerp(
                              const Color(0xFFEEF0FF),
                              const Color(0xFFE4E8FF),
                              _bgController.value,
                            )!,
                          ],
                  ),
                ),
              );
            },
          ),

          // ── Particle field (V2 Splash — LOCKED) ──────────────────────
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) {
              return CustomPaint(
                size: size,
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                  isDark: isDark,
                ),
              );
            },
          ),

          // ── Decorative orbs ──────────────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(isDark ? 0.25 : 0.12),
                    AppTheme.primary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withOpacity(isDark ? 0.2 : 0.1),
                    AppTheme.secondary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isTablet ? 480 : double.infinity,
                  ),
                  child: FadeTransition(
                    opacity: _cardEntrance,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.08),
                        end: Offset.zero,
                      ).animate(_cardEntrance),
                      child: Column(
                        children: [
                          // Logo
                          _buildLogo(isDark),
                          const SizedBox(height: 32),

                          // Auth card
                          _buildAuthCard(isDark),

                          const SizedBox(height: 20),

                          // Demo credentials box
                          _buildDemoBox(isDark),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(102),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.view_in_ar_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 14),
        ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: Text(
            'BuildVerse',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Build. Scan. Create. Share.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withAlpha(128)
                : const Color(0xFF4A4870).withAlpha(179),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthCard(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        // LOCKED: Glassmorphism card — BackdropFilter blur
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(18)
                : Colors.white.withAlpha(179),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(26)
                  : AppTheme.primary.withAlpha(38),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tab toggle
              _buildTabToggle(isDark),
              const SizedBox(height: 28),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (!_isLogin) ...[
                      _buildGlassField(
                        controller: _nameController,
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        isDark: isDark,
                        validator: InputValidator.validateDisplayName,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildGlassField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.email_outlined,
                      isDark: isDark,
                      keyboardType: TextInputType.emailAddress,
                      validator: InputValidator.validateEmail,
                    ),
                    const SizedBox(height: 14),
                    _buildGlassField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      isDark: isDark,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: isDark
                              ? Colors.white.withAlpha(102)
                              : const Color(0xFF4A4870).withAlpha(128),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      validator: (v) => InputValidator.validatePassword(
                        v,
                        isSignUp: !_isLogin,
                      ),
                    ),
                    if (!_isLogin) ...[
                      const SizedBox(height: 14),
                      _buildGlassField(
                        controller: _confirmController,
                        label: 'Confirm Password',
                        icon: Icons.lock_outline_rounded,
                        isDark: isDark,
                        obscureText: _obscureConfirm,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                            color: isDark
                                ? Colors.white.withAlpha(102)
                                : const Color(0xFF4A4870).withAlpha(128),
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        validator: (v) =>
                            InputValidator.validateConfirmPassword(
                              v,
                              _passwordController.text,
                            ),
                      ),
                    ],
                  ],
                ),
              ),

              if (_isLogin) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ] else
                const SizedBox(height: 20),

              // Submit button
              _buildSubmitButton(),

              const SizedBox(height: 24),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? Colors.white.withAlpha(26)
                          : const Color(0xFF6C63FF).withAlpha(38),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or continue with',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white.withAlpha(102)
                            : const Color(0xFF4A4870).withAlpha(153),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: isDark
                          ? Colors.white.withAlpha(26)
                          : const Color(0xFF6C63FF).withAlpha(38),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Social buttons
              Row(
                children: [
                  Expanded(
                    child: _buildSocialButton(
                      label: 'Google',
                      icon: Icons.g_mobiledata_rounded,
                      isDark: isDark,
                      onTap: () {
                        // TODO: Replace with Google Sign-In
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSocialButton(
                      label: 'Apple',
                      icon: Icons.apple_rounded,
                      isDark: isDark,
                      onTap: () {
                        // TODO: Replace with Apple Sign-In
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Toggle link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? "Don't have an account? "
                        : 'Already have an account? ',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? Colors.white.withAlpha(128)
                          : const Color(0xFF4A4870).withAlpha(179),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleMode,
                    child: Text(
                      _isLogin ? 'Sign Up' : 'Sign In',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabToggle(bool isDark) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(13)
            : AppTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : AppTheme.primary.withAlpha(31),
        ),
      ),
      child: Row(
        children: [
          _buildToggleTab(
            'Sign In',
            isActive: _isLogin,
            onTap: () {
              if (!_isLogin) _toggleMode();
            },
          ),
          _buildToggleTab(
            'Sign Up',
            isActive: !_isLogin,
            onTap: () {
              if (_isLogin) _toggleMode();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab(
    String label, {
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(89),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive
                    ? Colors.white
                    : AppTheme.primary.withAlpha(153),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    // V5 Glassmorphism FormField — LOCKED: AnimatedContainer focus animation
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : const Color(0xFF1A1840),
      ),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: CustomIconWidget(
            iconName: icon.codePoint.toRadixString(16),
            color: isDark
                ? Colors.white.withAlpha(102)
                : const Color(0xFF4A4870).withAlpha(128),
            size: 20,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 48,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Ink(
          decoration: BoxDecoration(
            gradient: _isLoading ? null : AppTheme.primaryGradient,
            color: _isLoading ? AppTheme.primary.withAlpha(102) : null,
            borderRadius: BorderRadius.circular(999),
            boxShadow: _isLoading
                ? null
                : [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(102),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    _isLogin ? 'Sign In' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(15)
              : Colors.white.withAlpha(204),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(26)
                : AppTheme.primary.withAlpha(38),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 22,
              color: isDark ? Colors.white : const Color(0xFF1A1840),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoBox(bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(isDark ? 0.08 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.secondary.withAlpha(51)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Demo Credentials',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.secondary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _fillDemo,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withAlpha(38),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Auto-fill',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _demoRow('Email', 'builder@buildverse.app', isDark),
              const SizedBox(height: 4),
              _demoRow('Password', 'BrickMaster2026!', isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _demoRow(String label, String value, bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withAlpha(102)
                  : const Color(0xFF4A4870).withAlpha(153),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? Colors.white.withAlpha(179)
                  : const Color(0xFF1A1840),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Particle system ─────────────────────────────────────────────────────────

class _Particle {
  final double x;
  final double y;
  final double radius;
  final double speed;
  final double opacity;
  final double phase;

  const _Particle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
    required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final bool isDark;

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final t = (progress * p.speed + p.phase / (2 * math.pi)) % 1.0;
      final dy = math.sin(t * math.pi * 2) * 0.04;
      final dx = math.cos(t * math.pi * 2 + p.phase) * 0.02;

      final paint = Paint()
        ..color = (isDark ? AppTheme.primary : AppTheme.primary).withOpacity(
          p.opacity * (isDark ? 0.6 : 0.35),
        )
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset((p.x + dx) * size.width, (p.y + dy) * size.height),
        p.radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}
