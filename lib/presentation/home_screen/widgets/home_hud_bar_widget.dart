import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_export.dart';
import '../../../providers/user_profile_provider.dart';

/// HUD Bar — Glassmorphism AppBar: avatar + XP progress + gem count + settings
/// Anatomy locked: Row [avatar] [progress pill] [gem chip] [settings icon]
class HomeHudBarWidget extends ConsumerWidget {
  final bool isDark;
  final bool isElevated;

  const HomeHudBarWidget({
    super.key,
    required this.isDark,
    this.isElevated = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);

    return ClipRect(
      child: BackdropFilter(
        // LOCKED: Glassmorphism — BackdropFilter blur
        filter: ImageFilter.blur(
          sigmaX: isElevated ? 24 : 0,
          sigmaY: isElevated ? 24 : 0,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isElevated
                ? (isDark
                      ? Colors.white.withAlpha(15)
                      : Colors.white.withAlpha(166))
                : Colors.transparent,
            border: isElevated
                ? Border(
                    bottom: BorderSide(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : AppTheme.primary.withAlpha(26),
                      width: 1,
                    ),
                  )
                : null,
          ),
          child: Row(
            children: [
              // Avatar
              _buildAvatar(context, profile),
              const SizedBox(width: 12),

              // XP Progress bar + level
              Expanded(child: _buildXpSection(isDark, profile)),
              const SizedBox(width: 12),

              // Gem counter
              _buildGemChip(isDark, profile),
              const SizedBox(width: 8),

              // Settings
              _buildSettingsButton(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, UserProfileState profile) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.profileScreen),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(102),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipOval(
          child: profile.avatarUrl != null
              ? CustomImageWidget(
                  imageUrl: profile.avatarUrl!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  semanticLabel: '${profile.displayName} profile avatar',
                )
              : Container(
                  color: AppTheme.primary.withAlpha(40),
                  child: Center(
                    child: Text(
                      profile.displayName.isNotEmpty
                          ? profile.displayName[0].toUpperCase()
                          : 'B',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildXpSection(bool isDark, UserProfileState profile) {
    final level = profile.level;
    final xp = profile.xp;
    final xpToNext = profile.xpToNextLevel;
    final progress = profile.xpProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Level $level',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
            const Spacer(),
            Text(
              '$xp / $xpToNext XP',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withAlpha(115)
                    : const Color(0xFF4A4870).withAlpha(153),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(20)
                : AppTheme.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            widthFactor: progress,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(128),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGemChip(bool isDark, UserProfileState profile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withOpacity(isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.secondary.withAlpha(64), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomIconWidget(
            iconName: 'diamond',
            color: AppTheme.secondary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '${profile.gems}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsButton(bool isDark) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(15)
            : AppTheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : AppTheme.primary.withAlpha(31),
        ),
      ),
      child: CustomIconWidget(
        iconName: 'settings',
        color: isDark ? Colors.white.withAlpha(153) : const Color(0xFF4A4870),
        size: 18,
      ),
    );
  }
}
