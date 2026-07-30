import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shimmer skeleton — AnimationController drives gradient position
class LoadingSkeletonWidget extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeletonWidget({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<LoadingSkeletonWidget> createState() => _LoadingSkeletonWidgetState();
}

class _LoadingSkeletonWidgetState extends State<LoadingSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (_shimmer.value - 0.3).clamp(0.0, 1.0),
                _shimmer.value.clamp(0.0, 1.0),
                (_shimmer.value + 0.3).clamp(0.0, 1.0),
              ],
              colors: isDark
                  ? [
                      Colors.white.withAlpha(10),
                      Colors.white.withAlpha(26),
                      Colors.white.withAlpha(10),
                    ]
                  : [
                      AppTheme.primary.withAlpha(13),
                      AppTheme.primary.withAlpha(31),
                      AppTheme.primary.withAlpha(13),
                    ],
            ),
          ),
        );
      },
    );
  }
}

/// Pre-built skeleton for a card
class CardSkeletonWidget extends StatelessWidget {
  final double height;

  const CardSkeletonWidget({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(10)
            : Colors.white.withAlpha(153),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : AppTheme.primary.withAlpha(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LoadingSkeletonWidget(width: 48, height: 48, borderRadius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LoadingSkeletonWidget(width: double.infinity, height: 14),
                    const SizedBox(height: 8),
                    LoadingSkeletonWidget(width: 120, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LoadingSkeletonWidget(width: double.infinity, height: 12),
          const SizedBox(height: 6),
          LoadingSkeletonWidget(width: 200, height: 12),
        ],
      ),
    );
  }
}
