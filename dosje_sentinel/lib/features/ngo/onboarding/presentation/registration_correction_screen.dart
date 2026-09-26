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

class RegistrationCorrectionScreen extends ConsumerWidget {
  const RegistrationCorrectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Correction Required',
        showEmblem: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_outlined,
                  size: 40,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Clarification Needed',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.primaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'The reviewing officer has requested updates to your registered address and establishment records.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),

              CivicCard(
                leadingStripeColor: AppColors.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Application Status:'),
                        StatusChip(
                          label: 'Correction Required',
                          variant: ChipVariant.critical,
                          icon: Icons.priority_high,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Reviewing Officer Note:',
                      style: AppTypography.labelMd.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Please verify the registered office pin code and ensure official contact number corresponds to the registered society signatory.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              CivicButton(
                label: 'Edit & Resubmit Application',
                icon: Icons.edit,
                onPressed: () {
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.incomplete,
                      );
                  context.go('/ngo/onboarding/register');
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
