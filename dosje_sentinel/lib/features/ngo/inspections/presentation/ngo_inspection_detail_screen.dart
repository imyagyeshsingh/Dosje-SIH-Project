import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';


class NgoInspectionDetailScreen extends ConsumerWidget {
  final String inspectionId;

  const NgoInspectionDetailScreen({super.key, required this.inspectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspectionAsync = ref.watch(singleInspectionProvider(inspectionId));

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Project Audit Detail',
        subtitle: 'DoSJE Compliance Record',
      ),
      body: SafeArea(
        child: inspectionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (inspection) {
            if (inspection == null) {
              return const Center(child: Text('Inspection not found.'));
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                // Top Notice Card
                CivicCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.security,
                        color: AppColors.saffron,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Surprise Verification Notice',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              inspection.code,
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              inspection.projectName,
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Status & Nodal Officer Details
                CivicCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          StatusChip(
                            label: inspection.status == 'IN_PROGRESS'
                                ? 'In Progress'
                                : inspection.status,
                            variant: ChipVariant.warning,
                          ),
                          Text(inspection.type, style: AppTypography.labelSm),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildDetailRow(
                        'Lead Nodal Officer',
                        '${inspection.nodalOfficerName}\n(${inspection.nodalOfficerDesignation})',
                      ),
                      if (inspection.officerId != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow('Inspector ID', inspection.officerId!),
                      ],
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Assignment Status',
                        inspection.assignmentStatus,
                      ),
                      if (inspection.assignedAt != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Assigned At',
                          '${inspection.assignedAt!.toLocal().day.toString().padLeft(2, '0')}/${inspection.assignedAt!.toLocal().month.toString().padLeft(2, '0')}/${inspection.assignedAt!.toLocal().year} ${inspection.assignedAt!.toLocal().hour.toString().padLeft(2, '0')}:${inspection.assignedAt!.toLocal().minute.toString().padLeft(2, '0')}',
                        ),
                      ],
                      if (inspection.inspectionLatitude != null) ...[
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Geofence Status',
                          inspection.locationVerified
                              ? 'VERIFIED ON-SITE (${inspection.distanceFromProject != null ? "${inspection.distanceFromProject!.toStringAsFixed(1)}m" : "<50m"})'
                              : 'OUTSIDE GEOFENCE (${inspection.distanceFromProject != null ? "${inspection.distanceFromProject!.toStringAsFixed(1)}m" : "Unverified"})',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'GPS Coordinates',
                          '${inspection.inspectionLatitude!.toStringAsFixed(4)}° N, ${inspection.inspectionLongitude!.toStringAsFixed(4)}° E',
                        ),
                      ],
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Sync Channel',
                        inspection.syncChannel ?? 'Direct Telemetry Handshake',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Information Request Card
                if (inspection.requests.isNotEmpty) ...[
                  CivicCard(
                    leadingStripeColor: AppColors.saffron,
                    backgroundColor: AppColors.warningBg,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.assignment_late,
                                  color: AppColors.saffron,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Official Evidence Request #REQ-01',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warningText,
                                  ),
                                ),
                              ],
                            ),
                            const StatusChip(
                              label: 'Urgent',
                              variant: ChipVariant.critical,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          inspection.requests.first.description,
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.warningText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: const [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: AppColors.saffron,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Geotagged & Timestamped Evidence Mandatory',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warningText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Required Submissions Checklist
                Text(
                  'Required Submissions',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ...inspection.checklistItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: CivicCard(
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                item.id.replaceAll('chk_', ''),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: AppTypography.labelMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  item.description,
                                  style: AppTypography.bodySm,
                                ),
                              ],
                            ),
                          ),
                          StatusChip(
                            label: item.isOptional ? 'Optional' : 'Pending',
                            variant: item.isOptional
                                ? ChipVariant.neutral
                                : ChipVariant.warning,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                CivicButton(
                  label: 'Respond & Attach Evidence',
                  icon: Icons.add_a_photo,
                  onPressed: () => context.push(
                    '/ngo/inspections/${inspection.id}/response',
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                CivicButton(
                  label: 'Join Live Video Call',
                  icon: Icons.videocam,
                  type: ButtonType.secondary,
                  onPressed: () async {
                    try {
                      final repo = ref.read(videoSessionRepositoryProvider);
                      final session = await repo.createVideoSessionForInspection(inspection.id);
                      if (context.mounted) {
                        context.push('/ngo/video/session', extra: session);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        context.push('/ngo/video/incoming');
                      }
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.bodySm),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
