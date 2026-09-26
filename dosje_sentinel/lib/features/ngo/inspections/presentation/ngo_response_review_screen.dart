import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import 'ngo_response_form_screen.dart';

class NgoResponseReviewScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const NgoResponseReviewScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<NgoResponseReviewScreen> createState() =>
      _NgoResponseReviewScreenState();
}

class _NgoResponseReviewScreenState
    extends ConsumerState<NgoResponseReviewScreen> {
  bool _isSubmitting = false;

  Future<void> _submitResponse() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() => _isSubmitting = false);
      context.go('/ngo/inspections/${widget.inspectionId}/receipt');
    }
  }

  @override
  Widget build(BuildContext context) {
    final stagedFiles = ref.watch(stagedEvidenceProvider);

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Review Submission',
        subtitle: 'Final Verification Check',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            CivicCard(
              leadingStripeColor: AppColors.saffron,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INSPECTION AUDIT DOSSIER',
                    style: AppTypography.labelSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'District Rehabilitation & Support Centre',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Ref: ${widget.inspectionId}',
                    style: AppTypography.bodySm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Written Response Section
            Text(
              'Response Summary',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            CivicCard(
              child: Text(
                'Enclosed certified staff attendance register copy for the morning session and breakfast distribution log verified by center superintendent.',
                style: AppTypography.bodyMd,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Staged Attachments
            Text(
              'Attached Ground Evidence (${stagedFiles.length})',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ...stagedFiles.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: CivicCard(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file.fileName,
                              style: AppTypography.labelMd.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${file.formattedSize} • Geo-verified GNSS Stamped',
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            CivicButton(
              label: 'Submit Official Response',
              icon: Icons.send,
              isLoading: _isSubmitting,
              onPressed: _submitResponse,
            ),
            const SizedBox(height: AppSpacing.sm),
            CivicButton(
              label: 'Back & Edit Details',
              type: ButtonType.outline,
              onPressed: () => context.pop(),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
