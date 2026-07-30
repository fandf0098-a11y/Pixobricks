import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../services/supabase_service.dart';

class CommunityTrendingTab extends StatefulWidget {
  final bool isDark;
  const CommunityTrendingTab({super.key, required this.isDark});

  @override
  State<CommunityTrendingTab> createState() => _CommunityTrendingTabState();
}

class _CommunityTrendingTabState extends State<CommunityTrendingTab> {
  List<Map<String, dynamic>> _trendingPosts = [];
  bool _isLoading = false;

  static const List<Map<String, dynamic>> _trendingTags = [
    {'tag': 'StarWars', 'posts': 4821, 'color': 0xFF6C63FF},
    {'tag': 'Architecture', 'posts': 3210, 'color': 0xFF00D4FF},
    {'tag': 'SpeedBuild', 'posts': 2890, 'color': 0xFFFF6B9D},
    {'tag': 'Tutorial', 'posts': 2450, 'color': 0xFF2ECC71},
    {'tag': 'MicroBuild', 'posts': 1980, 'color': 0xFFF39C12},
    {'tag': 'Lighting', 'posts': 1650, 'color': 0xFF9B94FF},
  ];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final posts = await SupabaseService.instance.fetchPosts(
        orderBy: 'likes_count',
        limit: 10,
      );
      if (mounted) {
        setState(() {
          _trendingPosts = posts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCount(int n) =>
      n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  Map<String, dynamic> _normalizePost(Map<String, dynamic> raw, int rank) {
    final profile = raw['user_profiles'] as Map<String, dynamic>?;
    return {
      'rank': rank + 1,
      'title': raw['title'] as String? ?? '',
      'creator': profile?['full_name'] as String? ?? 'Builder',
      'likes': raw['likes_count'] as int? ?? 0,
      'imageUrl': raw['image_url'] as String? ?? '',
      'imageLabel': raw['image_label'] as String? ?? '',
      'type': raw['post_type'] as String? ?? 'project',
      'growth': '+${(rank + 1) * 40}%',
    };
  }

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final normalized = _trendingPosts
        .asMap()
        .entries
        .map((e) => _normalizePost(e.value, e.key))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadTrending,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          _SectionHeader(title: '🔥 Trending Tags', isDark: widget.isDark),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trendingTags.map((tag) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Color(tag['color'] as int).withAlpha(31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Color(tag['color'] as int).withAlpha(77),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#${tag['tag']}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(tag['color'] as int),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatCount(tag['posts'] as int),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: widget.isDark
                            ? Colors.white.withAlpha(120)
                            : const Color(0xFF4A4870),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: '📈 Top This Week', isDark: widget.isDark),
          const SizedBox(height: 10),
          if (normalized.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'No trending posts yet',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: widget.isDark
                        ? Colors.white.withAlpha(128)
                        : const Color(0xFF4A4870),
                  ),
                ),
              ),
            )
          else
            ...List.generate(normalized.length, (index) {
              final post = normalized[index];
              return _TrendingPostCard(
                post: post,
                isDark: widget.isDark,
                rankColor: _rankColor(post['rank'] as int),
                formatCount: _formatCount,
              );
            }),
        ],
      ),
    );
  }
}

class _TrendingPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  final Color rankColor;
  final String Function(int) formatCount;

  const _TrendingPostCard({
    required this.post,
    required this.isDark,
    required this.rankColor,
    required this.formatCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(18)
              : AppTheme.primary.withAlpha(25),
        ),
      ),
      child: Row(
        children: [
          // Rank
          Container(
            width: 48,
            height: 80,
            decoration: BoxDecoration(
              color: rankColor.withAlpha(31),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Center(
              child: Text(
                '#${post['rank']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: rankColor,
                ),
              ),
            ),
          ),
          // Image
          ClipRRect(
            child: Image.network(
              post['imageUrl'] as String,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              semanticLabel: post['imageLabel'] as String,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: isDark
                    ? AppTheme.surfaceVariantDark
                    : AppTheme.surfaceVariantLight,
              ),
            ),
          ),
          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post['title'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1840),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'by ${post['creator']}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white.withAlpha(120)
                          : const Color(0xFF4A4870),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 12,
                        color: AppTheme.tertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatCount(post['likes'] as int),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.tertiary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withAlpha(38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          post['growth'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionHeader({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: isDark ? Colors.white : const Color(0xFF1A1840),
      ),
    );
  }
}
