import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class PostCardWidget extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isDark;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onCreatorTap;

  const PostCardWidget({
    super.key,
    required this.post,
    required this.isDark,
    required this.onLike,
    required this.onBookmark,
    required this.onCreatorTap,
  });

  @override
  State<PostCardWidget> createState() => _PostCardWidgetState();
}

class _PostCardWidgetState extends State<PostCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _likeController;
  late Animation<double> _likeScale;

  @override
  void initState() {
    super.initState();
    _likeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _likeScale = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _likeController, curve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _likeController.dispose();
    super.dispose();
  }

  void _handleLike() {
    HapticFeedback.lightImpact();
    _likeController.forward().then((_) => _likeController.reverse());
    widget.onLike();
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'video':
        return AppTheme.tertiary;
      case 'instructions':
        return AppTheme.secondary;
      case 'image':
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'video':
        return Icons.play_circle_rounded;
      case 'instructions':
        return Icons.menu_book_rounded;
      case 'image':
        return Icons.image_rounded;
      default:
        return Icons.view_in_ar_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final creator = post['creator'] as Map<String, dynamic>;
    final isLiked = post['isLiked'] as bool;
    final isBookmarked = post['isBookmarked'] as bool;
    final type = post['type'] as String;
    final tags = post['tags'] as List<dynamic>;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark
              ? Colors.white.withAlpha(18)
              : AppTheme.primary.withAlpha(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(widget.isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Creator header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: widget.onCreatorTap,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    child: ClipOval(
                      child: Image.network(
                        creator['avatarUrl'] as String,
                        fit: BoxFit.cover,
                        semanticLabel: creator['avatarLabel'] as String,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onCreatorTap,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              creator['name'] as String,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1840),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Color(
                                  creator['badgeColor'] as int,
                                ).withAlpha(46),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                creator['badge'] as String,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(creator['badgeColor'] as int),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          creator['username'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: widget.isDark
                                ? Colors.white.withAlpha(120)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _typeColor(type).withAlpha(38),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(type), size: 12, color: _typeColor(type)),
                      const SizedBox(width: 4),
                      Text(
                        type[0].toUpperCase() + type.substring(1),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: _typeColor(type),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Media
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.zero),
                child: Image.network(
                  post['imageUrl'] as String,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  semanticLabel: post['imageLabel'] as String,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: widget.isDark
                        ? AppTheme.surfaceVariantDark
                        : AppTheme.surfaceVariantLight,
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
                ),
              ),
              if (type == 'video')
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(140),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              // Time badge
              Positioned(
                top: 10,
                right: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      color: Colors.black.withAlpha(89),
                      child: Text(
                        post['timeAgo'] as String,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Title & description
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post['title'] as String,
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
                const SizedBox(height: 4),
                Text(
                  post['description'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: widget.isDark
                        ? Colors.white.withAlpha(160)
                        : const Color(0xFF4A4870),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Tags
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: tags
                      .map(
                        (tag) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(26),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#$tag',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Row(
              children: [
                // Like
                _ActionButton(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: _formatCount(post['likes'] as int),
                  color: isLiked ? AppTheme.tertiary : null,
                  isDark: widget.isDark,
                  onTap: _handleLike,
                  scaleAnimation: _likeScale,
                ),
                const SizedBox(width: 16),
                // Comment
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _formatCount(post['comments'] as int),
                  isDark: widget.isDark,
                  onTap: () {},
                ),
                const SizedBox(width: 16),
                // Remix
                _ActionButton(
                  icon: Icons.shuffle_rounded,
                  label: _formatCount(post['remixes'] as int),
                  color: AppTheme.secondary,
                  isDark: widget.isDark,
                  onTap: () {},
                ),
                const Spacer(),
                // Bookmark
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onBookmark();
                  },
                  child: Icon(
                    isBookmarked
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 22,
                    color: isBookmarked
                        ? AppTheme.warning
                        : (widget.isDark
                              ? Colors.white.withAlpha(120)
                              : const Color(0xFF4A4870)),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final bool isDark;
  final VoidCallback onTap;
  final Animation<double>? scaleAnimation;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
    this.color,
    this.scaleAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ??
        (isDark ? Colors.white.withAlpha(160) : const Color(0xFF4A4870));

    Widget iconWidget = Icon(icon, size: 20, color: iconColor);

    if (scaleAnimation != null) {
      iconWidget = ScaleTransition(scale: scaleAnimation!, child: iconWidget);
    }

    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
