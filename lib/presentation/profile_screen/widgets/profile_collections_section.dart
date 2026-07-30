import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ProfileCollectionsSection extends StatelessWidget {
  final List<Map<String, dynamic>> collections;
  final bool isDark;

  const ProfileCollectionsSection({
    super.key,
    required this.collections,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (collections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🗂', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No collections yet',
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

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: collections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final c = collections[index];
        final coverUrl = c['cover_image_url'] as String? ?? '';
        final pieceCount = c['piece_count'] as int? ?? 0;
        final theme = c['theme'] as String? ?? '';

        return Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isDark
                ? Colors.white.withAlpha(10)
                : Colors.white.withAlpha(180),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Cover image
              SizedBox(
                width: 100,
                child: coverUrl.isNotEmpty
                    ? Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        semanticLabel:
                            c['cover_image_label'] as String? ??
                            'Collection cover for ${c['title']}',
                        errorBuilder: (_, __, ___) => _coverPlaceholder(),
                      )
                    : _coverPlaceholder(),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        c['title'] as String? ?? 'Collection',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1840),
                        ),
                      ),
                      if (theme.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            theme,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.category_rounded,
                            size: 12,
                            color: isDark
                                ? Colors.white.withAlpha(100)
                                : const Color(0xFF4A4870),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$pieceCount pieces',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white.withAlpha(120)
                                  : const Color(0xFF4A4870),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withAlpha(80)
                      : const Color(0xFF4A4870).withAlpha(120),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      color: isDark
          ? AppTheme.surfaceVariantDark
          : AppTheme.surfaceVariantLight,
      child: Icon(
        Icons.collections_rounded,
        color: isDark
            ? Colors.white.withAlpha(60)
            : const Color(0xFF4A4870).withAlpha(80),
      ),
    );
  }
}
