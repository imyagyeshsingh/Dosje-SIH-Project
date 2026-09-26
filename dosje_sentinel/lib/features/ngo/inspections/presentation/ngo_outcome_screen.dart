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

class NgoOutcomeScreen extends ConsumerWidget {
  final String inspectionId;

  const NgoOutcomeScreen({super.key, required this.inspectionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Inspection Outcome',
        subtitle: 'Official Audit Findings',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            // Status Certificate Card
            CivicCard(
              leadingStripeColor: AppColors.success,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      StatusChip(
                        label: 'Evaluation Result',
                        variant: ChipVariant.info,
                      ),
                      Text(
                        '23 Sep 2026',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'PROVISIONALLY SATISFACTORY',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSecondaryFixed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'District Rehabilitation & Support Centre',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Facility Code: DSJ-AG-1042 • Agra Division',
                    style: AppTypography.bodySm,
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Official Audit Ref:', style: AppTypography.bodySm),
                      Text(
                        'E-AUDIT-2026-77892-UP',
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lead Officer:', style: AppTypography.bodySm),
                      Text(
                        'Shri V. K. Saxena (Dy. Director)',
                        style: AppTypography.labelMd,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Verified Ground Metrics (3-column bento)
            Row(
              children: [
                Expanded(
                  child: CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.groups,
                          color: AppColors.primaryContainer,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '24 / 25',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Headcount OK',
                          style: AppTypography.bodySm.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.timer,
                          color: AppColors.primaryContainer,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '43 mins',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Stream Verified',
                          style: AppTypography.bodySm.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: CivicCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.saffron,
                          size: 20,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '100%',
                          style: AppTypography.titleMd.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Geo Perimeter',
                          style: AppTypography.bodySm.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Official Observations
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.rate_review,
                        color: AppColors.primaryContainer,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Official Observations',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Facility operational during surprise evaluation. Living quarters and dietary counters inspected via encrypted live stream.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info, size: 16, color: AppColors.saffron),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Biometric attendance register physical verification conducted; 2 staff members were on scheduled field outreach.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Required Follow-Up Action Card
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
                            Icons.pending_actions,
                            color: AppColors.saffron,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Mandatory Compliance Step',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.warningText,
                            ),
                          ),
                        ],
                      ),
                      const StatusChip(
                        label: 'Pending',
                        variant: ChipVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Submit verified meal log register copies and signed staff movement roster within 3 days.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.warningText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  CivicButton(
                    label: 'Respond to Follow-Up Action',
                    icon: Icons.upload_file,
                    onPressed: () => context.push(
                      '/ngo/inspections/$inspectionId/follow-up',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
