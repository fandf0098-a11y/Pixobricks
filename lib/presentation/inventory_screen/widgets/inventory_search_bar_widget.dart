import 'dart:ui';

import '../../../core/app_export.dart';

/// Inline glassmorphism search bar — NOT default SearchDelegate
class InventorySearchBarWidget extends StatefulWidget {
  final bool isDark;
  final ValueChanged<String> onChanged;
  final String query;

  const InventorySearchBarWidget({
    super.key,
    required this.isDark,
    required this.onChanged,
    required this.query,
  });

  @override
  State<InventorySearchBarWidget> createState() =>
      _InventorySearchBarWidgetState();
}

class _InventorySearchBarWidgetState extends State<InventorySearchBarWidget>
    with SingleTickerProviderStateMixin {
  late TextEditingController _controller;
  late AnimationController _focusController;
  late Animation<double> _focusAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _focusAnimation = CurvedAnimation(
      parent: _focusController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _focusAnimation,
      builder: (context, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            // LOCKED: V5 Glassmorphism FormField — BackdropFilter blur
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withAlpha(15)
                    : Colors.white.withAlpha(166),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isFocused
                      ? AppTheme.primary
                      : (widget.isDark
                            ? Colors.white.withAlpha(26)
                            : AppTheme.primary.withAlpha(38)),
                  width: _isFocused ? 1.5 : 1,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppTheme.primary.withAlpha(38),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  CustomIconWidget(
                    iconName: 'search',
                    color: _isFocused
                        ? AppTheme.primary
                        : (widget.isDark
                              ? Colors.white.withAlpha(102)
                              : const Color(0xFF4A4870).withAlpha(128)),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Focus(
                      onFocusChange: (focused) {
                        setState(() => _isFocused = focused);
                        if (focused) {
                          _focusController.forward();
                        } else {
                          _focusController.reverse();
                        }
                      },
                      child: TextField(
                        controller: _controller,
                        onChanged: widget.onChanged,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: widget.isDark
                              ? Colors.white
                              : const Color(0xFF1A1840),
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search bricks, piece IDs...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: widget.isDark
                                ? Colors.white.withAlpha(77)
                                : const Color(0xFF4A4870).withAlpha(115),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          filled: false,
                        ),
                      ),
                    ),
                  ),
                  if (widget.query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        widget.onChanged('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: CustomIconWidget(
                          iconName: 'close',
                          color: widget.isDark
                              ? Colors.white.withAlpha(102)
                              : const Color(0xFF4A4870).withAlpha(128),
                          size: 18,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
