import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/evidence_model.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';

final stagedEvidenceProvider = StateProvider.autoDispose<List<EvidenceModel>>((
  ref,
) {
  return [
    EvidenceModel(
      id: 'staged_1',
      inspectionId: 'INS-2026-00482',
      title: 'Staff Attendance Register Roster',
      fileName: 'Attendance_Register_23Sep2026_Morning.jpg',
      fileType: 'JPG',
      fileSizeBytes: 2400000,
      isGeoVerified: true,
      latitude: 27.1982,
      longitude: 78.0059,
      timestamp: DateTime.now(),
      sha256Hash: '8f4a21e12d90a78b54c0e6f3329184ba',
    ),
    EvidenceModel(
      id: 'staged_2',
      inspectionId: 'INS-2026-00482',
      title: 'Breakfast Distribution Log',
      fileName: 'Breakfast_Nutrition_Distribution_Log.pdf',
      fileType: 'PDF',
      fileSizeBytes: 840000,
      isGeoVerified: true,
      latitude: 27.1982,
      longitude: 78.0059,
      timestamp: DateTime.now(),
      sha256Hash: '3c9b44a7810fc11894d87210e53a02bb',
    ),
  ];
});

class NgoResponseFormScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const NgoResponseFormScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<NgoResponseFormScreen> createState() =>
      _NgoResponseFormScreenState();
}

class _NgoResponseFormScreenState extends ConsumerState<NgoResponseFormScreen> {
  final _responseController = TextEditingController(
    text: 'Enclosed certified staff attendance register copy for the morning session and breakfast distribution log verified by center superintendent.',
  );

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  void _addEvidenceItem(
    String title,
    String fileName,
    String fileType,
    int size,
  ) {
    final list = ref.read(stagedEvidenceProvider);
    final newItem = EvidenceModel(
      id: 'staged_${DateTime.now().millisecondsSinceEpoch}',
      inspectionId: widget.inspectionId,
      title: title,
      fileName: fileName,
      fileType: fileType,
      fileSizeBytes: size,
      isGeoVerified: true,
      latitude: 27.1982,
      longitude: 78.0059,
      timestamp: DateTime.now(),
      sha256Hash: 'a7810fc3c9b44${DateTime.now().millisecondsSinceEpoch}',
    );
    ref.read(stagedEvidenceProvider.notifier).state = [...list, newItem];
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Attached: $fileName')));
  }

  @override
  Widget build(BuildContext context) {
    final stagedFiles = ref.watch(stagedEvidenceProvider);

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Inspection Response',
        subtitle: 'Official Evidentiary Submission',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            // Context Banner
            CivicCard(
              backgroundColor: AppColors.primaryContainer,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INSPECTION: ${widget.inspectionId}',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondaryFixed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Staff Attendance & Meal Log',
                    style: AppTypography.titleMd.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ground monitoring response for surprise evaluation session.',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.surfaceContainerHigh,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Written Response Text Input
            Text(
              'Written Response Statement',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _responseController,
              maxLines: 4,
              style: AppTypography.bodyMd,
              decoration: const InputDecoration(
                hintText: 'Provide official comments or clarifications...',
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Action Tiles: Take Photo, Record Video, Upload Document, Photo Library
            Text(
              'Capture Ground Evidence',
              style: AppTypography.labelLg.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.photo_camera,
                    title: 'Take Photo',
                    subtitle: 'Auto-Geotagged',
                    color: AppColors.saffron,
                    onTap: () => _addEvidenceItem(
                      'Live Facility Photo',
                      'Facility_Still_${DateTime.now().minute}.jpg',
                      'JPG',
                      1800000,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.videocam,
                    title: 'Record Video',
                    subtitle: '60s Walkthrough',
                    color: AppColors.primaryContainer,
                    onTap: () => _addEvidenceItem(
                      'Walkthrough Video',
                      'Inspection_Video_${DateTime.now().minute}.mp4',
                      'MP4',
                      8500000,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.drive_folder_upload,
                    title: 'Upload File',
                    subtitle: 'PDF, XLSX copies',
                    color: AppColors.primaryContainer,
                    onTap: () => _addEvidenceItem(
                      'Document Roster',
                      'Certified_Log_${DateTime.now().minute}.pdf',
                      'PDF',
                      920000,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildActionTile(
                    icon: Icons.photo_library,
                    title: 'Photo Library',
                    subtitle: 'Inspection stills',
                    color: AppColors.primaryContainer,
                    onTap: () => _addEvidenceItem(
                      'Gallery Stills',
                      'Ground_Still_${DateTime.now().minute}.jpg',
                      'JPG',
                      2100000,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Staged Files Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Staged Evidence (${stagedFiles.length})',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('Max 50 MB total', style: AppTypography.bodySm),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ...stagedFiles.map(
              (file) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: CivicCard(
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          file.fileType == 'PDF'
                              ? Icons.description
                              : Icons.image,
                          color: AppColors.primaryContainer,
                          size: 20,
                        ),
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${file.formattedSize} • Geo-verified (27.1982° N, 78.0059° E)',
                              style: AppTypography.bodySm.copyWith(
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed: () {
                          ref
                              .read(stagedEvidenceProvider.notifier)
                              .state = stagedFiles
                              .where((e) => e.id != file.id)
                              .toList();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            CivicButton(
              label: 'Proceed to Review & Confirm',
              icon: Icons.arrow_forward,
              onPressed: () {
                context.push('/ngo/inspections/${widget.inspectionId}/review');
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceLowest,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.labelMd.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(subtitle, style: AppTypography.bodySm.copyWith(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
