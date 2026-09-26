import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';

class ScheduleInspectionScreen extends ConsumerStatefulWidget {
  const ScheduleInspectionScreen({super.key});

  @override
  ConsumerState<ScheduleInspectionScreen> createState() =>
      _ScheduleInspectionScreenState();
}

class _ScheduleInspectionScreenState
    extends ConsumerState<ScheduleInspectionScreen> {
  String? _selectedProjectId;
  String _inspectionType = 'SURPRISE PHYSICAL VISIT';
  String _selectedInspectorId = 'RANDOM_PMU';
  bool _includeStaffBiometric = true;
  bool _includeKitchenSanitation = true;
  bool _includeFinancialRoster = true;
  bool _isSubmitting = false;

  Future<void> _handleSubmit() async {
    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(inspectionRepositoryProvider);
      final projectRepo = ref.read(projectRepositoryProvider);
      final projects = await projectRepo.getProjects(limit: 50);

      final targetProjectId = _selectedProjectId ?? (projects.isNotEmpty ? projects.first.id : '1');
      final matchingProject = projects.where((p) => p.id == targetProjectId).firstOrNull;
      final selectedProjectName = matchingProject?.name ?? (projects.isNotEmpty ? projects.first.name : 'Selected Facility');

      final typeBackend = _inspectionType.contains('SURPRISE') ? 'RANDOM' : 'SCHEDULED';

      if (_selectedInspectorId == 'RANDOM_PMU') {
        // Create unassigned inspection then perform authoritative backend random assignment
        final inspection = await repo.createInspection(
          projectId: targetProjectId,
          inspectionType: typeBackend,
          status: 'PENDING',
          reason: 'Surprise inspection order dispatched from Directorate.',
        );

        final assignedInspection = await repo.assignRandomInspector(inspection.id);
        final officerDisplay = assignedInspection.officerName ?? assignedInspection.officerId ?? 'Assigned Officer';

        if (mounted) {
          setState(() => _isSubmitting = false);
          _showConfirmationDialog(officerDisplay, selectedProjectName, isRandom: true);
        }
      } else {
        // Manual assignment of specific inspector
        final inspectors = await ref.read(inspectorsListProvider.future);
        final matchingInspector = inspectors.where((i) => i.inspectorId == _selectedInspectorId).firstOrNull;
        final assignedName = matchingInspector?.inspectorName ?? (inspectors.isNotEmpty ? inspectors.first.inspectorName : 'Lead Inspector');
        final assignedId = matchingInspector?.inspectorId ?? (inspectors.isNotEmpty ? inspectors.first.inspectorId : 'INS-001');

        final inspection = await repo.createInspection(
          projectId: targetProjectId,
          inspectionType: typeBackend,
          status: 'PENDING',
          officerName: assignedName,
          officerId: assignedId,
          reason: 'Authorized inspection order dispatched from Directorate.',
        );

        await repo.assignInspector(
          inspection.id,
          inspectorId: assignedId,
          inspectorName: assignedName,
        );

        if (mounted) {
          setState(() => _isSubmitting = false);
          _showConfirmationDialog(assignedName, selectedProjectName, isRandom: false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule inspection: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showConfirmationDialog(String inspectorName, String projectName, {required bool isRandom}) {
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
            Text('Audit Scheduled'),
          ],
        ),
        content: Text(
          isRandom
              ? 'Inspection order successfully scheduled and randomly assigned to $inspectorName for $projectName via Directorate automated roster. Real-time notification routed.'
              : 'Inspection order dispatched to $inspectorName for $projectName. Real-time notification routed.',
          style: AppTypography.bodySm,
        ),
        actions: [
          CivicButton(
            text: 'Return to Directorate',
            onPressed: () {
              context.pop();
              context.go('/official/dashboard');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(allRegisteredProjectsProvider);
    final inspectorsAsync = ref.watch(inspectorsListProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Schedule Inspection',
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
                    'TARGET FACILITY / PROJECT',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedProjectId),
                    initialValue: _selectedProjectId ?? projectsAsync.value?.firstOrNull?.id,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
                    items: [
                      if (projectsAsync.value == null || projectsAsync.value!.isEmpty)
                        const DropdownMenuItem(
                          value: '1',
                          child: Text('Loading registered projects...'),
                        )
                      else
                        ...?projectsAsync.value?.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              '${p.name} (${p.code})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProjectId = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'INSPECTION AUDIT TYPE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_inspectionType),
                    initialValue: _inspectionType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'SURPRISE PHYSICAL VISIT',
                        child: Text('Surprise Physical Field Visit'),
                      ),
                      DropdownMenuItem(
                        value: 'SURPRISE VIDEO CALL',
                        child: Text('Surprise Remote Video Audit'),
                      ),
                      DropdownMenuItem(
                        value: 'QUARTERLY COMPLIANCE AUDIT',
                        child: Text('Quarterly Compliance Review'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _inspectionType = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'ASSIGNED PMU INSPECTION SQUAD',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_selectedInspectorId),
                    initialValue: _selectedInspectorId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                        borderSide: const BorderSide(
                          color: AppColors.outlineVariant,
                        ),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 'RANDOM_PMU',
                        child: Row(
                          children: [
                            Icon(Icons.shuffle, size: 16, color: AppColors.secondary),
                            SizedBox(width: 6),
                            Text('Automated Random Inspector (PMU Selection)'),
                          ],
                        ),
                      ),
                      ...?inspectorsAsync.value?.map(
                        (insp) => DropdownMenuItem(
                          value: insp.inspectorId,
                          child: Text('${insp.inspectorName} (${insp.inspectorId})'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedInspectorId = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'MANDATORY VERIFICATION MODULES',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),
            CivicCard(
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Staff & Beneficiary Attendance Verification',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Biometric cross-check with enrollment registry',
                      style: AppTypography.caption,
                    ),
                    value: _includeStaffBiometric,
                    activeColor: AppColors.primaryContainer,
                    onChanged: (val) =>
                        setState(() => _includeStaffBiometric = val ?? false),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceContainer),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Kitchen & Dietary Sanitation Audit',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Pantry inspection, meal quality and food grain stocks',
                      style: AppTypography.caption,
                    ),
                    value: _includeKitchenSanitation,
                    activeColor: AppColors.primaryContainer,
                    onChanged: (val) => setState(
                      () => _includeKitchenSanitation = val ?? false,
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.surfaceContainer),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Financial Vouchers & Grant Utilization',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      'Physical verification of purchase registers',
                      style: AppTypography.caption,
                    ),
                    value: _includeFinancialRoster,
                    activeColor: AppColors.primaryContainer,
                    onChanged: (val) =>
                        setState(() => _includeFinancialRoster = val ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            CivicButton(
              text: 'Issue & Authorize Inspection Order',
              icon: Icons.check_circle_outline,
              isLoading: _isSubmitting,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
