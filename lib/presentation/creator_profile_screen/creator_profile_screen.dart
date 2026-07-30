import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class CreatorProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? creator;
  const CreatorProfileScreen({super.key, this.creator});

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  int _followerCount = 0;
  bool _isLoadingProfile = false;

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _posts = [];

  final List<Map<String, dynamic>> _badges = [
    {'icon': '🏆', 'label': 'Legend', 'color': 0xFF2ECC71},
    {'icon': '🔥', 'label': '42-Day Streak', 'color': 0xFFF39C12},
    {'icon': '⭐', 'label': 'Top Creator', 'color': 0xFFFFD700},
    {'icon': '🎯', 'label': '100 Posts', 'color': 0xFF6C63FF},
    {'icon': '💎', 'label': 'Diamond Tier', 'color': 0xFF00D4FF},
    {'icon': '🚀', 'label': 'Viral Post', 'color': 0xFFFF6B9D},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _isFollowing = (widget.creator?['isFollowing'] as bool?) ?? false;
    _followerCount = (widget.creator?['followers'] as int?) ?? 0;
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final creatorId = widget.creator?['id'] as String?;
    if (creatorId == null || creatorId.isEmpty) return;

    setState(() => _isLoadingProfile = true);
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchCreatorProfile(creatorId),
        SupabaseService.instance.fetchCreatorPosts(creatorId),
        SupabaseService.instance.fetchFollowerCount(creatorId),
        SupabaseService.instance.isFollowing(creatorId),
      ]);
      if (mounted) {
        setState(() {
          _profileData = results[0] as Map<String, dynamic>?;
          _posts = results[1] as List<Map<String, dynamic>>;
          _followerCount = results[2] as int;
          _isFollowing = results[3] as bool;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _toggleFollow() async {
    HapticFeedback.lightImpact();
    final creatorId = _creatorData['id'] as String?;
    if (creatorId == null || creatorId.isEmpty) return;

    setState(() {
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });
    try {
      if (_isFollowing) {
        await SupabaseService.instance.followCreator(creatorId);
      } else {
        await SupabaseService.instance.unfollowCreator(creatorId);
      }
    } catch (_) {
      setState(() {
        _isFollowing = !_isFollowing;
        _followerCount += _isFollowing ? 1 : -1;
      });
    }
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Map<String, dynamic> get _creatorData {
    if (_profileData != null) {
      return {
        'id': _profileData!['id'],
        'name': _profileData!['full_name'] ?? 'Builder',
        'username': '@${_profileData!['username'] ?? 'builder'}',
        'badge': _profileData!['badge'] ?? 'Builder',
        'badgeColor': _profileData!['badge_color'] ?? 0xFF6C63FF,
        'avatarUrl': _profileData!['avatar_url'] ?? '',
        'avatarLabel': 'Creator profile avatar',
        'posts': _posts.length,
        'xp': _profileData!['xp'] ?? 0,
        'streak': _profileData!['streak'] ?? 0,
      };
    }
    return widget.creator ??
        {
          'id': '',
          'name': 'BrickWizard',
          'username': '@brickwizard',
          'badge': 'Master Builder',
          'badgeColor': 0xFF6C63FF,
          'avatarUrl':
              'https://images.unsplash.com/photo-1531218532332-2ad238829d9a',
          'avatarLabel': 'Young man with glasses smiling',
          'posts': 112,
          'xp': 27800,
          'streak': 21,
        };
  }

  List<Map<String, dynamic>> get _normalizedPosts {
    return _posts
        .map(
          (p) => {
            'imageUrl': p['image_url'] as String? ?? '',
            'imageLabel':
                p['image_label'] as String? ?? p['title'] as String? ?? '',
            'likes': p['likes_count'] as int? ?? 0,
            'type': p['post_type'] as String? ?? 'project',
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final creator = _creatorData;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.backgroundGradientDark
                  : AppTheme.backgroundGradientLight,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(
                      creator['badgeColor'] as int? ?? 0xFF6C63FF,
                    ).withAlpha(89),
                    AppTheme.primary.withAlpha(51),
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                        ),
                      ),
                      const Spacer(),
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
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _isLoadingProfile
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              // Avatar
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppTheme.primaryGradient,
                                  border: Border.all(
                                    color: Color(
                                      creator['badgeColor'] as int? ??
                                          0xFF6C63FF,
                                    ).withAlpha(153),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(
                                        creator['badgeColor'] as int? ??
                                            0xFF6C63FF,
                                      ).withAlpha(89),
                                      blurRadius: 20,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    creator['avatarUrl'] as String? ??
                                        'https://images.pexels.com/photos/220453/pexels-photo-220453.jpeg?w=200&h=200&fit=crop',
                                    fit: BoxFit.cover,
                                    semanticLabel:
                                        creator['avatarLabel'] as String? ??
                                        'Creator avatar',
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Name & badge
                              Text(
                                creator['name'] as String? ?? 'Creator',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1840),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    creator['username'] as String? ??
                                        '@creator',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white.withAlpha(140)
                                          : const Color(0xFF4A4870),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(
                                        creator['badgeColor'] as int? ??
                                            0xFF6C63FF,
                                      ).withAlpha(46),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      creator['badge'] as String? ?? 'Builder',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(
                                          creator['badgeColor'] as int? ??
                                              0xFF6C63FF,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Stats row
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _StatItem(
                                      label: 'Posts',
                                      value: _formatCount(
                                        creator['posts'] as int? ?? 0,
                                      ),
                                      isDark: isDark,
                                    ),
                                    _StatDivider(isDark: isDark),
                                    _StatItem(
                                      label: 'Followers',
                                      value: _formatCount(_followerCount),
                                      isDark: isDark,
                                    ),
                                    _StatDivider(isDark: isDark),
                                    _StatItem(
                                      label: 'XP',
                                      value: _formatCount(
                                        creator['xp'] as int? ?? 0,
                                      ),
                                      isDark: isDark,
                                      color: AppTheme.xpColor,
                                    ),
                                    _StatDivider(isDark: isDark),
                                    _StatItem(
                                      label: 'Streak',
                                      value:
                                          '${creator['streak'] as int? ?? 0}d 🔥',
                                      isDark: isDark,
                                      color: AppTheme.warning,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Follow & Message buttons
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: GestureDetector(
                                        onTap: _toggleFollow,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          height: 42,
                                          decoration: BoxDecoration(
                                            gradient: _isFollowing
                                                ? null
                                                : AppTheme.primaryGradient,
                                            color: _isFollowing
                                                ? (isDark
                                                      ? Colors.white.withAlpha(
                                                          15,
                                                        )
                                                      : Colors.white.withAlpha(
                                                          160,
                                                        ))
                                                : null,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: _isFollowing
                                                ? Border.all(
                                                    color: isDark
                                                        ? Colors.white
                                                              .withAlpha(30)
                                                        : AppTheme.primary
                                                              .withAlpha(60),
                                                  )
                                                : null,
                                            boxShadow: _isFollowing
                                                ? null
                                                : [
                                                    BoxShadow(
                                                      color: AppTheme.primary
                                                          .withAlpha(89),
                                                      blurRadius: 12,
                                                      offset: const Offset(
                                                        0,
                                                        4,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Center(
                                            child: Text(
                                              _isFollowing
                                                  ? '✓ Following'
                                                  : '+ Follow',
                                              style:
                                                  GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: _isFollowing
                                                        ? (isDark
                                                              ? Colors.white
                                                                    .withAlpha(
                                                                      200,
                                                                    )
                                                              : const Color(
                                                                  0xFF4A4870,
                                                                ))
                                                        : Colors.white,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withAlpha(15)
                                              : Colors.white.withAlpha(160),
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: isDark
                                                ? Colors.white.withAlpha(30)
                                                : AppTheme.primary.withAlpha(
                                                    60,
                                                  ),
                                          ),
                                        ),
                                        child: Center(
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons
                                                    .chat_bubble_outline_rounded,
                                                size: 16,
                                                color: isDark
                                                    ? Colors.white.withAlpha(
                                                        200,
                                                      )
                                                    : const Color(0xFF4A4870),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Message',
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.white
                                                                .withAlpha(200)
                                                          : const Color(
                                                              0xFF4A4870,
                                                            ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Badges
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '🎖 Badges',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1840),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _badges.map((badge) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              badge['color'] as int,
                                            ).withAlpha(31),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Color(
                                                badge['color'] as int,
                                              ).withAlpha(77),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                badge['icon'] as String,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                badge['label'] as String,
                                                style:
                                                    GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Color(
                                                        badge['color'] as int,
                                                      ),
                                                    ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Posts grid
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '📸 Creations',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF1A1840),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _normalizedPosts.isEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            'No creations yet',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 13,
                                              color: isDark
                                                  ? Colors.white.withAlpha(128)
                                                  : const Color(0xFF4A4870),
                                            ),
                                          ),
                                        ),
                                      )
                                    : GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              crossAxisSpacing: 6,
                                              mainAxisSpacing: 6,
                                            ),
                                        itemCount: _normalizedPosts.length,
                                        itemBuilder: (context, index) {
                                          final post = _normalizedPosts[index];
                                          return _PostGridItem(
                                            post: post,
                                            isDark: isDark,
                                          );
                                        },
                                      ),
                              ),
                              const SizedBox(height: 120),
                            ],
                          ),
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

class _PostGridItem extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  const _PostGridItem({required this.post, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final imageUrl = post['imageUrl'] as String? ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  semanticLabel: post['imageLabel'] as String? ?? '',
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark
                        ? AppTheme.surfaceVariantDark
                        : AppTheme.surfaceVariantLight,
                    child: Icon(
                      Icons.image_outlined,
                      color: isDark
                          ? Colors.white.withAlpha(60)
                          : const Color(0xFF4A4870).withAlpha(80),
                    ),
                  ),
                )
              : Container(
                  color: isDark
                      ? AppTheme.surfaceVariantDark
                      : AppTheme.surfaceVariantLight,
                  child: Icon(
                    Icons.image_outlined,
                    color: isDark
                        ? Colors.white.withAlpha(60)
                        : const Color(0xFF4A4870).withAlpha(80),
                  ),
                ),
          if (post['type'] == 'video')
            const Center(
              child: Icon(
                Icons.play_circle_rounded,
                color: Colors.white70,
                size: 28,
              ),
            ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.favorite_rounded,
                  size: 10,
                  color: Colors.white70,
                ),
                const SizedBox(width: 2),
                Text(
                  _fmt(post['likes'] as int? ?? 0),
                  style: const TextStyle(
                    fontSize: 9,
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? color;
  const _StatItem({
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
            fontSize: 16,
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

class _StatDivider extends StatelessWidget {
  final bool isDark;
  const _StatDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: isDark
          ? Colors.white.withAlpha(30)
          : AppTheme.primary.withAlpha(40),
    );
  }
}
