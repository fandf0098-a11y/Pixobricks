import 'dart:ui';

import '../../../core/app_export.dart';

/// Quick Stats row — 4 glassmorphism metric cards
/// Anatomy: horizontal scroll row of metric cards
class HomeQuickStatsWidget extends StatelessWidget {
  final bool isDark;
  final bool isTablet;

  const HomeQuickStatsWidget({
    super.key,
    required this.isDark,
    this.isTablet = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stats = [
      _StatItem(
        icon: 'view_in_ar',
        label: 'Total Bricks',
        value: '1,247',
        delta: '+64 this week',
        deltaPositive: true,
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B94FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _StatItem(
        icon: 'architecture',
        label: 'Builds Done',
        value: '38',
        delta: '+3 this month',
        deltaPositive: true,
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _StatItem(
        icon: 'auto_awesome',
        label: 'AI Builds',
        value: '127',
        delta: '+12 this week',
        deltaPositive: true,
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFD44080)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      _StatItem(
        icon: 'favorite',
        label: 'Community Likes',
        value: '2.4K',
        delta: '-18 this week',
        deltaPositive: false,
        gradient: const LinearGradient(
          colors: [Color(0xFFF39C12), Color(0xFFD68910)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    ];

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Text(
                'Your Stats',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.4,
            children: stats.map((s) => _buildStatCard(s, isDark)).toList(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Your Stats',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
            Text(
              'Last 30 days',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? Colors.white.withAlpha(102)
                    : const Color(0xFF4A4870).withAlpha(153),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) =>
                SizedBox(width: 140, child: _buildStatCard(stats[i], isDark)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatItem stat, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(15)
                : Colors.white.withAlpha(166),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(26)
                  : AppTheme.primary.withAlpha(31),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: stat.gradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: (stat.gradient.colors.first).withAlpha(89),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: CustomIconWidget(
                  iconName: stat.icon,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const Spacer(),
              Text(
                stat.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1A1840),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withAlpha(115)
                      : const Color(0xFF4A4870).withAlpha(153),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat.delta,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: stat.deltaPositive ? AppTheme.success : AppTheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem {
  final String icon;
  final String label;
  final String value;
  final String delta;
  final bool deltaPositive;
  final LinearGradient gradient;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    required this.deltaPositive,
    required this.gradient,
  });
}
