import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ProfileStatsSection extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final bool isDark;

  const ProfileStatsSection({
    super.key,
    required this.posts,
    required this.isDark,
  });

  String _fmt(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🧱', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No creations yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withAlpha(120)
                    : const Color(0xFF4A4870),
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final imageUrl = post['image_url'] as String? ?? '';
        final likes = post['likes_count'] as int? ?? 0;
        final type = post['post_type'] as String? ?? 'project';

        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      semanticLabel:
                          post['image_label'] as String? ??
                          post['title'] as String? ??
                          'Creation',
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
              if (type == 'video')
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
                      _fmt(likes),
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
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: isDark
          ? AppTheme.surfaceVariantDark
          : AppTheme.surfaceVariantLight,
      child: Icon(
        Icons.image_outlined,
        color: isDark
            ? Colors.white.withAlpha(60)
            : const Color(0xFF4A4870).withAlpha(80),
      ),
    );
  }
}
