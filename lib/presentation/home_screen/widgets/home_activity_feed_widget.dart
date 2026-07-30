import 'dart:ui';

import '../../../core/app_export.dart';

/// Recent Activity Feed — last 5 domain events
/// ListItem V1: Rich Data Row — status badge + primary + metadata + trailing
class HomeActivityFeedWidget extends StatelessWidget {
  final bool isDark;

  const HomeActivityFeedWidget({super.key, required this.isDark});

  static final List<Map<String, dynamic>> _activityMaps = [
    {
      'icon': 'camera_alt',
      'iconColor': 0xFF6C63FF,
      'title': 'Scanned 64 new bricks',
      'subtitle': 'Plates — 2×4, 1×2, 1×4 variants added to inventory',
      'time': '2 min ago',
      'status': 'completed',
      'statusLabel': 'Scanned',
    },
    {
      'icon': 'auto_awesome',
      'iconColor': 0xFF00D4FF,
      'title': 'AI generated Medieval Castle',
      'subtitle': 'Build plan ready — 342 pieces, 94% collection match',
      'time': '18 min ago',
      'status': 'aiReady',
      'statusLabel': 'AI Ready',
    },
    {
      'icon': 'architecture',
      'iconColor': 0xFF2ECC71,
      'title': 'Completed Space Rover build',
      'subtitle': 'Added to gallery · 47 community likes',
      'time': '3h ago',
      'status': 'completed',
      'statusLabel': 'Done',
    },
    {
      'icon': 'people',
      'iconColor': 0xFFFF6B9D,
      'title': 'Priya Sharma liked your build',
      'subtitle': '"Vintage Steam Train" — now at 128 likes',
      'time': '5h ago',
      'status': 'active',
      'statusLabel': 'Social',
    },
    {
      'icon': 'warning_amber',
      'iconColor': 0xFFF39C12,
      'title': 'Low stock: Red 2×4 plates',
      'subtitle': 'Only 3 remaining — needed for 4 pending builds',
      'time': '1d ago',
      'status': 'warning',
      'statusLabel': 'Alert',
    },
  ];

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'aiReady':
        return AppTheme.secondary;
      case 'active':
        return AppTheme.tertiary;
      case 'warning':
        return AppTheme.warning;
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Activity',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'View all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(13)
                    : Colors.white.withAlpha(166),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(20)
                      : AppTheme.primary.withAlpha(26),
                ),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _activityMaps.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: isDark
                      ? Colors.white.withAlpha(13)
                      : AppTheme.primary.withAlpha(15),
                ),
                itemBuilder: (context, index) {
                  final item = _activityMaps[index];
                  return _buildActivityRow(item);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRow(Map<String, dynamic> item) {
    final statusColor = _statusColor(item['status'] as String);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(item['iconColor'] as int).withAlpha(38),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Color(item['iconColor'] as int).withAlpha(64),
                width: 1,
              ),
            ),
            child: CustomIconWidget(
              iconName: item['icon'] as String,
              color: Color(item['iconColor'] as int),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1840),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withAlpha(31),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusColor.withAlpha(64)),
                      ),
                      child: Text(
                        item['statusLabel'] as String,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item['subtitle'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withAlpha(115)
                        : const Color(0xFF4A4870).withAlpha(166),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item['time'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withAlpha(77)
                        : const Color(0xFF4A4870).withAlpha(115),
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
