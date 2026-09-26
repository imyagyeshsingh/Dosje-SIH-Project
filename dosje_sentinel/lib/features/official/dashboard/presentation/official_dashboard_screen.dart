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
import '../../ngos/providers/official_ngos_provider.dart';

class OfficialDashboardScreen extends ConsumerWidget {
  const OfficialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final analyticsRepo = ref.watch(analyticsRepositoryProvider);
    final ngosAsync = ref.watch(allNgosProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: CivicAppBar(
        title: 'Department Directorate',
        subtitle: user?.name ?? 'Ministry Official',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryContainer),
            onPressed: () {
              ref.invalidate(allNgosProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Directorate Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: AppColors.saffron,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NATIONAL MONITORING CONSOLE',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.saffron,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Department of Social Justice & Empowerment',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Top Metric Cards
            FutureBuilder<Map<String, dynamic>>(
              future: analyticsRepo.getDashboardMetrics(),
              builder: (context, snapshot) {
                final metrics = snapshot.data ?? {};
                final totalProjects = metrics['totalProjects'] ?? 148;
                final activeInspections = metrics['activeInspections'] ?? 12;
                final pendingRegistrations =
                    metrics['pendingNgoRegistrations'] ?? 4;
                final highRisk = metrics['highRiskFacilities'] ?? 7;

                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CivicCard(
                            onTap: () => context.push('/official/ngos'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'ALL NGOs',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.outline,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ngosAsync.when(
                                  data: (ngos) => Text(
                                    '${ngos.length}',
                                    style: AppTypography.headlineSm.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  loading: () => const Text(
                                    '...',
                                    style: TextStyle(fontSize: 20),
                                  ),
                                  error: (_, __) => Text(
                                    '$totalProjects',
                                    style: AppTypography.headlineSm.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$pendingRegistrations pending review',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CivicCard(
                            onTap: () => context.push('/official/cctv'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'CCTV Streams',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.outline,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '582',
                                  style: AppTypography.headlineSm.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Online nationwide',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CivicCard(
                            onTap: () => context.push('/official/analytics'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'AI Risk Score',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.outline,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$highRisk High Risk',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.error,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Anomalies flagged',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CivicCard(
                            onTap: () => context.push('/official/scheduler'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Surprise Audits',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.outline,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 12,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$activeInspections Active',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Schedule audit',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.saffron,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Directory Access Quick Link
            CivicCard(
              backgroundColor: AppColors.surfaceContainerLow,
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
              ),
              onTap: () => context.push('/official/ngos'),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.corporate_fare,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Department "ALL NGOs" Directory',
                          style: AppTypography.titleSm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'View verified registrations, live WebSocket updates & approve onboarding',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.outline),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // High Priority Anomaly Feed
            Text(
              'BACKEND AI RISK ANOMALIES',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<AiRiskProfile>>(
              future: analyticsRepo.getRiskProfiles(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingSkeleton(count: 2, height: 90);
                }

                final profiles = snapshot.data ?? [];
                if (profiles.isEmpty) {
                  return const CivicCard(
                    child: Center(child: Text('No risk alerts')),
                  );
                }

                return Column(
                  children: profiles.map((p) {
                    final isHigh = p.riskLevel == RiskLevel.high || p.riskLevel == RiskLevel.critical;
                    final isMed = p.riskLevel == RiskLevel.medium;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CivicCard(
                        onTap: () => context.push('/official/analytics'),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isHigh
                                    ? AppColors.errorBg
                                    : (isMed
                                          ? AppColors.warningBg
                                          : AppColors.successBg),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isHigh
                                    ? Icons.crisis_alert
                                    : (isMed
                                          ? Icons.warning_amber
                                          : Icons.verified),
                                color: isHigh
                                    ? AppColors.error
                                    : (isMed
                                          ? AppColors.warning
                                          : AppColors.success),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          p.facilityName,
                                          style: AppTypography.titleSm,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      StatusChip(
                                        label: 'Score: ${p.riskScore}',
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
                                    p.riskFactors.isNotEmpty
                                        ? p.riskFactors.first.description
                                        : 'Standard monitoring metrics normal',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
