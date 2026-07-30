import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class CommunityLeaderboardTab extends StatefulWidget {
  final bool isDark;
  const CommunityLeaderboardTab({super.key, required this.isDark});

  @override
  State<CommunityLeaderboardTab> createState() =>
      _CommunityLeaderboardTabState();
}

class _CommunityLeaderboardTabState extends State<CommunityLeaderboardTab> {
  String _period = 'Weekly';
  final List<String> _periods = ['Weekly', 'Monthly', 'All Time'];
  List<Map<String, dynamic>> _creators = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final data = await SupabaseService.instance.fetchCreators(limit: 20);
      if (mounted) {
        setState(() {
          _creators = data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatXP(int xp) {
    if (xp >= 1000) return '${(xp / 1000).toStringAsFixed(1)}k XP';
    return '$xp XP';
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Map<String, dynamic> _enrichCreator(Map<String, dynamic> raw, int rank) {
    return {
      ...raw,
      'rank': rank + 1,
      'name': raw['full_name'] as String? ?? 'Builder',
      'username': '@${raw['username'] as String? ?? 'builder'}',
      'xp': raw['xp'] as int? ?? 0,
      'badge': raw['badge'] as String? ?? 'Builder',
      'badgeColor': raw['badge_color'] as int? ?? 0xFF6C63FF,
      'avatarUrl': raw['avatar_url'] as String? ?? '',
      'avatarLabel': 'Creator avatar',
      'streak': raw['streak'] as int? ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final enriched = _creators
        .asMap()
        .entries
        .map((e) => _enrichCreator(e.value, e.key))
        .toList();

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppTheme.primary,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          Row(
            children: _periods.map((p) {
              final isActive = p == _period;
              return GestureDetector(
                onTap: () => setState(() => _period = p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppTheme.primaryGradient : null,
                    color: isActive
                        ? null
                        : (widget.isDark
                              ? Colors.white.withAlpha(15)
                              : Colors.white.withAlpha(160)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? Colors.transparent
                          : (widget.isDark
                                ? Colors.white.withAlpha(25)
                                : AppTheme.primary.withAlpha(40)),
                    ),
                  ),
                  child: Text(
                    p,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? Colors.white
                          : (widget.isDark
                                ? Colors.white.withAlpha(180)
                                : const Color(0xFF4A4870)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          if (enriched.length >= 3) _buildPodium(enriched),
          const SizedBox(height: 20),
          ...enriched
              .skip(3)
              .map(
                (creator) => _LeaderboardRow(
                  creator: creator,
                  isDark: widget.isDark,
                  formatXP: _formatXP,
                  formatCount: _formatCount,
                  onTap: () => context.push(
                    AppRoutes.creatorProfileScreen,
                    extra: creator,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildPodium(List<Map<String, dynamic>> enriched) {
    final top3 = enriched.take(3).toList();
    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _PodiumCard(
              creator: top3[1],
              isDark: widget.isDark,
              height: 140,
              onTap: () =>
                  context.push(AppRoutes.creatorProfileScreen, extra: top3[1]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumCard(
              creator: top3[0],
              isDark: widget.isDark,
              height: 180,
              onTap: () =>
                  context.push(AppRoutes.creatorProfileScreen, extra: top3[0]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PodiumCard(
              creator: top3[2],
              isDark: widget.isDark,
              height: 120,
              onTap: () =>
                  context.push(AppRoutes.creatorProfileScreen, extra: top3[2]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PodiumCard extends StatelessWidget {
  final Map<String, dynamic> creator;
  final bool isDark;
  final double height;
  final VoidCallback onTap;

  const _PodiumCard({
    required this.creator,
    required this.isDark,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rank = creator['rank'] as int? ?? 1;
    final color = Color(creator['badgeColor'] as int? ?? 0xFF6C63FF);
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? Colors.white.withAlpha(13)
              : Colors.white.withAlpha(160),
          border: Border.all(color: color.withAlpha(80)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(medals[rank] ?? '', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(120), width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  creator['avatarUrl'] as String? ?? '',
                  fit: BoxFit.cover,
                  semanticLabel: creator['avatarLabel'] as String? ?? '',
                  errorBuilder: (_, __, ___) => Container(
                    color: color.withAlpha(40),
                    child: Icon(Icons.person_rounded, color: color, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                creator['name'] as String? ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Text(
              '${((creator['xp'] as int? ?? 0) / 1000).toStringAsFixed(1)}k XP',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final Map<String, dynamic> creator;
  final bool isDark;
  final String Function(int) formatXP;
  final String Function(int) formatCount;
  final VoidCallback onTap;

  const _LeaderboardRow({
    required this.creator,
    required this.isDark,
    required this.formatXP,
    required this.formatCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(creator['badgeColor'] as int? ?? 0xFF6C63FF);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? Colors.white.withAlpha(10)
              : Colors.white.withAlpha(160),
          border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(15)
                : AppTheme.primary.withAlpha(25),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#${creator['rank']}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? Colors.white.withAlpha(180)
                      : const Color(0xFF4A4870),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(100), width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  creator['avatarUrl'] as String? ?? '',
                  fit: BoxFit.cover,
                  semanticLabel: creator['avatarLabel'] as String? ?? '',
                  errorBuilder: (_, __, ___) => Container(
                    color: color.withAlpha(40),
                    child: Icon(Icons.person_rounded, color: color, size: 20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    creator['name'] as String? ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1840),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    creator['badge'] as String? ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatXP(creator['xp'] as int? ?? 0),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  '🔥 ${creator['streak'] ?? 0}d',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withAlpha(128)
                        : const Color(0xFF4A4870),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
