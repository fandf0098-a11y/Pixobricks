import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// V3 — Liquid Glass Bottom Navigation (4 tabs: Home, Inventory, Build, Community)
class AppNavigation extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({required this.navigationShell, super.key});

  @override
  State<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends State<AppNavigation>
    with SingleTickerProviderStateMixin {
  late int _selectedVisualIndex;
  late AnimationController _pillController;
  late Animation<double> _pillAnimation;

  static const List<_TabSpec> _tabs = [
    _TabSpec(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      branchIndex: 0,
    ),
    _TabSpec(
      label: 'Inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2_rounded,
      branchIndex: 1,
    ),
    _TabSpec(
      label: 'AI Build',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      branchIndex: 2,
    ),
    _TabSpec(
      label: 'Community',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      branchIndex: 3,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedVisualIndex = widget.navigationShell.currentIndex;
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _pillAnimation = CurvedAnimation(
      parent: _pillController,
      curve: Curves.easeOutCubic,
    );
    _pillController.forward();
  }

  @override
  void dispose() {
    _pillController.dispose();
    super.dispose();
  }

  void _onTabTapped(int visualIndex) {
    final spec = _tabs[visualIndex];
    if (spec.branchIndex == null) return;

    setState(() {
      _selectedVisualIndex = visualIndex;
    });

    _pillController.reset();
    _pillController.forward();

    widget.navigationShell.goBranch(
      spec.branchIndex!,
      initialLocation: spec.branchIndex == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(20)
                  : Colors.white.withAlpha(166),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(31)
                    : AppTheme.primary.withAlpha(38),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isActive = index == _selectedVisualIndex;

                return Expanded(
                  child: Semantics(
                    button: true,
                    enabled: true,
                    selected: isActive,
                    label: '${tab.label} tab',
                    hint: isActive
                        ? 'Currently selected'
                        : 'Navigate to ${tab.label}',
                    child: Tooltip(
                      message: tab.label,
                      child: GestureDetector(
                        onTap: () => _onTabTapped(index),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppTheme.primary.withAlpha(46)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  isActive ? tab.selectedIcon : tab.icon,
                                  key: ValueKey(isActive),
                                  size: 22,
                                  color: isActive
                                      ? AppTheme.primary
                                      : (isDark
                                            ? Colors.white.withAlpha(128)
                                            : const Color(
                                                0xFF4A4870,
                                              ).withAlpha(153)),
                                ),
                              ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: isActive
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppTheme.primary
                                      : (isDark
                                            ? Colors.white.withAlpha(128)
                                            : const Color(
                                                0xFF4A4870,
                                              ).withAlpha(153)),
                                ),
                                child: Text(
                                  tab.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? branchIndex;

  const _TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.branchIndex,
  });
}
