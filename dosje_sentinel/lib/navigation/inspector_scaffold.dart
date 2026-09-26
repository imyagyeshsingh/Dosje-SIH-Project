import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme/colors.dart';

class InspectorScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const InspectorScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        backgroundColor: AppColors.surfaceLowest,
        indicatorColor: AppColors.surfaceContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(
              Icons.dashboard,
              color: AppColors.primaryContainer,
            ),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(
              Icons.fact_check,
              color: AppColors.primaryContainer,
            ),
            label: 'Assigned',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(
              Icons.videocam,
              color: AppColors.primaryContainer,
            ),
            label: 'Surprise Video',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            selectedIcon: Icon(Icons.badge, color: AppColors.primaryContainer),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
