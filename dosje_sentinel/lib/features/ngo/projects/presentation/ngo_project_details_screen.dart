import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/alert_model.dart';
import '../../../../shared/models/project_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_skeleton.dart';

final singleProjectProvider = FutureProvider.family<ProjectModel?, String>((
  ref,
  id,
) async {
  final repo = ref.watch(projectRepositoryProvider);
  return await repo.getProjectById(id);
});

class NgoProjectDetailsScreen extends ConsumerWidget {
  final String projectId;

  const NgoProjectDetailsScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(projectSummaryProvider(projectId));
    final alertsAsync = ref.watch(projectAlertsProvider(projectId));

    return Scaffold(
      appBar: CivicAppBar(
        title: 'Project Audit Detail',
        subtitle: 'DoSJE Compliance Record',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryContainer),
            tooltip: 'Refresh Summary',
            onPressed: () {
              ref.invalidate(projectSummaryProvider(projectId));
              ref.invalidate(projectAlertsProvider(projectId));
              ref.invalidate(projectAuditLogsProvider(projectId));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: LoadingSkeletonCard(height: 300)),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (summary) {
            if (summary == null) {
              return const Center(child: Text('Project not found.'));
            }

            final project = summary.project;

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Top Sync Banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.folder_shared,
                            size: 18,
                            color: AppColors.primaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text('PROJECT ID: ', style: AppTypography.labelSm),
                          Text(
                            project.code,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'SYNCED',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Hero Card
                CivicCard(
                  leadingStripeColor: AppColors.success,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DoSJE REGISTERED FACILITY',
                            style: AppTypography.labelSm,
                          ),
                          StatusChip(
                            label: project.status,
                            variant: ChipVariant.success,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        project.name,
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.corporate_fare,
                            size: 16,
                            color: AppColors.saffron,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            project.organizationName,
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: AppColors.outline,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              project.address,
                              style: AppTypography.bodySm,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLow,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assigned Nodal Officer',
                                  style: AppTypography.bodySm,
                                ),
                                Text(
                                  project.assignedNodalOfficer ?? 'N/A',
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              project.nodalOfficerDesignation ?? '',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Telemetry / Monitoring Status (NGO Scoped - No AI risk scores!)
                Text(
                  'Field Telemetry Status',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: CivicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Surveillance', style: AppTypography.bodySm),
                            const SizedBox(height: 4),
                            Text(
                              (summary.activeCameras > 0 || project.cctvOnline)
                                  ? 'ONLINE'
                                  : 'OFFLINE',
                              style: AppTypography.titleMd.copyWith(
                                color: (summary.activeCameras > 0 || project.cctvOnline)
                                    ? AppColors.success
                                    : AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${summary.activeCameras}/${summary.totalCameras > 0 ? summary.totalCameras : project.cctvTotalCameras} Cameras Live',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: CivicCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Inspection State',
                              style: AppTypography.bodySm,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (summary.pendingInspections > 0 || project.hasActiveInspection)
                                  ? 'IN PROGRESS'
                                  : 'ROUTINE',
                              style: AppTypography.titleMd.copyWith(
                                color: (summary.pendingInspections > 0 || project.hasActiveInspection)
                                    ? AppColors.saffron
                                    : AppColors.primaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              (summary.pendingInspections > 0 || project.hasActiveInspection)
                                  ? 'Surprise Evaluation'
                                  : 'Normal Schedule',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Urgent Action Banner
                if (summary.pendingInspections > 0 || summary.activeAlerts > 0 || project.hasActiveInspection) ...[
                  CivicCard(
                    leadingStripeColor: (alertsAsync.value?.isNotEmpty ?? false)
                        ? (alertsAsync.value!.first.severityEnum == AlertSeverity.critical || alertsAsync.value!.first.severityEnum == AlertSeverity.high
                            ? AppColors.error
                            : AppColors.saffron)
                        : AppColors.saffron,
                    backgroundColor: AppColors.warningBg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (alertsAsync.value?.isNotEmpty ?? false)
                                  ? Icons.crisis_alert
                                  : Icons.notification_important,
                              color: (alertsAsync.value?.isNotEmpty ?? false)
                                  ? (alertsAsync.value!.first.severityEnum == AlertSeverity.critical || alertsAsync.value!.first.severityEnum == AlertSeverity.high
                                      ? AppColors.error
                                      : AppColors.saffron)
                                  : AppColors.saffron,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (alertsAsync.value?.isNotEmpty ?? false)
                                    ? 'Active System Alert: ${alertsAsync.value!.first.alertType}'
                                    : 'Information Requested by Inspection Officer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.warningText,
                                ),
                              ),
                            ),
                            if (alertsAsync.value?.isNotEmpty ?? false)
                              StatusChip(
                                label: alertsAsync.value!.first.severity,
                                variant: alertsAsync.value!.first.severityEnum == AlertSeverity.critical || alertsAsync.value!.first.severityEnum == AlertSeverity.high
                                    ? ChipVariant.critical
                                    : ChipVariant.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          (alertsAsync.value?.isNotEmpty ?? false)
                              ? alertsAsync.value!.first.message
                              : '"Please provide the verified staff attendance register and meal counter log for the morning session."',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.warningText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        CivicButton(
                          label: 'Respond & Attach Evidence',
                          icon: Icons.upload_file,
                          onPressed: () =>
                              context.push('/ngo/inspections/ins_1/response'),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Text(
                  'COMPLIANCE AUDIT TRAIL',
                  style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                ),
                const SizedBox(height: AppSpacing.xs),
                ref.watch(projectAuditLogsProvider(projectId)).when(
                  loading: () => const LoadingSkeletonCard(height: 70),
                  error: (e, _) => CivicCard(
                    child: Text('Unable to load audit trail', style: AppTypography.caption),
                  ),
                  data: (logs) {
                    if (logs.isEmpty) {
                      return const CivicCard(
                        child: Text(
                          'No compliance audit logs recorded yet.',
                          style: TextStyle(fontSize: 12),
                        ),
                      );
                    }
                    return Column(
                      children: logs.take(5).map((log) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: CivicCard(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history,
                                  size: 20,
                                  color: AppColors.primaryContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.displayTitle,
                                        style: AppTypography.titleSm.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        log.details ?? log.actorDisplay,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  log.formattedDate,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.outline,
                                    fontSize: 10,
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
            );
          },
        ),
      ),
    );
  }
}
