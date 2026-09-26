import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/report_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';

class InspectionReportDraftScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const InspectionReportDraftScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<InspectionReportDraftScreen> createState() =>
      _InspectionReportDraftScreenState();
}

class _InspectionReportDraftScreenState
    extends ConsumerState<InspectionReportDraftScreen> {
  String _selectedVerdict = 'Provisionally Satisfactory';
  int _followUpDays = 3;
  final TextEditingController _summaryController = TextEditingController(
    text: 'Facility operational during unannounced field visit. Kitchen logbooks inspected. Staff biometric attendance showed 2 discrepancies requiring formal reconciliation.',
  );
  final TextEditingController _actionController = TextEditingController(
    text: 'Submit certified biometric monthly punch roster and supplier invoice reconciliations.',
  );
  bool _isSubmitting = false;

  @override
  void dispose() {
    _summaryController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmitReport() async {
    setState(() => _isSubmitting = true);
    try {
      final inspectionRepo = ref.read(inspectionRepositoryProvider);
      final reportRepo = ref.read(reportRepositoryProvider);

      final inspection = await inspectionRepo.getInspectionById(widget.inspectionId);
      final projId = inspection != null
          ? (int.tryParse(inspection.projectId) ?? 1)
          : 1;
      final inspId = inspection != null
          ? (int.tryParse(inspection.id) ?? 1)
          : (int.tryParse(widget.inspectionId) ?? 1);

      await reportRepo.createReport(
        projectId: projId,
        inspectionId: inspId,
        reportType: ReportType.inspection,
        status: ReportStatus.finalStatus,
        title: 'Field Audit Report - ${widget.inspectionId}',
        summary: _summaryController.text.trim(),
        findings: 'Verdict: $_selectedVerdict. Timeline: $_followUpDays days.',
        recommendations: _actionController.text.trim(),
        generatedAt: DateTime.now(),
      );

      // Invalidate relevant providers to ensure freshness
      ref.invalidate(projectReportsProvider(projId));
      ref.invalidate(singleInspectionProvider(widget.inspectionId));
      ref.invalidate(auditLogsProvider);
      ref.invalidate(projectAuditLogsProvider(projId));

      if (mounted) {
        setState(() => _isSubmitting = false);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: AppColors.success, size: 28),
                SizedBox(width: 8),
                Text('Audit Dossier Filed'),
              ],
            ),
            content: Text(
              'Field audit report for #${widget.inspectionId} has been submitted to the Department Directorate for review and action tracking.',
              style: AppTypography.bodySm,
            ),
            actions: [
              CivicButton(
                text: 'Return to Dashboard',
                onPressed: () {
                  context.pop(); // pop dialog
                  context.go('/inspector/dashboard');
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Draft Audit Report',
        showProfileAvatar: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INSPECTION AUDIT DOSSIER',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Reference ID: ${widget.inspectionId}',
                    style: AppTypography.titleSm,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Filed under PMU Special Enforcement Squad',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Official Evaluation Verdict
            Text(
              'EVALUATION VERDICT',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),
            CivicCard(
              child: DropdownButtonFormField<String>(
                value: _selectedVerdict,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  border: InputBorder.none,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Fully Satisfactory',
                    child: Text('Fully Satisfactory (Approved)'),
                  ),
                  DropdownMenuItem(
                    value: 'Provisionally Satisfactory',
                    child: Text('Provisionally Satisfactory'),
                  ),
                  DropdownMenuItem(
                    value: 'Correction Required',
                    child: Text('Correction / Action Required'),
                  ),
                  DropdownMenuItem(
                    value: 'Critical Discrepancy',
                    child: Text('Critical Discrepancy (Flagged)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedVerdict = val);
                },
              ),
            ),
            const SizedBox(height: 16),

            // Findings Summary
            Text(
              'EXECUTIVE FINDINGS SUMMARY',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summaryController,
              maxLines: 4,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Notice & Deadline
            Text(
              'PRESCRIBED REMEDIATION ACTION',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _actionController,
              maxLines: 3,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'CORRECTIVE TIMELINE DEADLINE',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),
            CivicCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDayOption(3, '3 Days'),
                  _buildDayOption(7, '7 Days'),
                  _buildDayOption(14, '14 Days'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            CivicButton(
              text: 'Submit Official Report to Directorate',
              icon: Icons.send_rounded,
              isLoading: _isSubmitting,
              onPressed: _handleSubmitReport,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayOption(int days, String label) {
    final isSelected = _followUpDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _followUpDays = days),
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
