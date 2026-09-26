import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/ai_risk_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';

class AiRiskAnalyticsScreen extends ConsumerWidget {
  const AiRiskAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsRepo = ref.watch(analyticsRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'AI Risk Analytics',
        showProfileAvatar: false,
      ),
      body: FutureBuilder<List<AiRiskProfile>>(
        future: analyticsRepo.getRiskProfiles(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.screenMargin),
              child: LoadingSkeleton(count: 3, height: 140),
            );
          }

          final profiles = snapshot.data ?? [];
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              final isHigh = profile.riskLevel == RiskLevel.high || profile.riskLevel == RiskLevel.critical;
              final isMed = profile.riskLevel == RiskLevel.medium;

              return CivicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            profile.facilityName,
                            style: AppTypography.titleSm,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        StatusChip(
                          label: 'RISK: ${profile.riskScore}',
                          variant: isHigh
                              ? ChipVariant.critical
                              : (isMed
                                    ? ChipVariant.warning
                                    : ChipVariant.success),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Facility ID: ${profile.facilityId}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Risk Progress Indicator
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: profile.riskScore / 100.0,
                        backgroundColor: AppColors.surfaceContainer,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isHigh
                              ? AppColors.error
                              : (isMed ? AppColors.warning : AppColors.success),
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Risk Factors
                    if (profile.riskFactors.isNotEmpty) ...[
                      Text(
                        'IDENTIFIED RISK ANOMALIES',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...profile.riskFactors.map((factor) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.bolt,
                                color: AppColors.error,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${factor.title}: ${factor.description} (+${factor.scoreImpact} pts)',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                    ],

                    // Action Trigger
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          icon: const Icon(
                            Icons.flash_on,
                            size: 16,
                            color: AppColors.saffron,
                          ),
                          label: Text(
                            'Dispatch Surprise Audit',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.saffron,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            context.push('/official/scheduler');
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
