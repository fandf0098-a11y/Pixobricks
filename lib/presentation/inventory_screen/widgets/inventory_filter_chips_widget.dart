import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Horizontal scrollable filter chips row
class InventoryFilterChipsWidget extends StatelessWidget {
  final List<String> filters;
  final String selected;
  final bool isDark;
  final ValueChanged<String> onSelected;

  const InventoryFilterChipsWidget({
    super.key,
    required this.filters,
    required this.selected,
    required this.isDark,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isActive = filter == selected;

          return GestureDetector(
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppTheme.primaryGradient : null,
                color: isActive
                    ? null
                    : (isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.white.withAlpha(166)),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive
                      ? Colors.transparent
                      : (isDark
                            ? Colors.white.withAlpha(26)
                            : AppTheme.primary.withAlpha(38)),
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(77),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? Colors.white
                      : (isDark
                            ? Colors.white.withAlpha(153)
                            : const Color(0xFF4A4870)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
