import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/theme/colors.dart';

class OfficialScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const OfficialScaffold({super.key, required this.navigationShell});

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
            icon: Icon(Icons.corporate_fare_outlined),
            selectedIcon: Icon(
              Icons.corporate_fare,
              color: AppColors.primaryContainer,
            ),
            label: 'ALL NGOs',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(
              Icons.videocam,
              color: AppColors.primaryContainer,
            ),
            label: 'CCTV Wall',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(
              Icons.analytics,
              color: AppColors.primaryContainer,
            ),
            label: 'AI Risk',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_outlined),
            selectedIcon: Icon(
              Icons.account_balance,
              color: AppColors.primaryContainer,
            ),
            label: 'Directorate',
          ),
        ],
      ),
    );
  }
}
