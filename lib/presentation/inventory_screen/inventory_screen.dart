import 'dart:ui';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_skeleton_widget.dart';
import './widgets/inventory_brick_grid_widget.dart';
import './widgets/inventory_filter_chips_widget.dart';
import './widgets/inventory_scan_fab_widget.dart';
import './widgets/inventory_search_bar_widget.dart';

/// Inventory Screen — Brick collection manager backed by Supabase
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final ScrollController _scrollController = ScrollController();

  static const List<String> _filters = [
    'All',
    'Plates',
    'Bricks',
    'Technic',
    'Special',
    'Minifigs',
  ];

  List<Map<String, dynamic>> _brickMaps = [];
  String? _error;

  List<Map<String, dynamic>> get _filteredBricks {
    return _brickMaps.where((b) {
      final matchesFilter =
          _selectedFilter == 'All' || b['category'] == _selectedFilter;
      final matchesSearch =
          _searchQuery.isEmpty ||
          (b['name'] as String? ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (b['piece_id'] as String? ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      return matchesFilter && matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await SupabaseService.instance.fetchInventoryItems();
      if (mounted) {
        setState(() {
          _brickMaps = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadInventory();
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
  }

  Future<void> _onDeleteBrick(String id) async {
    try {
      await SupabaseService.instance.deleteInventoryItem(id);
      setState(() {
        _brickMaps.removeWhere((b) => b['id'] == id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onToggleFavorite(String id) async {
    final idx = _brickMaps.indexWhere((b) => b['id'] == id);
    if (idx == -1) return;
    final current = _brickMaps[idx]['is_favorite'] as bool? ?? false;
    setState(() {
      _brickMaps[idx]['is_favorite'] = !current;
    });
    try {
      await SupabaseService.instance.toggleInventoryFavorite(id, !current);
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _brickMaps[idx]['is_favorite'] = current;
        });
      }
    }
  }

  int get _totalPieces =>
      _brickMaps.fold(0, (sum, b) => sum + ((b['count'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;
    final isLargeTablet = size.width >= 840;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      floatingActionButton: InventoryScanFabWidget(isDark: isDark),
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.backgroundGradientDark
                  : AppTheme.backgroundGradientLight,
            ),
          ),

          // Decorative orb
          Positioned(
            top: 200,
            right: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.tertiary.withOpacity(isDark ? 0.12 : 0.06),
                    AppTheme.tertiary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildAppBar(isDark),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: InventorySearchBarWidget(
                    isDark: isDark,
                    onChanged: _onSearchChanged,
                    query: _searchQuery,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                  child: InventoryFilterChipsWidget(
                    filters: _filters,
                    selected: _selectedFilter,
                    isDark: isDark,
                    onSelected: _onFilterChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _buildCountHeader(isDark),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: isLargeTablet && size.width >= 840
                      ? _buildTabletLandscapeLayout(isDark)
                      : _buildGridContent(
                          isDark: isDark,
                          crossAxisCount: isTablet ? 3 : 2,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Inventory',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF1A1840),
                    ),
                  ),
                  Text(
                    '${_brickMaps.length} brick types · $_totalPieces total pieces',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withAlpha(115)
                          : const Color(0xFF4A4870).withAlpha(153),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: _loadInventory,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(15)
                        : AppTheme.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : AppTheme.primary.withAlpha(31),
                    ),
                  ),
                  child: CustomIconWidget(
                    iconName: 'refresh',
                    color: isDark
                        ? Colors.white.withAlpha(153)
                        : const Color(0xFF4A4870),
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(31),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withAlpha(64)),
                ),
                child: CustomIconWidget(
                  iconName: 'grid_view',
                  color: AppTheme.primary,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountHeader(bool isDark) {
    final filtered = _filteredBricks;
    return Row(
      children: [
        Text(
          '${filtered.length} result${filtered.length == 1 ? '' : 's'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withAlpha(128)
                : const Color(0xFF4A4870).withAlpha(166),
          ),
        ),
        const Spacer(),
        if (_searchQuery.isNotEmpty || _selectedFilter != 'All')
          GestureDetector(
            onTap: () {
              setState(() {
                _searchQuery = '';
                _selectedFilter = 'All';
              });
            },
            child: Text(
              'Clear filters',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGridContent({
    required bool isDark,
    required int crossAxisCount,
  }) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.78,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => const CardSkeletonWidget(height: 200),
        ),
      );
    }

    if (_error != null) {
      return EmptyStateWidget(
        icon: Icons.error_outline_rounded,
        title: 'Failed to load inventory',
        description: 'Pull to refresh or tap retry to try again.',
        ctaLabel: 'Retry',
        onCtaTap: _loadInventory,
      );
    }

    final filtered = _filteredBricks;

    if (filtered.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.inventory_2_outlined,
        title: 'No bricks found',
        description: _searchQuery.isNotEmpty
            ? 'No bricks match "$_searchQuery". Try a different search term.'
            : 'Your ${_selectedFilter.toLowerCase()} collection is empty. Scan some bricks to get started!',
        ctaLabel: 'Scan Bricks',
        onCtaTap: () {},
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primary,
      backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
      child: InventoryBrickGridWidget(
        bricks: filtered,
        isDark: isDark,
        crossAxisCount: crossAxisCount,
        onDelete: _onDeleteBrick,
        onFavoriteToggle: _onToggleFavorite,
      ),
    );
  }

  Widget _buildTabletLandscapeLayout(bool isDark) {
    return Row(
      children: [
        SizedBox(
          width: 340,
          child: _buildGridContent(isDark: isDark, crossAxisCount: 2),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 20, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withAlpha(13)
                        : Colors.white.withAlpha(166),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : AppTheme.primary.withAlpha(26),
                    ),
                  ),
                  child: EmptyStateWidget(
                    icon: Icons.touch_app_outlined,
                    title: 'Select a brick',
                    description:
                        'Tap any brick in your collection to see detailed information, usage history, and AI build suggestions.',
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
