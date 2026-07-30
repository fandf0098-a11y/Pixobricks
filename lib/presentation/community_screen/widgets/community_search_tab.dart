import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../routes/app_routes.dart';
import '../../../services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class CommunitySearchTab extends StatefulWidget {
  final bool isDark;
  const CommunitySearchTab({super.key, required this.isDark});

  @override
  State<CommunitySearchTab> createState() => _CommunitySearchTabState();
}

class _CommunitySearchTabState extends State<CommunitySearchTab> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _searchType = 'Creators';
  final List<String> _searchTypes = ['Creators', 'Posts', 'Tags'];

  List<Map<String, dynamic>> _creators = [];
  Set<String> _followingIds = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchCreators(searchQuery: _query),
        SupabaseService.instance.fetchFollowingIds(),
      ]);
      if (mounted) {
        setState(() {
          _creators = results[0] as List<Map<String, dynamic>>;
          _followingIds = results[1] as Set<String>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String targetId) async {
    final isFollowing = _followingIds.contains(targetId);
    setState(() {
      if (isFollowing) {
        _followingIds.remove(targetId);
      } else {
        _followingIds.add(targetId);
      }
    });
    try {
      if (isFollowing) {
        await SupabaseService.instance.unfollowCreator(targetId);
      } else {
        await SupabaseService.instance.followCreator(targetId);
      }
    } catch (_) {
      await _loadData();
    }
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            children: [
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white.withAlpha(20)
                        : AppTheme.primary.withAlpha(35),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) {
                    setState(() => _query = v);
                    _loadData();
                  },
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: widget.isDark
                        ? Colors.white
                        : const Color(0xFF1A1840),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search creators, posts, tags...',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: widget.isDark
                          ? Colors.white.withAlpha(100)
                          : const Color(0xFF4A4870).withAlpha(150),
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: widget.isDark
                          ? Colors.white.withAlpha(120)
                          : const Color(0xFF4A4870),
                      size: 20,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _query = '');
                              _loadData();
                            },
                            child: Icon(
                              Icons.close_rounded,
                              color: widget.isDark
                                  ? Colors.white.withAlpha(120)
                                  : const Color(0xFF4A4870),
                              size: 18,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: _searchTypes.map((type) {
                  final isActive = type == _searchType;
                  return GestureDetector(
                    onTap: () => setState(() => _searchType = type),
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
                        type,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
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
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _buildResults()),
      ],
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_creators.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? 'No creators found' : 'No results for "$_query"',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: widget.isDark
                ? Colors.white.withAlpha(128)
                : const Color(0xFF4A4870),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        itemCount: _creators.length,
        itemBuilder: (context, index) {
          final creator = _creators[index];
          final creatorId = creator['id'] as String? ?? '';
          final isFollowing = _followingIds.contains(creatorId);
          final color = Color(creator['badge_color'] as int? ?? 0xFF6C63FF);
          return GestureDetector(
            onTap: () => context.push(
              AppRoutes.creatorProfileScreen,
              extra: {
                'id': creatorId,
                'name': creator['full_name'],
                'username': '@${creator['username'] ?? ''}',
                'badge': creator['badge'],
                'badgeColor': creator['badge_color'],
                'avatarUrl': creator['avatar_url'],
                'avatarLabel': 'Creator avatar',
                'followers': 0,
                'posts': 0,
                'xp': creator['xp'],
                'streak': creator['streak'],
                'isFollowing': isFollowing,
              },
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: widget.isDark
                    ? Colors.white.withAlpha(10)
                    : Colors.white.withAlpha(160),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white.withAlpha(15)
                      : AppTheme.primary.withAlpha(25),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withAlpha(100), width: 2),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        creator['avatar_url'] as String? ?? '',
                        fit: BoxFit.cover,
                        semanticLabel: 'Creator avatar',
                        errorBuilder: (_, __, ___) => Container(
                          color: color.withAlpha(40),
                          child: Icon(
                            Icons.person_rounded,
                            color: color,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          creator['full_name'] as String? ?? 'Builder',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: widget.isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${creator['username'] as String? ?? ''}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.white.withAlpha(128)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            creator['badge'] as String? ?? 'Builder',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleFollow(creatorId),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: isFollowing ? null : AppTheme.primaryGradient,
                        color: isFollowing
                            ? (widget.isDark
                                  ? Colors.white.withAlpha(20)
                                  : Colors.white.withAlpha(200))
                            : null,
                        borderRadius: BorderRadius.circular(20),
                        border: isFollowing
                            ? Border.all(
                                color: widget.isDark
                                    ? Colors.white.withAlpha(40)
                                    : AppTheme.primary.withAlpha(60),
                              )
                            : null,
                      ),
                      child: Text(
                        isFollowing ? 'Following' : 'Follow',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isFollowing
                              ? (widget.isDark
                                    ? Colors.white.withAlpha(180)
                                    : const Color(0xFF4A4870))
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
