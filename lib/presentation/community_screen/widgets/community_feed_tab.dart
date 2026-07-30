import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../routes/app_routes.dart';
import '../../../services/supabase_service.dart';
import '../../../theme/app_theme.dart';
import './post_card_widget.dart';

class CommunityFeedTab extends StatefulWidget {
  final bool isDark;
  const CommunityFeedTab({super.key, required this.isDark});

  @override
  State<CommunityFeedTab> createState() => _CommunityFeedTabState();
}

class _CommunityFeedTabState extends State<CommunityFeedTab> {
  String _activeFilter = 'All';
  final List<String> _filters = [
    'All',
    'Projects',
    'Images',
    'Videos',
    'Instructions',
  ];

  List<Map<String, dynamic>> _posts = [];
  Set<String> _likedPostIds = {};
  Set<String> _bookmarkedPostIds = {};
  bool _isLoading = false;
  String? _error;

  static const Map<String, String> _filterTypeMap = {
    'Projects': 'project',
    'Images': 'image',
    'Videos': 'video',
    'Instructions': 'instructions',
  };

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final postType = _activeFilter == 'All'
          ? null
          : _filterTypeMap[_activeFilter];
      final results = await Future.wait([
        SupabaseService.instance.fetchPosts(postType: postType),
        SupabaseService.instance.fetchLikedPostIds(),
        SupabaseService.instance.fetchBookmarkedPostIds(),
      ]);
      if (mounted) {
        setState(() {
          _posts = results[0] as List<Map<String, dynamic>>;
          _likedPostIds = results[1] as Set<String>;
          _bookmarkedPostIds = results[2] as Set<String>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleLike(String postId) async {
    final isLiked = _likedPostIds.contains(postId);
    // Optimistic update
    setState(() {
      if (isLiked) {
        _likedPostIds.remove(postId);
        final idx = _posts.indexWhere((p) => p['id'] == postId);
        if (idx != -1) {
          _posts[idx]['likes_count'] =
              ((_posts[idx]['likes_count'] as int?) ?? 1) - 1;
        }
      } else {
        _likedPostIds.add(postId);
        final idx = _posts.indexWhere((p) => p['id'] == postId);
        if (idx != -1) {
          _posts[idx]['likes_count'] =
              ((_posts[idx]['likes_count'] as int?) ?? 0) + 1;
        }
      }
    });
    try {
      if (isLiked) {
        await SupabaseService.instance.unlikePost(postId);
      } else {
        await SupabaseService.instance.likePost(postId);
      }
    } catch (_) {
      // Revert on failure
      await _loadPosts();
    }
  }

  Future<void> _toggleBookmark(String postId) async {
    final isBookmarked = _bookmarkedPostIds.contains(postId);
    setState(() {
      if (isBookmarked) {
        _bookmarkedPostIds.remove(postId);
        final idx = _posts.indexWhere((p) => p['id'] == postId);
        if (idx != -1) {
          _posts[idx]['bookmarks_count'] =
              ((_posts[idx]['bookmarks_count'] as int?) ?? 1) - 1;
        }
      } else {
        _bookmarkedPostIds.add(postId);
        final idx = _posts.indexWhere((p) => p['id'] == postId);
        if (idx != -1) {
          _posts[idx]['bookmarks_count'] =
              ((_posts[idx]['bookmarks_count'] as int?) ?? 0) + 1;
        }
      }
    });
    try {
      if (isBookmarked) {
        await SupabaseService.instance.unbookmarkPost(postId);
      } else {
        await SupabaseService.instance.bookmarkPost(postId);
      }
    } catch (_) {
      await _loadPosts();
    }
  }

  Map<String, dynamic> _normalizePost(Map<String, dynamic> raw) {
    final profile = raw['user_profiles'] as Map<String, dynamic>?;
    final postId = raw['id'] as String? ?? '';
    return {
      'id': postId,
      'type': raw['post_type'] as String? ?? 'project',
      'title': raw['title'] as String? ?? '',
      'description': raw['description'] as String? ?? '',
      'imageUrl': raw['image_url'] as String? ?? '',
      'imageLabel': raw['image_label'] as String? ?? '',
      'creator': {
        'id': profile?['id'] as String? ?? '',
        'name': profile?['full_name'] as String? ?? 'Builder',
        'username': '@${profile?['username'] as String? ?? 'builder'}',
        'avatarUrl': profile?['avatar_url'] as String? ?? '',
        'avatarLabel': 'Creator avatar',
        'badge': profile?['badge'] as String? ?? 'Builder',
        'badgeColor': profile?['badge_color'] as int? ?? 0xFF6C63FF,
      },
      'likes': raw['likes_count'] as int? ?? 0,
      'comments': raw['comments_count'] as int? ?? 0,
      'bookmarks': raw['bookmarks_count'] as int? ?? 0,
      'remixes': raw['remixes_count'] as int? ?? 0,
      'isLiked': _likedPostIds.contains(postId),
      'isBookmarked': _bookmarkedPostIds.contains(postId),
      'tags': List<String>.from(raw['tags'] as List? ?? []),
      'timeAgo': _timeAgo(raw['created_at'] as String?),
    };
  }

  String _timeAgo(String? isoDate) {
    if (isoDate == null) return '';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 14),
        _buildFilterChips(),
        const SizedBox(height: 8),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.red.withAlpha(180),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load posts',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: widget.isDark
                    ? Colors.white.withAlpha(180)
                    : const Color(0xFF4A4870),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _loadPosts,
              child: Text(
                'Retry',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'No posts yet. Be the first to share!',
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
      onRefresh: _loadPosts,
      color: AppTheme.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        physics: const BouncingScrollPhysics(),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _normalizePost(_posts[index]);
          return PostCardWidget(
            post: post,
            isDark: widget.isDark,
            onLike: () => _toggleLike(post['id'] as String),
            onBookmark: () => _toggleBookmark(post['id'] as String),
            onCreatorTap: () => context.push(
              AppRoutes.creatorProfileScreen,
              extra: post['creator'],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isActive = filter == _activeFilter;
          return GestureDetector(
            onTap: () {
              setState(() => _activeFilter = filter);
              _loadPosts();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                filter,
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
        },
      ),
    );
  }
}
