import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import './app_navigation.dart';

/// Shell scaffold — variant-aware: extendBody true for Liquid Glass (V3)
class AppScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppScaffold({required this.navigationShell, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // V3 Liquid Glass requires extendBody: true so content renders under the blur bar
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: AppNavigation(navigationShell: navigationShell),
    );
  }
}
