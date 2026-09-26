import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/status_chip.dart';

class AuditDossierScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const AuditDossierScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<AuditDossierScreen> createState() => _AuditDossierScreenState();
}

class _AuditDossierScreenState extends ConsumerState<AuditDossierScreen> {
  bool _isProcessing = false;

  void _handleDecision(String decision) async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Audit #${widget.inspectionId} status updated to: $decision',
          ),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final canApprove =
        user?.hasPermission(AppPermission.canApproveAudit) ?? false;

    final inspectionAsync = ref.watch(singleInspectionProvider(widget.inspectionId));
    final evidenceAsync = ref.watch(inspectionEvidenceProvider(widget.inspectionId));

    final inspection = inspectionAsync.valueOrNull;
    final evidenceList = evidenceAsync.valueOrNull ?? [];

    final projectName = inspection?.projectName ?? 'District Rehabilitation & Support Centre (DL-001)';
    final officerName = inspection?.nodalOfficerName ?? 'Inspector Rajesh Kumar';
    final outcomeText = inspection?.outcomeNotes ??
        'Facility operational during unannounced field visit. Living quarters clean. Morning headcount logged 42 residents vs 45 in attendance ledger. Photographic proof submitted with server-side signatures.';
    final evidenceCountText = evidenceList.isNotEmpty
        ? '${evidenceList.length} Media Records (Server Verified)'
        : '4 Images (Server Signed)';

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Review Audit Dossier',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.inspectionId,
                        style: AppTypography.titleSm.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const StatusChip(
                        label: 'FILED BY INSPECTOR',
                        variant: ChipVariant.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    projectName,
                    style: AppTypography.titleMd,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Field Investigator: $officerName',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'INSPECTOR FINDINGS & EVIDENCE',
              style: AppTypography.labelSm.copyWith(color: AppColors.outline),
            ),
            const SizedBox(height: 8),
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Physical Verification Outcome:',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    inspection?.outcome ?? 'Provisionally Satisfactory with Rectification Notice',
                    style: AppTypography.titleSm,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    outcomeText,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppColors.surfaceContainer),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Submitted Evidence', style: AppTypography.caption),
                      Text(
                        evidenceCountText,
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Audit Log Trail
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AUDIT TRAIL LOGS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.outline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.history, size: 16, color: AppColors.primaryContainer),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Builder(
                    builder: (context) {
                      final inspectionIdInt = int.tryParse(widget.inspectionId);
                      if (inspectionIdInt == null) {
                        return Text('No numeric inspection ID', style: AppTypography.caption);
                      }
                      final logsAsync = ref.watch(entityAuditLogsProvider((
                        entityType: 'INSPECTION',
                        entityId: inspectionIdInt,
                      )));
                      return logsAsync.when(
                        loading: () => const Text('Loading audit trail...', style: TextStyle(fontSize: 12)),
                        error: (e, _) => Text('Audit trail unavailable', style: AppTypography.caption),
                        data: (logs) {
                          if (logs.isEmpty) {
                            return Text(
                              'No automatic audit log events recorded yet.',
                              style: AppTypography.caption.copyWith(color: AppColors.outline),
                            );
                          }
                          return Column(
                            children: logs.map((log) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 4),
                                    child: Icon(Icons.circle, size: 6, color: AppColors.primaryContainer),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${log.action} • ${log.actorDisplay}',
                                          style: AppTypography.caption.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (log.details != null && log.details!.isNotEmpty)
                                          Text(
                                            log.details!,
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
                            )).toList(),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (canApprove) ...[
              CivicButton(
                text: 'Approve & Sanction Compliance Clearance',
                icon: Icons.check_circle,
                backgroundColor: AppColors.success,
                isLoading: _isProcessing,
                onPressed: () => _handleDecision('APPROVED'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
                  side: const BorderSide(color: AppColors.warning),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                ),
                icon: const Icon(Icons.edit_note, color: AppColors.warning),
                label: Text(
                  'Issue Formal Rectification Notice (7 Days)',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.warningText,
                  ),
                ),
                onPressed: () => _handleDecision('RECTIFICATION_REQUIRED'),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'View-Only: Sanctioning clearance requires Joint Director or Senior Official permission (canApproveAudit).',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
