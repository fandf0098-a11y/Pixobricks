import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import './widgets/profile_achievements_section.dart';
import './widgets/profile_collections_section.dart';
import './widgets/profile_stats_section.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isOwnProfile = false;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _achievements = [];
  List<Map<String, dynamic>> _collections = [];
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final targetId =
          widget.userId ?? SupabaseService.instance.currentUserId ?? '';
      _isOwnProfile = targetId == SupabaseService.instance.currentUserId;

      final results = await Future.wait(<Future<dynamic>>[
        SupabaseService.instance.fetchCreatorProfile(targetId),
        Future.value(<Map<String, dynamic>>[]),
        Future.value(<Map<String, dynamic>>[]),
        SupabaseService.instance.fetchCreatorPosts(targetId),
        if (!_isOwnProfile)
          SupabaseService.instance.isFollowing(targetId)
        else
          Future.value(false),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _achievements = results[1] as List<Map<String, dynamic>>;
          _collections = results[2] as List<Map<String, dynamic>>;
          _posts = results[3] as List<Map<String, dynamic>>;
          _isFollowing = results[4] as bool;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load profile. Pull to refresh.'),
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

  Future<void> _toggleFollow() async {
    HapticFeedback.lightImpact();
    final targetId = widget.userId ?? '';
    if (targetId.isEmpty) return;
    setState(() {
      _isFollowing = !_isFollowing;
    });
    try {
      if (_isFollowing) {
        await SupabaseService.instance.followCreator(targetId);
      } else {
        await SupabaseService.instance.unfollowCreator(targetId);
      }
    } catch (_) {
      setState(() => _isFollowing = !_isFollowing);
    }
  }

  String _fmt(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 1);
  }

  Color _expColor(String level) {
    switch (level) {
      case 'Master':
        return AppTheme.tertiary;
      case 'Expert':
        return AppTheme.warning;
      case 'Advanced':
        return AppTheme.secondary;
      case 'Intermediate':
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = _profile;
    final badgeColor = Color(p?['badge_color'] as int? ?? 0xFF6C63FF);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.backgroundGradientDark
                  : AppTheme.backgroundGradientLight,
            ),
          ),
          // Header glow
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    badgeColor.withAlpha(80),
                    AppTheme.primary.withAlpha(40),
                    Colors.transparent,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildContent(isDark, p, badgeColor),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, Map<String, dynamic>? p, Color badgeColor) {
    return Column(
      children: [
        _buildAppBar(isDark, p),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProfile,
            color: AppTheme.primary,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _buildAvatarSection(isDark, p, badgeColor),
                  const SizedBox(height: 16),
                  _buildFollowRow(isDark, p),
                  const SizedBox(height: 20),
                  _buildQuickStats(isDark, p),
                  const SizedBox(height: 20),
                  _buildExperienceStreak(isDark, p),
                  const SizedBox(height: 20),
                  _buildFavouriteThemes(isDark, p),
                  const SizedBox(height: 20),
                  _buildTabSection(isDark),
                  const SizedBox(height: 120),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(bool isDark, Map<String, dynamic>? p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Semantics(
              button: true,
              label: 'Go back',
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.white.withAlpha(180),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1840),
            ),
          ),
          const Spacer(),
          if (_isOwnProfile)
            GestureDetector(
              onTap: () => context.push('/edit-profile-screen'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.white.withAlpha(180),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.edit_rounded,
                  size: 18,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : Colors.white.withAlpha(180),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.share_rounded,
                  size: 18,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection(
    bool isDark,
    Map<String, dynamic>? p,
    Color badgeColor,
  ) {
    final avatarUrl = p?['avatar_url'] as String? ?? '';
    final name = p?['full_name'] as String? ?? 'Builder';
    final username = p?['username'] as String? ?? 'builder';
    final badge = p?['badge'] as String? ?? 'Builder';
    final bio = p?['bio'] as String? ?? '';

    return Column(
      children: [
        // Avatar
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            border: Border.all(color: badgeColor.withAlpha(160), width: 3),
            boxShadow: [
              BoxShadow(
                color: badgeColor.withAlpha(100),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    semanticLabel: 'Profile avatar of $name',
                    errorBuilder: (_, __, ___) => _avatarFallback(name),
                  )
                : _avatarFallback(name),
          ),
        ),
        const SizedBox(height: 12),
        // Name
        Text(
          name,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1A1840),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '@$username',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withAlpha(140)
                    : const Color(0xFF4A4870),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withAlpha(46),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: badgeColor,
                ),
              ),
            ),
          ],
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              bio,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: isDark
                    ? Colors.white.withAlpha(160)
                    : const Color(0xFF4A4870),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return Container(
      color: AppTheme.primaryContainer,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'B',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFollowRow(bool isDark, Map<String, dynamic>? p) {
    final followers = p?['followers_count'] as int? ?? 0;
    final following = p?['following_count'] as int? ?? 0;
    final xp = p?['xp'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _FollowStatItem(
              label: 'Followers',
              value: _fmt(followers),
              isDark: isDark,
            ),
          ),
          _VertDivider(isDark: isDark),
          Expanded(
            child: _FollowStatItem(
              label: 'Following',
              value: _fmt(following),
              isDark: isDark,
            ),
          ),
          _VertDivider(isDark: isDark),
          Expanded(
            child: _FollowStatItem(
              label: 'XP',
              value: _fmt(xp),
              isDark: isDark,
              color: AppTheme.xpColor,
            ),
          ),
          if (!_isOwnProfile) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _toggleFollow,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: _isFollowing ? null : AppTheme.primaryGradient,
                  color: _isFollowing
                      ? (isDark
                            ? Colors.white.withAlpha(15)
                            : Colors.white.withAlpha(160))
                      : null,
                  borderRadius: BorderRadius.circular(14),
                  border: _isFollowing
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withAlpha(30)
                              : AppTheme.primary.withAlpha(60),
                        )
                      : null,
                  boxShadow: _isFollowing
                      ? null
                      : [
                          BoxShadow(
                            color: AppTheme.primary.withAlpha(80),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Text(
                  _isFollowing ? '✓ Following' : '+ Follow',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _isFollowing
                        ? (isDark
                              ? Colors.white.withAlpha(200)
                              : const Color(0xFF4A4870))
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(bool isDark, Map<String, dynamic>? p) {
    final hoursBlt = p?['hours_built'] as num? ?? 0;
    final piecesScanned = p?['pieces_scanned'] as int? ?? 0;
    final projectsCount = p?['projects_count'] as int? ?? 0;
    final collectionsCount = p?['collections_count'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '📊 Stats',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
          ),
          // Bento grid — 2x2 asymmetric
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _StatCard(
                  icon: '⏱',
                  label: 'Hours Built',
                  value: _fmt(hoursBlt),
                  color: AppTheme.secondary,
                  isDark: isDark,
                  tall: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _StatCard(
                      icon: '🔍',
                      label: 'Pieces Scanned',
                      value: _fmt(piecesScanned),
                      color: AppTheme.tertiary,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _StatCard(
                      icon: '📦',
                      label: 'Projects',
                      value: _fmt(projectsCount),
                      color: AppTheme.success,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _StatCard(
            icon: '🗂',
            label: 'Collections',
            value: _fmt(collectionsCount),
            color: AppTheme.warning,
            isDark: isDark,
            wide: true,
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceStreak(bool isDark, Map<String, dynamic>? p) {
    final expLevel = p?['experience_level'] as String? ?? 'Beginner';
    final streak = p?['building_streak'] as int? ?? 0;
    final longestStreak = p?['longest_streak'] as int? ?? 0;
    final expColor = _expColor(expLevel);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Experience level
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: expColor.withAlpha(60), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: expColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            _expIcon(expLevel),
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Experience',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white.withAlpha(120)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    expLevel,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: expColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _expProgress(expLevel),
                      backgroundColor: expColor.withAlpha(30),
                      valueColor: AlwaysStoppedAnimation<Color>(expColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Building streak
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.white.withAlpha(180),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppTheme.warning.withAlpha(60),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('🔥', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Streak',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white.withAlpha(120)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '$streak',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.warning,
                          ),
                        ),
                        TextSpan(
                          text: ' days',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withAlpha(140)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Best: $longestStreak days',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withAlpha(100)
                          : const Color(0xFF4A4870).withAlpha(160),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _expIcon(String level) {
    switch (level) {
      case 'Master':
        return '🏆';
      case 'Expert':
        return '💎';
      case 'Advanced':
        return '⭐';
      case 'Intermediate':
        return '🔧';
      default:
        return '🌱';
    }
  }

  double _expProgress(String level) {
    switch (level) {
      case 'Master':
        return 1.0;
      case 'Expert':
        return 0.8;
      case 'Advanced':
        return 0.6;
      case 'Intermediate':
        return 0.4;
      default:
        return 0.2;
    }
  }

  Widget _buildFavouriteThemes(bool isDark, Map<String, dynamic>? p) {
    final themes =
        (p?['favourite_themes'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    if (themes.isEmpty) return const SizedBox.shrink();

    final themeColors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.tertiary,
      AppTheme.success,
      AppTheme.warning,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              '🎨 Favourite Themes',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: themes.asMap().entries.map((entry) {
              final color = themeColors[entry.key % themeColors.length];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Text(
                  entry.value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSection(bool isDark) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(12)
                : Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark
                ? Colors.white.withAlpha(120)
                : const Color(0xFF4A4870),
            tabs: const [
              Tab(text: 'Creations'),
              Tab(text: 'Collections'),
              Tab(text: 'Achievements'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 400,
          child: TabBarView(
            controller: _tabController,
            children: [
              ProfileStatsSection(posts: _posts, isDark: isDark),
              ProfileCollectionsSection(
                collections: _collections,
                isDark: isDark,
              ),
              ProfileAchievementsSection(
                achievements: _achievements,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FollowStatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? color;
  const _FollowStatItem({
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color ?? (isDark ? Colors.white : const Color(0xFF1A1840)),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isDark
                ? Colors.white.withAlpha(120)
                : const Color(0xFF4A4870),
          ),
        ),
      ],
    );
  }
}

class _VertDivider extends StatelessWidget {
  final bool isDark;
  const _VertDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: isDark
          ? Colors.white.withAlpha(30)
          : AppTheme.primary.withAlpha(40),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool tall;
  final bool wide;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.tall = false,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tall
          ? 130
          : wide
          ? 60
          : 60,
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 20 : 14,
        vertical: wide ? 0 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(12)
            : Colors.white.withAlpha(180),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withAlpha(50), width: 1),
      ),
      child: wide
          ? Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white.withAlpha(120)
                        : const Color(0xFF4A4870),
                  ),
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 16)),
                  ),
                ),
                if (tall) ...[
                  const Spacer(),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withAlpha(120)
                          : const Color(0xFF4A4870),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: isDark
                          ? Colors.white.withAlpha(120)
                          : const Color(0xFF4A4870),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
