import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../theme/app_theme.dart';
import '../../../providers/user_profile_provider.dart';

/// Greeting widget — contextual by time of day + current stats
class HomeGreetingWidget extends ConsumerWidget {
  final bool isDark;

  const HomeGreetingWidget({super.key, required this.isDark});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formattedDate() {
    final now = DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider);
    final firstName = profile.displayName.split(' ').first;
    final piecesScanned = profile.piecesScanned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting()}, $firstName! 👋',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1840),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your AI builds are ready to explore',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? Colors.white.withAlpha(140)
                          : const Color(0xFF4A4870).withAlpha(179),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.success.withAlpha(31),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppTheme.success.withAlpha(64)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'AI Online',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${_formattedDate()} · Collection: $piecesScanned bricks',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? Colors.white.withAlpha(89)
                : const Color(0xFF4A4870).withAlpha(128),
          ),
        ),
      ],
    );
  }
}
