import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme/colors.dart';

class NgoScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NgoScaffold({super.key, required this.navigationShell});

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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppColors.primaryContainer),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder, color: AppColors.primaryContainer),
            label: 'Projects',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(
              Icons.assignment,
              color: AppColors.primaryContainer,
            ),
            label: 'Inspections',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(
              Icons.notifications,
              color: AppColors.primaryContainer,
            ),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primaryContainer),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
