import 'dart:ui';

import '../../../core/app_export.dart';

/// Brick inventory grid — 2-column glassmorphism card grid
/// Card V2 Glassmorphism — LOCKED: BackdropFilter + semi-transparent surface
/// ListItem V1 Rich Data Row — status badge + primary + metadata + trailing action
class InventoryBrickGridWidget extends StatefulWidget {
  final List<Map<String, dynamic>> bricks;
  final bool isDark;
  final int crossAxisCount;
  final ValueChanged<String> onDelete;
  final ValueChanged<String> onFavoriteToggle;

  const InventoryBrickGridWidget({
    super.key,
    required this.bricks,
    required this.isDark,
    required this.crossAxisCount,
    required this.onDelete,
    required this.onFavoriteToggle,
  });

  @override
  State<InventoryBrickGridWidget> createState() =>
      _InventoryBrickGridWidgetState();
}

class _InventoryBrickGridWidgetState extends State<InventoryBrickGridWidget> {
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        120,
      ), // bottom pad for Liquid Glass nav
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: widget.bricks.length,
      itemBuilder: (context, index) {
        final brick = widget.bricks[index];
        return _BrickCardWidget(
          brick: brick,
          isDark: widget.isDark,
          onDelete: () => widget.onDelete(brick['id'] as String),
          onFavoriteToggle: () =>
              widget.onFavoriteToggle(brick['id'] as String),
          animationDelay: Duration(milliseconds: (index * 50).clamp(0, 400)),
        );
      },
    );
  }
}

class _BrickCardWidget extends StatefulWidget {
  final Map<String, dynamic> brick;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onFavoriteToggle;
  final Duration animationDelay;

  const _BrickCardWidget({
    required this.brick,
    required this.isDark,
    required this.onDelete,
    required this.onFavoriteToggle,
    required this.animationDelay,
  });

  @override
  State<_BrickCardWidget> createState() => _BrickCardWidgetState();
}

class _BrickCardWidgetState extends State<_BrickCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Staggered entrance
    Future.delayed(widget.animationDelay, () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'warning':
        return AppTheme.warning;
      case 'active':
        return AppTheme.success;
      default:
        return AppTheme.primary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'warning':
        return 'Low Stock';
      case 'active':
        return 'In Stock';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brick = widget.brick;
    final statusColor = _statusColor(brick['status'] as String);
    final isFav = brick['isFavorite'] as bool;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: () {},
          onLongPress: () => _showOptions(context),
          child: AnimatedScale(
            scale: _isPressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                // LOCKED: Card V2 Glassmorphism — BackdropFilter
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? Colors.white.withAlpha(18)
                        : Colors.white.withAlpha(184),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withAlpha(26)
                          : AppTheme.primary.withAlpha(31),
                      width: 1,
                    ),
                    // Left border accent for warning status
                    boxShadow: brick['status'] == 'warning'
                        ? [
                            BoxShadow(
                              color: AppTheme.warning.withAlpha(51),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(
                                widget.isDark ? 0.2 : 0.06,
                              ),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section — top 52% of card
                      Expanded(
                        flex: 52,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              child: CustomImageWidget(
                                imageUrl: brick['imageUrl'] as String,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                semanticLabel: brick['semanticLabel'] as String,
                              ),
                            ),
                            // Status badge — top-left
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(140),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _statusLabel(brick['status'] as String),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                            // Favorite button — top-right
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: widget.onFavoriteToggle,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(115),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFav
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 14,
                                    color: isFav
                                        ? AppTheme.tertiary
                                        : Colors.white.withAlpha(179),
                                  ),
                                ),
                              ),
                            ),
                            // Count badge — bottom-right
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withAlpha(102),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '×${brick['count']}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Info section — bottom 48%
                      Expanded(
                        flex: 48,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                brick['name'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: widget.isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1840),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Category chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondary.withAlpha(26),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: AppTheme.secondary.withAlpha(51),
                                  ),
                                ),
                                child: Text(
                                  brick['category'] as String,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.secondary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              // Piece ID + last scanned
                              Row(
                                children: [
                                  CustomIconWidget(
                                    iconName: 'qr_code',
                                    color: widget.isDark
                                        ? Colors.white.withAlpha(89)
                                        : const Color(
                                            0xFF4A4870,
                                          ).withAlpha(115),
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      brick['pieceId'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: widget.isDark
                                            ? Colors.white.withAlpha(102)
                                            : const Color(
                                                0xFF4A4870,
                                              ).withAlpha(140),
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.white.withAlpha(217),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withAlpha(26)
                        : AppTheme.primary.withAlpha(31),
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withAlpha(51)
                          : AppTheme.primary.withAlpha(51),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.brick['name'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1840),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _optionTile(
                    icon: 'edit',
                    label: 'Edit brick details',
                    isDark: isDark,
                    onTap: () => Navigator.pop(ctx),
                  ),
                  _optionTile(
                    icon: 'auto_awesome',
                    label: 'Find AI builds using this brick',
                    isDark: isDark,
                    onTap: () => Navigator.pop(ctx),
                  ),
                  _optionTile(
                    icon: 'share',
                    label: 'Share brick info',
                    isDark: isDark,
                    onTap: () => Navigator.pop(ctx),
                  ),
                  _optionTile(
                    icon: 'delete_outline',
                    label: 'Remove from inventory',
                    isDark: isDark,
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onDelete();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _optionTile({
    required String icon,
    required String label,
    required bool isDark,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppTheme.error.withAlpha(20)
              : (isDark
                    ? Colors.white.withAlpha(10)
                    : AppTheme.primary.withAlpha(10)),
          borderRadius: BorderRadius.circular(14),
          border: isDestructive
              ? Border.all(color: AppTheme.error.withAlpha(51))
              : null,
        ),
        child: Row(
          children: [
            CustomIconWidget(
              iconName: icon,
              color: isDestructive
                  ? AppTheme.error
                  : (isDark
                        ? Colors.white.withAlpha(179)
                        : const Color(0xFF4A4870)),
              size: 20,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDestructive
                    ? AppTheme.error
                    : (isDark ? Colors.white : const Color(0xFF1A1840)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
