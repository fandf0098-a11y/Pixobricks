// AppBar V3 — Glassmorphism — LOCKED: BackdropFilter blur + transparent surface
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

class AppBarWidget extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBack;
  final bool centerTitle;
  final double elevation;

  const AppBarWidget({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBack = false,
    this.centerTitle = true,
    this.elevation = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        // LOCKED: BackdropFilter blur — Glassmorphism AppBar core technique
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 64 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(13)
                : Colors.white.withAlpha(153),
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withAlpha(20)
                    : AppTheme.primary.withAlpha(26),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showBack)
                Tooltip(
                  message: 'Go back',
                  child: Semantics(
                    button: true,
                    label: 'Go back',
                    child: IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          Navigator.of(context).maybePop();
                        }
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: isDark ? Colors.white : const Color(0xFF1A1840),
                      ),
                    ),
                  ),
                )
              else if (leading != null)
                leading!
              else
                const SizedBox(width: 16),
              Expanded(
                child: centerTitle
                    ? Center(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
              ),
              if (actions != null) ...actions!,
              if (actions == null) const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
