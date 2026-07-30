import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class ProfileAchievementsSection extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;
  final bool isDark;

  const ProfileAchievementsSection({
    super.key,
    required this.achievements,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🏆', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              'No achievements yet',
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
      itemCount: achievements.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = achievements[index];
        final color = Color(a['icon_color'] as int? ?? 0xFF6C63FF);
        final xpReward = a['xp_reward'] as int? ?? 0;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(10)
                : Colors.white.withAlpha(180),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withAlpha(40),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withAlpha(80)),
                ),
                child: Center(
                  child: Text(
                    a['icon'] as String? ?? '🏆',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a['title'] as String? ?? 'Achievement',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1A1840),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a['description'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark
                            ? Colors.white.withAlpha(120)
                            : const Color(0xFF4A4870),
                      ),
                    ),
                  ],
                ),
              ),
              if (xpReward > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.xpColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+$xpReward XP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.xpColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
