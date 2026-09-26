import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';

class NgoEvidenceCaptureScreen extends ConsumerStatefulWidget {
  final String? inspectionId;

  const NgoEvidenceCaptureScreen({super.key, this.inspectionId});

  @override
  ConsumerState<NgoEvidenceCaptureScreen> createState() =>
      _NgoEvidenceCaptureScreenState();
}

class _NgoEvidenceCaptureScreenState
    extends ConsumerState<NgoEvidenceCaptureScreen> {
  bool _isCaptured = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Evidence Capture',
        subtitle: 'Ground Monitoring Stills',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Telemetry Bar
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.saffron,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '27.1982° N, 78.0059° E (Locked)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: const [
                        Icon(Icons.shield, size: 14, color: AppColors.success),
                        SizedBox(width: 4),
                        Text(
                          'GNSS STAMP ACTIVE',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Viewfinder / Preview Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Viewfinder Crosshairs or Captured state
                      if (_isCaptured) ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              'Evidence Frame Captured',
                              style: AppTypography.titleMd.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Facility_Mess_Still_0942.jpg (2.4 MB)',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.surfaceContainerHigh,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.camera_alt_outlined,
                              size: 64,
                              color: AppColors.surfaceContainerHigh,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Tap Shutter to Capture Ground Still',
                              style: AppTypography.titleMd.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auto-geotagged and timestamped',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.surfaceContainerHigh,
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Bottom Overlay
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'INS-2026-00482',
                                style: AppTypography.labelSm.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '1080p • ISO 200',
                                style: AppTypography.bodySm.copyWith(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              if (_isUploading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Uploading to Cloudinary...',
                          style: AppTypography.labelSm,
                        ),
                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: AppTypography.labelSm.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _uploadProgress,
                      backgroundColor: AppColors.surfaceContainer,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ],

              // Controls
              if (!_isCaptured) ...[
                CivicButton(
                  label: 'Snap Geotagged Photo',
                  icon: Icons.camera,
                  onPressed: () => setState(() => _isCaptured = true),
                ),
              ] else ...[
                CivicButton(
                  label: 'Upload & Submit Evidence',
                  icon: Icons.cloud_upload_outlined,
                  isLoading: _isUploading,
                  onPressed: () async {
                    setState(() => _isUploading = true);
                    try {
                      final evidenceRepo = ref.read(evidenceRepositoryProvider);
                      final targetId = widget.inspectionId ?? '1';

                      final sampleJpegBytes = <int>[
                        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
                        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
                        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
                        0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12,
                        0x13, 0x0F, 0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20,
                        0x24, 0x2E, 0x27, 0x20, 0x22, 0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29,
                        0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27, 0x39, 0x3D, 0x38, 0x32,
                        0x3C, 0x2E, 0x33, 0x34, 0x32, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01,
                        0x00, 0x01, 0x01, 0x01, 0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00,
                        0x01, 0x05, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00,
                        0x00, 0x00, 0x00, 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
                        0x09, 0x0A, 0x0B, 0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F,
                        0x00, 0x7F, 0xFF, 0xD9,
                      ];

                      await evidenceRepo.uploadInspectionEvidence(
                        inspectionId: targetId,
                        fileBytes: sampleJpegBytes,
                        fileName: 'ground_evidence_${DateTime.now().millisecondsSinceEpoch}.jpg',
                        description: 'Facility_Mess_Still_0942.jpg',
                        latitude: 27.1982,
                        longitude: 78.0059,
                        capturedAt: DateTime.now(),
                        onProgress: (p) {
                          if (mounted) setState(() => _uploadProgress = p);
                        },
                      );

                      ref.invalidate(inspectionEvidenceProvider(targetId));

                      if (mounted) {
                        setState(() => _isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Evidence uploaded and recorded.'),
                          ),
                        );
                        context.pop();
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isUploading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.xs),
                CivicButton(
                  label: 'Retake Photo',
                  type: ButtonType.secondary,
                  onPressed: () => setState(() => _isCaptured = false),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
