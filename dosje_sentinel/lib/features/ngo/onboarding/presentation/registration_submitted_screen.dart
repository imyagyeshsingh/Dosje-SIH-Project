import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/ngo_registration_status.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';

class RegistrationSubmittedScreen extends ConsumerWidget {
  const RegistrationSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Registration Submitted',
        showEmblem: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            children: [
              const Spacer(),
              // Success Icon Container
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.successBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mark_email_read_outlined,
                  size: 40,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Registration Submitted',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.primaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Your NGO registration profile has been recorded on central DoSJE servers and queued for initial administrative intake.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Status Card
              CivicCard(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Current Status:'),
                        StatusChip(
                          label: 'Submitted',
                          variant: ChipVariant.info,
                          icon: Icons.hourglass_top,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Organization:', style: AppTypography.bodySm),
                        Text(
                          'Samarpan Welfare Society',
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Registration Ref:', style: AppTypography.bodySm),
                        Text('NGO-UP-8821', style: AppTypography.labelMd),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Action buttons (including demo transition for testing)
              CivicButton(
                label: 'Check Under Review Status',
                icon: Icons.refresh,
                onPressed: () {
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.underReview,
                      );
                  context.go('/ngo/onboarding/under-review');
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              CivicButton(
                label: 'Sign Out',
                type: ButtonType.outline,
                onPressed: () {
                  ref.read(authStateProvider.notifier).signOut();
                  context.go('/login');
                },
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
