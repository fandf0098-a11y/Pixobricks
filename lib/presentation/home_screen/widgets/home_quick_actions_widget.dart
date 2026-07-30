import 'dart:ui';

import '../../../core/app_export.dart';

/// Quick Actions Bar — 4 icon action slots
/// Anatomy locked from reference: Row of 4 rounded-square icon containers
class HomeQuickActionsWidget extends StatelessWidget {
  final bool isDark;

  const HomeQuickActionsWidget({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final actions = [
      _ActionItem(
        icon: 'camera_alt',
        label: 'Scan',
        gradient: const LinearGradient(
          colors: [Color(0xFF6C63FF), Color(0xFF9B94FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {},
      ),
      _ActionItem(
        icon: 'smart_toy',
        label: 'AI Chat',
        gradient: const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFF0099BB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => context.push(AppRoutes.aiAssistantScreen),
      ),
      _ActionItem(
        icon: 'view_in_ar',
        label: 'AR View',
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B9D), Color(0xFFD44080)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () => context.push(AppRoutes.arBuildingScreen),
      ),
      _ActionItem(
        icon: 'share',
        label: 'Share',
        gradient: const LinearGradient(
          colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        onTap: () {},
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1A1840),
          ),
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: actions.map((action) {
                  return GestureDetector(
                    onTap: action.onTap,
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: action.gradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: action.gradient.colors.first.withAlpha(
                                  89,
                                ),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CustomIconWidget(
                            iconName: action.icon,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          action.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white.withAlpha(179)
                                : const Color(0xFF4A4870),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionItem {
  final String icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });
}
