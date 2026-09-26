import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/video_session_model.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';

import '../../../../shared/providers/core_providers.dart';

class InspectorVideoScreen extends ConsumerStatefulWidget {
  const InspectorVideoScreen({super.key});

  @override
  ConsumerState<InspectorVideoScreen> createState() =>
      _InspectorVideoScreenState();
}

class _InspectorVideoScreenState extends ConsumerState<InspectorVideoScreen> {
  String _selectedProject = 'District Rehabilitation & Support Centre';
  String _selectedRepresentative = 'Dr. Vikramaditya Rathore';
  bool _isDialing = false;

  void _initiateAuditCall() async {
    setState(() => _isDialing = true);
    try {
      final repo = ref.read(videoSessionRepositoryProvider);
      final session = await repo.createVideoSession(
        projectId: 1,
        officerName: 'PMU Squad Inspector',
        representativeName: _selectedRepresentative,
      );
      if (mounted) {
        setState(() => _isDialing = false);
        context.push('/ngo/video/session', extra: session);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isDialing = false);
        final session = VideoSessionModel(
          id: 'VID-SURPRISE-${DateTime.now().millisecondsSinceEpoch}',
          inspectionId: 'ins_1',
          projectName: _selectedProject,
          callerName: 'PMU Squad Inspector',
          callerDesignation: 'Field Inspection Directorate',
          startedAt: DateTime.now(),
          status: VideoSessionStatus.active,
        );
        context.push('/ngo/video/session', extra: session);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Surprise Video Audit',
        showProfileAvatar: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Alert
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unannounced video audit calls trigger immediate high-priority alerts on the NGO representative terminal. Ensure call recording is legally acknowledged.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.warningText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TARGET PROJECT FACILITY',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProject,
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
                        value: 'District Rehabilitation & Support Centre',
                        child: Text(
                          'District Rehabilitation & Support Centre (DL-001)',
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Integrated Child Development & Daycare',
                        child: Text(
                          'Integrated Child Development & Daycare (VR-002)',
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProject = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NODAL NGO REPRESENTATIVE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedRepresentative,
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
                        value: 'Dr. Vikramaditya Rathore',
                        child: Text(
                          'Dr. Vikramaditya Rathore (Project Director)',
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null)
                        setState(() => _selectedRepresentative = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            CivicCard(
              backgroundColor: AppColors.surfaceLowest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AUDIT PROTOCOL REQUIREMENTS',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildProtocolItem(
                    Icons.lock_clock,
                    '45-second connection handshake SLA',
                  ),
                  _buildProtocolItem(
                    Icons.videocam,
                    'Encrypted bidirectional WebRTC stream',
                  ),
                  _buildProtocolItem(
                    Icons.location_on,
                    'Automatic GNSS & temporal watermarking',
                  ),
                  _buildProtocolItem(
                    Icons.cloud_upload,
                    'Realtime cloud archival on secure backend',
                  ),
                ],
              ),
            ),
            const Spacer(),

            CivicButton(
              text: 'Initiate Surprise Audit Stream',
              icon: Icons.video_call,
              backgroundColor: AppColors.primaryContainer,
              isLoading: _isDialing,
              onPressed: _initiateAuditCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTypography.bodySm)),
        ],
      ),
    );
  }
}
