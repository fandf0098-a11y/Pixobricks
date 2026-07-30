import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.ctaLabel,
    this.onCtaTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withAlpha(38),
                    AppTheme.secondary.withAlpha(26),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppTheme.primary.withAlpha(51),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 48, color: AppTheme.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? Colors.white.withAlpha(128)
                    : const Color(0xFF4A4870).withAlpha(179),
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null && onCtaTap != null) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onCtaTap,
                icon: const Icon(Icons.add_rounded),
                label: Text(ctaLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
