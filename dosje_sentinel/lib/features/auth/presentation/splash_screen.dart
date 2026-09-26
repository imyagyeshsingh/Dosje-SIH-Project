import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../app/theme/spacing.dart';
import '../../../core/auth/auth_guard.dart';
import '../../../shared/providers/core_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;

    final authState = ref.read(authStateProvider);
    if (!authState.isAuthenticated) {
      context.go('/login');
    } else {
      if (authState.isNgo) {
        final targetRoute = AuthGuard.resolveNgoInitialRoute(
          authState.ngoRegistrationStatus,
        );
        context.go(targetRoute);
      } else if (authState.isInspector) {
        context.go('/inspector/dashboard');
      } else if (authState.isOfficial) {
        context.go('/official/dashboard');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(10, 37, 64, 0.08),
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/emblem.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: AppColors.primaryContainer,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'DoSJE Sentinel',
              style: AppTypography.headlineMd.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Real-Time Monitoring & Inspection System',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ministry of Social Justice and Empowerment',
              style: AppTypography.labelSm.copyWith(color: AppColors.secondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
