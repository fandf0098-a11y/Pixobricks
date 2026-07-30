import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_export.dart';
import '../../providers/user_profile_provider.dart';
import './widgets/home_activity_feed_widget.dart';
import './widgets/home_ai_suggestions_widget.dart';
import './widgets/home_greeting_widget.dart';
import './widgets/home_hud_bar_widget.dart';
import './widgets/home_quick_actions_widget.dart';
import './widgets/home_quick_stats_widget.dart';

/// Home Screen — Primary dashboard
/// Density: D2 Conversational — hero stats + AI suggestions + activity feed
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  bool _hudElevated = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final elevated = _scrollController.offset > 10;
      if (elevated != _hudElevated) {
        setState(() => _hudElevated = elevated);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() => _isLoading = true);
    // Refresh user profile from Supabase
    await ref.read(userProfileProvider.notifier).loadProfile();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.backgroundGradientDark
                  : AppTheme.backgroundGradientLight,
            ),
          ),

          // ── Decorative orbs ──────────────────────────────────────────
          Positioned(
            top: 100,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                    AppTheme.primary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withOpacity(isDark ? 0.12 : 0.06),
                    AppTheme.secondary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),

          // ── Main scrollable content ──────────────────────────────────
          SafeArea(
            bottom: false,
            child: isTablet
                ? _buildTabletLayout(isDark)
                : _buildPhoneLayout(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(bool isDark) {
    return Column(
      children: [
        // Fixed HUD bar
        HomeHudBarWidget(isDark: isDark, isElevated: _hudElevated),

        // Scrollable body
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.primary,
            backgroundColor: isDark
                ? AppTheme.surfaceDark
                : AppTheme.surfaceLight,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: HomeGreetingWidget(isDark: isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: HomeQuickStatsWidget(isDark: isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 28, 0, 0),
                    child: HomeAiSuggestionsWidget(isDark: isDark),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: HomeActivityFeedWidget(isDark: isDark),
                  ),
                ),
                // Bottom padding for Liquid Glass nav bar
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(bool isDark) {
    return Column(
      children: [
        HomeHudBarWidget(isDark: isDark, isElevated: _hudElevated),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppTheme.primary,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column — primary content
                Expanded(
                  flex: 6,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 12, 0),
                          child: HomeGreetingWidget(isDark: isDark),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 12, 0),
                          child: HomeAiSuggestionsWidget(
                            isDark: isDark,
                            isTablet: true,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 12, 0),
                          child: HomeActivityFeedWidget(isDark: isDark),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 120)),
                    ],
                  ),
                ),

                // Right sidebar
                SizedBox(
                  width: 280,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 20, 24, 120),
                    child: Column(
                      children: [
                        HomeQuickStatsWidget(isDark: isDark, isTablet: true),
                        const SizedBox(height: 20),
                        HomeQuickActionsWidget(isDark: isDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
