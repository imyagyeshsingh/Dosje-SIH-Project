import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/video_session_model.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';

class NgoVideoCompletedScreen extends StatelessWidget {
  final VideoSessionModel session;

  const NgoVideoCompletedScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final minutes = (session.durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (session.durationSeconds % 60).toString().padLeft(2, '0');
    final nowFormatted = DateFormat('dd MMM yyyy, HH:mm:ss')
        .format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Audit Completed',
        showProfileAvatar: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Success Icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.successBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.successBorder,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Video Inspection Concluded',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.primaryNavy,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'The live remote audit feed has been securely sealed and logged on the DoSJE backend repository.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Summary Card
              CivicCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AUDIT SESSION SUMMARY',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildRow('Session Reference', session.id),
                    const Divider(
                      height: 20,
                      color: AppColors.surfaceContainer,
                    ),
                    _buildRow('Project Name', session.projectName),
                    const Divider(
                      height: 20,
                      color: AppColors.surfaceContainer,
                    ),
                    _buildRow(
                      'Conducting Official',
                      '${session.callerName} (${session.callerDesignation})',
                    ),
                    const Divider(
                      height: 20,
                      color: AppColors.surfaceContainer,
                    ),
                    _buildRow(
                      'Total Stream Duration',
                      '$minutes min $seconds sec',
                    ),
                    const Divider(
                      height: 20,
                      color: AppColors.surfaceContainer,
                    ),
                    _buildRow('Concluded At', nowFormatted),
                    const Divider(
                      height: 20,
                      color: AppColors.surfaceContainer,
                    ),
                    _buildRow(
                      'Location Telemetry',
                      'GNSS Verified (28.6139° N, 77.2090° E)',
                    ),
                  ],
                ),
              ),
              const Spacer(),

              CivicButton(
                text: 'Return to NGO Inspections',
                icon: Icons.assignment_outlined,
                onPressed: () => context.go('/ngo/inspections'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                ),
                onPressed: () => context.go('/ngo/home'),
                child: Text(
                  'Go to Home Dashboard',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AppTypography.bodySm.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryNavy,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
