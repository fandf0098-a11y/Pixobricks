import 'package:flutter/material.dart';

enum BadgeStatus {
  active,
  completed,
  inProgress,
  pending,
  warning,
  error,
  aiReady,
  scanning,
}

class StatusBadgeWidget extends StatelessWidget {
  final BadgeStatus status;
  final String? customLabel;
  final bool compact;

  const StatusBadgeWidget({
    super.key,
    required this.status,
    this.customLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _badgeConfig(status);

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withAlpha(38),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: config.color.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: config.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            customLabel ?? config.label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: config.color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _badgeConfig(BadgeStatus status) {
    switch (status) {
      case BadgeStatus.active:
        return _BadgeConfig(const Color(0xFF2ECC71), 'Active');
      case BadgeStatus.completed:
        return _BadgeConfig(const Color(0xFF6C63FF), 'Completed');
      case BadgeStatus.inProgress:
        return _BadgeConfig(const Color(0xFF00D4FF), 'In Progress');
      case BadgeStatus.pending:
        return _BadgeConfig(const Color(0xFFF39C12), 'Pending');
      case BadgeStatus.warning:
        return _BadgeConfig(const Color(0xFFF39C12), 'Warning');
      case BadgeStatus.error:
        return _BadgeConfig(const Color(0xFFE74C3C), 'Error');
      case BadgeStatus.aiReady:
        return _BadgeConfig(const Color(0xFF00D4FF), 'AI Ready');
      case BadgeStatus.scanning:
        return _BadgeConfig(const Color(0xFFFF6B9D), 'Scanning');
    }
  }
}

class _BadgeConfig {
  final Color color;
  final String label;
  const _BadgeConfig(this.color, this.label);
}
