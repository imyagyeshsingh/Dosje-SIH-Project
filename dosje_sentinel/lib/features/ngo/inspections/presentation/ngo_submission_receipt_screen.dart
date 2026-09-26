import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';

class NgoSubmissionReceiptScreen extends ConsumerWidget {
  final String inspectionId;

  const NgoSubmissionReceiptScreen({super.key, required this.inspectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Submission Receipt',
        subtitle: 'Official Acknowledgement',
        showEmblem: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            // Success Header Card
            CivicCard(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: AppColors.successBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: AppColors.success,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Evidence Submitted Successfully',
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.primaryContainer,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Official Response Recorded for $inspectionId',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RECEIPT #: RESP-2026-00321',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Real-Time Status Pipeline
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('WORKFLOW STATUS', style: AppTypography.labelSm),
                      const StatusChip(
                        label: 'In Review',
                        variant: ChipVariant.warning,
                        icon: Icons.hourglass_top,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      _buildPipelineStep(
                        'Submitted',
                        '11:02 AM',
                        true,
                        isFirst: true,
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      _buildPipelineStep('In Review', 'Nodal Officer', true),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: AppColors.outlineVariant,
                        ),
                      ),
                      _buildPipelineStep(
                        'Finalized',
                        'Pending',
                        false,
                        isLast: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Submission Details & Manifest
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submission Manifest Details',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 16),
                  _buildManifestRow(
                    'Timestamp:',
                    '23 Sep 2026, 11:02:44 AM IST',
                  ),
                  _buildManifestRow(
                    'Signatory:',
                    'Shri Rajesh Sharma (Project Director)',
                  ),
                  _buildManifestRow(
                    'Facility:',
                    'District Rehabilitation & Support Centre',
                  ),
                  _buildManifestRow(
                    'Supervising Desk:',
                    'Department of Social Justice and Empowerment',
                  ),
                  const Divider(height: 16),
                  Text(
                    'Cryptographic Evidence Files (2)',
                    style: AppTypography.labelSm,
                  ),
                  const SizedBox(height: 6),
                  _buildFileReceiptItem(
                    'Attendance_Register_23Sep2026_Morning.jpg',
                    '8f4a21...e12d90a',
                  ),
                  const SizedBox(height: 4),
                  _buildFileReceiptItem(
                    'Breakfast_Nutrition_Distribution_Log.pdf',
                    '3c9b44...a7810fc',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            CivicButton(
              label: 'Return to Home Dashboard',
              icon: Icons.home,
              onPressed: () => context.go('/ngo/home'),
            ),
            const SizedBox(height: AppSpacing.sm),
            CivicButton(
              label: 'View Project Details',
              type: ButtonType.secondary,
              onPressed: () => context.go('/ngo/projects/proj_1'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStep(
    String label,
    String sub,
    bool active, {
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryContainer
                : AppColors.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            active ? Icons.check : Icons.circle_outlined,
            size: 14,
            color: active ? Colors.white : AppColors.outline,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(sub, style: AppTypography.bodySm.copyWith(fontSize: 9)),
      ],
    );
  }

  Widget _buildManifestRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTypography.bodySm)),
          Expanded(
            child: Text(
              value,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileReceiptItem(String fileName, String optionalHash) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: AppTypography.labelSm.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Integrity SHA-256: $optionalHash',
                  style: AppTypography.bodySm.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
