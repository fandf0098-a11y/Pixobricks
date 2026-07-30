import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_theme.dart';
import './widgets/community_feed_tab.dart';
import './widgets/community_leaderboard_tab.dart';
import './widgets/community_search_tab.dart';
import './widgets/community_trending_tab.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;

  final List<_CommunityTab> _tabs = const [
    _CommunityTab(label: 'Feed', icon: Icons.dynamic_feed_rounded),
    _CommunityTab(label: 'Trending', icon: Icons.local_fire_department_rounded),
    _CommunityTab(label: 'Leaders', icon: Icons.emoji_events_rounded),
    _CommunityTab(label: 'Search', icon: Icons.search_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
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
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.tertiary.withOpacity(isDark ? 0.18 : 0.10),
                    AppTheme.tertiary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 280,
            left: -80,
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

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(isDark),
                _buildTabBar(isDark),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      CommunityFeedTab(isDark: isDark),
                      CommunityTrendingTab(isDark: isDark),
                      CommunityLeaderboardTab(isDark: isDark),
                      CommunitySearchTab(isDark: isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _buildUploadFab(isDark),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              'BuildVerse',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Community',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(
              AppRoutes.creatorProfileScreen,
              extra: _mockCurrentUser,
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                border: Border.all(
                  color: AppTheme.primary.withAlpha(128),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Image.network(
                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80&h=80&fit=crop',
                  fit: BoxFit.cover,
                  semanticLabel:
                      'Current user avatar — young man with short hair',
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.white.withAlpha(140),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(20)
                    : AppTheme.primary.withAlpha(30),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark
                  ? Colors.white.withAlpha(120)
                  : const Color(0xFF4A4870),
              tabs: _tabs
                  .map(
                    (t) => Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.icon, size: 14),
                          const SizedBox(width: 4),
                          Text(t.label),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadFab(bool isDark) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.uploadCreationScreen),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(115),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

const Map<String, dynamic> _mockCurrentUser = {
  'id': 'user_current',
  'username': 'BuildMaster99',
  'avatarUrl':
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=80&h=80&fit=crop',
};

class _CommunityTab {
  final String label;
  final IconData icon;
  const _CommunityTab({required this.label, required this.icon});
}
