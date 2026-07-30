import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../services/supabase_service.dart';

class AiBuilderScreen extends StatefulWidget {
  const AiBuilderScreen({super.key});

  @override
  State<AiBuilderScreen> createState() => _AiBuilderScreenState();
}

class _AiBuilderScreenState extends State<AiBuilderScreen>
    with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isGenerating = false;
  bool _hasResult = false;
  int _selectedStyle = 0;

  late AnimationController _pulseController;
  late AnimationController _resultController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _resultSlide;
  late Animation<double> _resultOpacity;

  List<Map<String, dynamic>> _savedBuilds = [];
  List<_GeneratedBuild> _generatedBuilds = [];
  bool _isLoadingSaved = false;

  static const List<String> _suggestions = [
    '🏰 Medieval Castle',
    '🚀 Space Station',
    '🌆 Futuristic City',
    '🐉 Dragon',
    '🌉 Suspension Bridge',
    '🤖 Robot',
    '🏖️ Beach House',
    '⚔️ Knight Armor',
  ];

  static const List<_BuildStyle> _styles = [
    _BuildStyle(
      label: 'Classic',
      icon: Icons.star_rounded,
      color: Color(0xFF6C63FF),
    ),
    _BuildStyle(
      label: 'Technic',
      icon: Icons.settings_rounded,
      color: Color(0xFF00D4FF),
    ),
    _BuildStyle(
      label: 'Creator',
      icon: Icons.brush_rounded,
      color: Color(0xFFFF6B9D),
    ),
    _BuildStyle(
      label: 'City',
      icon: Icons.location_city_rounded,
      color: Color(0xFF2ECC71),
    ),
  ];

  static const List<_GeneratedBuild> _mockBuilds = [
    _GeneratedBuild(
      title: 'Medieval Castle',
      pieces: 847,
      difficulty: 'Advanced',
      time: '4-6 hrs',
      imageUrl:
          'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
      matchPercent: 94,
      color: Color(0xFF6C63FF),
    ),
    _GeneratedBuild(
      title: 'Castle Tower',
      pieces: 312,
      difficulty: 'Medium',
      time: '1-2 hrs',
      imageUrl:
          'https://images.pexels.com/photos/1643383/pexels-photo-1643383.jpeg?w=400',
      matchPercent: 87,
      color: Color(0xFF00D4FF),
    ),
    _GeneratedBuild(
      title: 'Mini Fortress',
      pieces: 156,
      difficulty: 'Easy',
      time: '30 min',
      imageUrl:
          'https://images.pixabay.com/photo/2016/11/29/09/16/architecture-1868667_640.jpg',
      matchPercent: 79,
      color: Color(0xFFFF6B9D),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _resultSlide = Tween<double>(begin: 60, end: 0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.easeOutCubic),
    );
    _resultOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.easeOut),
    );
    _loadSavedBuilds();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _focusNode.dispose();
    _pulseController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedBuilds() async {
    setState(() => _isLoadingSaved = true);
    try {
      final builds = await SupabaseService.instance.fetchAiBuilds();
      if (mounted) {
        setState(() {
          _savedBuilds = builds;
          _isLoadingSaved = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSaved = false);
    }
  }

  Future<void> _generate() async {
    if (_promptController.text.trim().isEmpty) return;
    _focusNode.unfocus();
    setState(() {
      _isGenerating = true;
      _hasResult = false;
    });
    _resultController.reset();
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) {
      // Generate mock results based on prompt
      final prompt = _promptController.text.trim();
      final styleName = _styles[_selectedStyle].label;
      _generatedBuilds = [
        _GeneratedBuild(
          title: prompt,
          pieces: 847,
          difficulty: 'Advanced',
          time: '4-6 hrs',
          imageUrl:
              'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
          matchPercent: 94,
          color: _styles[_selectedStyle].color,
        ),
        _GeneratedBuild(
          title: '$prompt (Compact)',
          pieces: 312,
          difficulty: 'Medium',
          time: '1-2 hrs',
          imageUrl:
              'https://images.pexels.com/photos/1643383/pexels-photo-1643383.jpeg?w=400',
          matchPercent: 87,
          color: const Color(0xFF00D4FF),
        ),
        _GeneratedBuild(
          title: 'Mini $prompt',
          pieces: 156,
          difficulty: 'Easy',
          time: '30 min',
          imageUrl:
              'https://images.pixabay.com/photo/2016/11/29/09/16/architecture-1868667_640.jpg',
          matchPercent: 79,
          color: const Color(0xFFFF6B9D),
        ),
      ];

      // Auto-save the top result to Supabase
      try {
        await SupabaseService.instance.saveAiBuild({
          'prompt': prompt,
          'style': styleName,
          'title': prompt,
          'pieces': 847,
          'difficulty': 'Advanced',
          'build_time': '4-6 hrs',
          'image_url':
              'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400',
          'match_percent': 94,
          'accent_color': _styles[_selectedStyle].color.value,
          'is_saved': false,
        });
        await _loadSavedBuilds();
      } catch (_) {
        // Non-critical — continue showing results
      }

      setState(() {
        _isGenerating = false;
        _hasResult = true;
      });
      _resultController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.backgroundGradientDark
                  : AppTheme.backgroundGradientLight,
            ),
          ),

          // Top accent orb
          Positioned(
            top: -80,
            left: -40,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.primary.withAlpha(51), Colors.transparent],
                ),
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              slivers: [
                // App bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: isDark
                                ? Colors.white.withAlpha(20)
                                : Colors.white.withAlpha(179),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(31)
                                  : AppTheme.primary.withAlpha(51),
                            ),
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'AI Builder',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1840),
                                ),
                              ),
                              Text(
                                'Describe your dream build',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white.withAlpha(128)
                                      : const Color(0xFF4A4870),
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              context.push(AppRoutes.aiAssistantScreen),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withAlpha(80),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.smart_toy_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AI Chat',
                                  style: GoogleFonts.manrope(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GlassChip(
                          label: '✨ Pro',
                          isDark: isDark,
                          color: AppTheme.tertiary,
                        ),
                      ],
                    ),
                  ),
                ),

                // Prompt input card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: _PromptInputCard(
                      controller: _promptController,
                      focusNode: _focusNode,
                      isDark: isDark,
                      isGenerating: _isGenerating,
                      onGenerate: _generate,
                      pulseAnimation: _pulseAnimation,
                    ),
                  ),
                ),

                // Style selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Build Style',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withAlpha(179)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 20),
                            itemCount: _styles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final s = _styles[i];
                              final isSelected = i == _selectedStyle;
                              return GestureDetector(
                                onTap: () => setState(() => _selectedStyle = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    color: isSelected
                                        ? s.color.withAlpha(51)
                                        : (isDark
                                              ? Colors.white.withAlpha(15)
                                              : Colors.white.withAlpha(179)),
                                    border: Border.all(
                                      color: isSelected
                                          ? s.color.withAlpha(153)
                                          : (isDark
                                                ? Colors.white.withAlpha(31)
                                                : const Color(0xFFDDDBFF)),
                                      width: isSelected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        s.icon,
                                        size: 14,
                                        color: isSelected
                                            ? s.color
                                            : (isDark
                                                  ? Colors.white.withAlpha(128)
                                                  : const Color(0xFF4A4870)),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        s.label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? s.color
                                              : (isDark
                                                    ? Colors.white.withAlpha(
                                                        153,
                                                      )
                                                    : const Color(0xFF4A4870)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Suggestions
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Ideas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white.withAlpha(179)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 38,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.only(right: 20),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              return GestureDetector(
                                onTap: () {
                                  _promptController.text = _suggestions[i]
                                      .substring(2);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: isDark
                                        ? Colors.white.withAlpha(15)
                                        : Colors.white.withAlpha(204),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withAlpha(26)
                                          : const Color(0xFFDDDBFF),
                                    ),
                                  ),
                                  child: Text(
                                    _suggestions[i],
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? Colors.white.withAlpha(179)
                                          : const Color(0xFF4A4870),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Generating indicator
                if (_isGenerating)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                      child: _GeneratingIndicator(isDark: isDark),
                    ),
                  ),

                // Results
                if (_hasResult) ...[
                  SliverToBoxAdapter(
                    child: AnimatedBuilder(
                      animation: _resultController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _resultOpacity.value,
                          child: Transform.translate(
                            offset: Offset(0, _resultSlide.value),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                        child: Row(
                          children: [
                            Text(
                              'Generated Builds',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1840),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: AppTheme.primary.withAlpha(38),
                              ),
                              child: Text(
                                '${_generatedBuilds.length}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return AnimatedBuilder(
                        animation: _resultController,
                        builder: (context, child) {
                          final delay = index * 0.15;
                          final t = (_resultController.value - delay).clamp(
                            0.0,
                            1.0,
                          );
                          return Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, (1 - t) * 40),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            index == _generatedBuilds.length - 1 ? 120 : 0,
                          ),
                          child: _BuildResultCard(
                            build: _generatedBuilds[index],
                            isDark: isDark,
                          ),
                        ),
                      );
                    }, childCount: _generatedBuilds.length),
                  ),
                ],

                if (!_isGenerating && !_hasResult)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
                      child: _EmptyPromptState(isDark: isDark),
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

class _PromptInputCard extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final Animation<double> pulseAnimation;

  const _PromptInputCard({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.isGenerating,
    required this.onGenerate,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.white.withAlpha(179),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(31)
                  : AppTheme.primary.withAlpha(51),
            ),
          ),
          child: Column(
            children: [
              TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 3,
                minLines: 2,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
                decoration: InputDecoration(
                  hintText:
                      'Describe your build... e.g. "A medieval castle with a drawbridge and towers"',
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: isDark
                        ? Colors.white.withAlpha(89)
                        : const Color(0xFF4A4870).withAlpha(128),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _GlassChip(
                    label: '🎯 Match to inventory',
                    isDark: isDark,
                    color: AppTheme.secondary,
                  ),
                  const Spacer(),
                  _GenerateButton(
                    isGenerating: isGenerating,
                    onTap: onGenerate,
                    pulseAnimation: pulseAnimation,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenerateButton extends StatefulWidget {
  final bool isGenerating;
  final VoidCallback onTap;
  final Animation<double> pulseAnimation;

  const _GenerateButton({
    required this.isGenerating,
    required this.onTap,
    required this.pulseAnimation,
  });

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.92,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.reverse(),
      onTapUp: (_) {
        _scaleController.forward();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.forward(),
      child: ScaleTransition(
        scale: _scaleController,
        child: AnimatedBuilder(
          animation: widget.pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isGenerating ? widget.pulseAnimation.value : 1.0,
              child: child,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(102),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.isGenerating
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                const SizedBox(width: 8),
                Text(
                  widget.isGenerating ? 'Building...' : 'Generate',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuildResultCard extends StatefulWidget {
  final _GeneratedBuild build;
  final bool isDark;

  const _BuildResultCard({required this.build, required this.isDark});

  @override
  State<_BuildResultCard> createState() => _BuildResultCardState();
}

class _BuildResultCardState extends State<_BuildResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.build;
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _hoverController.reverse();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _hoverController.forward();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _hoverController.forward();
      },
      child: ScaleTransition(
        scale: _hoverController,
        child: Hero(
          tag: 'build_${b.title}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: widget.isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.white.withAlpha(204),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withAlpha(26)
                        : const Color(0xFFDDDBFF),
                  ),
                ),
                child: Row(
                  children: [
                    // Image
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      child: Image.network(
                        b.imageUrl,
                        width: 100,
                        height: 110,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 100,
                          height: 110,
                          color: b.color.withAlpha(51),
                          child: Icon(
                            Icons.construction_rounded,
                            color: b.color,
                            size: 32,
                          ),
                        ),
                      ),
                    ),

                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    b.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isDark
                                          ? Colors.white
                                          : const Color(0xFF1A1840),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: b.color.withAlpha(38),
                                  ),
                                  child: Text(
                                    '${b.matchPercent}%',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: b.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _InfoChip(
                                  icon: Icons.category_rounded,
                                  label: '${b.pieces} pcs',
                                  isDark: widget.isDark,
                                ),
                                _InfoChip(
                                  icon: Icons.timer_rounded,
                                  label: b.time,
                                  isDark: widget.isDark,
                                ),
                                _InfoChip(
                                  icon: Icons.bar_chart_rounded,
                                  label: b.difficulty,
                                  isDark: widget.isDark,
                                  color: b.difficulty == 'Easy'
                                      ? AppTheme.success
                                      : b.difficulty == 'Medium'
                                      ? AppTheme.warning
                                      : AppTheme.error,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    label: 'Build Now',
                                    color: b.color,
                                    onTap: () {},
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _IconActionButton(
                                  icon: Icons.bookmark_border_rounded,
                                  isDark: widget.isDark,
                                  onTap: () {},
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        (isDark ? Colors.white.withAlpha(128) : const Color(0xFF4A4870));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: c),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: c,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(colors: [color, color.withAlpha(179)]),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _IconActionButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDark
              ? Colors.white.withAlpha(20)
              : Colors.white.withAlpha(153),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(31)
                : const Color(0xFFDDDBFF),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white.withAlpha(153) : const Color(0xFF4A4870),
        ),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color color;

  const _GlassChip({
    required this.label,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withAlpha(31),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _GeneratingIndicator extends StatefulWidget {
  final bool isDark;
  const _GeneratingIndicator({required this.isDark});

  @override
  State<_GeneratingIndicator> createState() => _GeneratingIndicatorState();
}

class _GeneratingIndicatorState extends State<_GeneratingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _dotCount = (_dotCount + 1) % 4);
            _controller.reset();
            _controller.forward();
          }
        });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.isDark
                ? Colors.white.withAlpha(13)
                : Colors.white.withAlpha(179),
            border: Border.all(color: AppTheme.primary.withAlpha(77)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.secondary],
                  ),
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI is designing your build${'.' * _dotCount}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? Colors.white
                            : const Color(0xFF1A1840),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        backgroundColor: AppTheme.primary.withAlpha(38),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPromptState extends StatelessWidget {
  final bool isDark;
  const _EmptyPromptState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('✨', style: TextStyle(fontSize: 56)),
        const SizedBox(height: 16),
        Text(
          'Describe anything',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1840),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Type a description or pick a quick idea above.\nOur AI will generate builds using your inventory.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark
                ? Colors.white.withAlpha(115)
                : const Color(0xFF4A4870).withAlpha(179),
            height: 1.6,
          ),
        ),
      ],
    );
  }
}

class _BuildStyle {
  final String label;
  final IconData icon;
  final Color color;

  const _BuildStyle({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _GeneratedBuild {
  final String title;
  final int pieces;
  final String difficulty;
  final String time;
  final String imageUrl;
  final int matchPercent;
  final Color color;

  const _GeneratedBuild({
    required this.title,
    required this.pieces,
    required this.difficulty,
    required this.time,
    required this.imageUrl,
    required this.matchPercent,
    required this.color,
  });
}
