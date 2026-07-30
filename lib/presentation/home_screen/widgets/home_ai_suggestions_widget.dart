import 'dart:ui';

import '../../../core/app_export.dart';

/// AI Suggestions carousel — 3 glassmorphism build suggestion cards
/// Anatomy: horizontal PageView with dot indicators
class HomeAiSuggestionsWidget extends StatefulWidget {
  final bool isDark;
  final bool isTablet;

  const HomeAiSuggestionsWidget({
    super.key,
    required this.isDark,
    this.isTablet = false,
  });

  @override
  State<HomeAiSuggestionsWidget> createState() =>
      _HomeAiSuggestionsWidgetState();
}

class _HomeAiSuggestionsWidgetState extends State<HomeAiSuggestionsWidget> {
  // TODO: Replace with [Riverpod/Bloc] for production
  int _currentPage = 0;
  final PageController _pageController = PageController(viewportFraction: 0.88);

  static final List<Map<String, dynamic>> _suggestionMaps = [
    {
      'title': 'Medieval Castle Tower',
      'description': 'Uses 342 of your bricks — 94% match with your collection',
      'difficulty': 'Intermediate',
      'pieces': 342,
      'estimatedTime': '2h 30m',
      'category': 'Architecture',
      'matchPercent': 94,
      'imageUrl':
          'https://images.unsplash.com/photo-1709656533372-03fd8b26b27e',
      'semanticLabel':
          'Medieval castle tower illustration with stone bricks and battlements against sunset sky',
      'isNew': true,
    },
    {
      'title': 'Space Shuttle Launch Pad',
      'description': 'Uses 518 bricks — 87% match. Missing 67 pieces flagged',
      'difficulty': 'Advanced',
      'pieces': 518,
      'estimatedTime': '4h 15m',
      'category': 'Space',
      'matchPercent': 87,
      'imageUrl': 'https://images.unsplash.com/photo-1546665115-8a78d41dbb91',
      'semanticLabel':
          'Space shuttle on launch pad with rocket boosters, blue sky background',
      'isNew': false,
    },
    {
      'title': 'Vintage Steam Train',
      'description':
          'Uses 228 bricks — 99% match. Perfect for your collection!',
      'difficulty': 'Beginner',
      'pieces': 228,
      'estimatedTime': '1h 45m',
      'category': 'Transport',
      'matchPercent': 99,
      'imageUrl':
          'https://images.unsplash.com/photo-1629151003498-829947804971',
      'semanticLabel':
          'Vintage steam locomotive on railway tracks with smoke, countryside setting',
      'isNew': true,
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomIconWidget(
                      iconName: 'auto_awesome',
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AI Suggestions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF1A1840),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 210,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _suggestionMaps.length,
            itemBuilder: (context, index) {
              final item = _suggestionMaps[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _buildSuggestionCard(item),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Dot indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _suggestionMaps.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentPage ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == _currentPage
                    ? AppTheme.primary
                    : (widget.isDark
                          ? Colors.white.withAlpha(51)
                          : AppTheme.primary.withAlpha(51)),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> item) {
    final isDark = widget.isDark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withAlpha(18)
                : Colors.white.withAlpha(179),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(26)
                  : AppTheme.primary.withAlpha(31),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Image section — 40% width
              SizedBox(
                width: 130,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        bottomLeft: Radius.circular(22),
                      ),
                      child: CustomImageWidget(
                        imageUrl: item['imageUrl'] as String,
                        width: 130,
                        height: 210,
                        fit: BoxFit.cover,
                        semanticLabel: item['semanticLabel'] as String,
                      ),
                    ),
                    // Match badge
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(153),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${item['matchPercent']}% match',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (item['isNew'] as bool)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Info section — 60% width
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withAlpha(31),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppTheme.secondary.withAlpha(64),
                          ),
                        ),
                        child: Text(
                          item['category'] as String,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1840),
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['description'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withAlpha(128)
                              : const Color(0xFF4A4870).withAlpha(179),
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          CustomIconWidget(
                            iconName: 'view_in_ar',
                            color: isDark
                                ? Colors.white.withAlpha(102)
                                : const Color(0xFF4A4870).withAlpha(128),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item['pieces']} pcs',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withAlpha(140)
                                  : const Color(0xFF4A4870).withAlpha(166),
                            ),
                          ),
                          const SizedBox(width: 10),
                          CustomIconWidget(
                            iconName: 'schedule',
                            color: isDark
                                ? Colors.white.withAlpha(102)
                                : const Color(0xFF4A4870).withAlpha(128),
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            item['estimatedTime'] as String,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white.withAlpha(140)
                                  : const Color(0xFF4A4870).withAlpha(166),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: const Text(
                                'Build Now',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
