import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';

class NgoFollowUpScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const NgoFollowUpScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<NgoFollowUpScreen> createState() => _NgoFollowUpScreenState();
}

class _NgoFollowUpScreenState extends ConsumerState<NgoFollowUpScreen> {
  final _commentController = TextEditingController(
    text: 'Submitting signed staff movement roster certified by superintendent and verified meal pantry receipts.',
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Follow-up compliance response submitted successfully.',
          ),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Follow-Up Action',
        subtitle: 'Compliance Resolution',
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
                  Text('ACTION REQUIRED', style: AppTypography.labelSm),
                  const SizedBox(height: 2),
                  Text(
                    'Staff Movement & Dietary Register Clarification',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deadline: 26 Sep 2026 • Status: PENDING RESOLUTION',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Explanation & Response Comments',
              style: AppTypography.labelLg,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter compliance response explanation...',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            CivicCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    color: AppColors.primaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Movement_Roster_Signed.pdf',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '1.2 MB • Ready to sync',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            CivicButton(
              label: 'Submit Follow-Up Dossier',
              icon: Icons.check_circle_outline,
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
