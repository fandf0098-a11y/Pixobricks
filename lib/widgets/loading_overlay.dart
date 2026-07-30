import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// LoadingOverlay — wraps any widget with a full-screen loading indicator.
/// Use [isLoading] to toggle visibility without rebuilding the child.
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;
  final Color? barrierColor;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
    this.barrierColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isLoading ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: barrierColor ?? Colors.black.withAlpha(115),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.surfaceDark
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(51),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primary,
                            ),
                          ),
                        ),
                        if (message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            message!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withAlpha(204)
                                  : const Color(0xFF4A4870),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// InlineLoader — compact centered loading indicator for list/content areas.
class InlineLoader extends StatelessWidget {
  final String? message;
  final double size;

  const InlineLoader({super.key, this.message, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 10),
              Text(
                message!,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withAlpha(153)
                      : const Color(0xFF4A4870).withAlpha(179),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
