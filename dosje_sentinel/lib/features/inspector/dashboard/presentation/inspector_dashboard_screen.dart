import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/inspection_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';

class InspectorDashboardScreen extends ConsumerWidget {
  const InspectorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final inspectionRepo = ref.watch(inspectionRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: CivicAppBar(
        title: 'PMU Field Inspector',
        subtitle: user?.name ?? 'Inspector Officer',
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppColors.saffron),
            tooltip: 'Launch Video Audit',
            onPressed: () => context.push('/inspector/video'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GNSS Geofence Lock Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GNSS SATELLITE TELEMETRY LOCKED',
                          style: AppTypography.labelSm.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Lat: 28.6139° N, Lon: 77.2090° E (Acc: ±3.8m)',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.gps_fixed,
                    color: AppColors.saffron,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Performance KPIs
            Row(
              children: [
                Expanded(
                  child: CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assigned',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '3',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Active today',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '28',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'This month',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Discrepancies',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '4',
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Action pending',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Banner: Initiate Surprise Video Audit
            CivicCard(
              backgroundColor: AppColors.surfaceContainerLow,
              border: Border.all(
                color: AppColors.saffron.withValues(alpha: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.saffron.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.video_call,
                      color: AppColors.saffron,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Surprise Remote Audit Call',
                          style: AppTypography.titleSm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dial an active NGO representative for unannounced live inspection',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.primaryContainer,
                    ),
                    onPressed: () => context.push('/inspector/video'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Active Field Inspections
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ASSIGNED FIELD AUDITS',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.outline,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/inspector/assignments'),
                  child: Text(
                    'View All',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            FutureBuilder<List<InspectionModel>>(
              future: inspectionRepo.getInspections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingSkeleton(count: 2, height: 120);
                }

                final inspections = snapshot.data ?? [];
                if (inspections.isEmpty) {
                  return const CivicCard(
                    child: Center(
                      child: Text('No assigned field inspections today'),
                    ),
                  );
                }

                return Column(
                  children: inspections.map((insp) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: CivicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  insp.code,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                StatusChip(
                                  label: insp.status,
                                  variant: insp.status == 'COMPLETED'
                                      ? ChipVariant.success
                                      : (insp.status == 'IN_PROGRESS'
                                            ? ChipVariant.warning
                                            : ChipVariant.neutral),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              insp.projectName,
                              style: AppTypography.titleSm,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Scheme: ${insp.schemeCode} • Nodal: ${insp.nodalOfficerName}',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: AppColors.outline,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd MMM yyyy, HH:mm')
                                          .format(insp.scheduledDate),
                                      style: AppTypography.caption,
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryContainer,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.buttonRadius,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.play_arrow, size: 16),
                                  label: const Text('Execute Audit'),
                                  onPressed: () => context.push(
                                    '/inspector/assignments/execute/${insp.id}',
                                  ),
                                ),
                              ],
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
