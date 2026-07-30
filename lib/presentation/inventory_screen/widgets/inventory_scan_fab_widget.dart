import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Extended FAB — Scan new bricks primary action
class InventoryScanFabWidget extends StatelessWidget {
  final bool isDark;

  const InventoryScanFabWidget({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withAlpha(115),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Replace with camera scan implementation
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        icon: const Icon(
          Icons.camera_alt_rounded,
          color: Colors.white,
          size: 22,
        ),
        label: const Text(
          'Scan Bricks',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
