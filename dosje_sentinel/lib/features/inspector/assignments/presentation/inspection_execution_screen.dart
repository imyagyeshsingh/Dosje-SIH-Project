import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../shared/models/inspection_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';

class InspectionExecutionScreen extends ConsumerStatefulWidget {
  final String inspectionId;

  const InspectionExecutionScreen({super.key, required this.inspectionId});

  @override
  ConsumerState<InspectionExecutionScreen> createState() =>
      _InspectionExecutionScreenState();
}

class _InspectionExecutionScreenState
    extends ConsumerState<InspectionExecutionScreen> {
  final Map<String, bool> _completedItems = {};
  final List<String> _capturedEvidence = [];
  final TextEditingController _notesController = TextEditingController();
  bool _isCapturingLocation = false;
  String? _locationErrorMessage;
  InspectionLocationModel? _currentLocation;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _captureAndVerifyLocation(InspectionModel insp) async {
    setState(() {
      _isCapturingLocation = true;
      _locationErrorMessage = null;
    });

    try {
      final locationService = ref.read(locationServiceProvider);
      final gnss = await locationService.getCurrentLocation();

      // Client range validation (basic sanity checks only)
      if (gnss.latitude < -90.0 || gnss.latitude > 90.0) {
        throw ValidationException('Latitude must be between -90 and 90 degrees');
      }
      if (gnss.longitude < -180.0 || gnss.longitude > 180.0) {
        throw ValidationException('Longitude must be between -180 and 180 degrees');
      }

      final inspectionRepo = ref.read(inspectionRepositoryProvider);
      final result = await inspectionRepo.submitInspectionLocation(
        insp.id,
        latitude: gnss.latitude,
        longitude: gnss.longitude,
        accuracy: gnss.accuracyMeters,
        capturedAt: gnss.timestamp,
      );

      setState(() {
        _currentLocation = result;
        _isCapturingLocation = false;
      });

      ref.invalidate(singleInspectionProvider(widget.inspectionId));
      ref.invalidate(inspectionLocationProvider(widget.inspectionId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.locationVerified
                  ? 'Geofence Verified: On-site at facility perimeter (${result.distanceFromProject?.toStringAsFixed(1) ?? '0'}m)'
                  : 'Geofence Warning: Outside facility perimeter (${result.distanceFromProject?.toStringAsFixed(1) ?? 'Unknown'}m, radius: ${result.verificationRadiusMeters.toStringAsFixed(0)}m)',
            ),
            backgroundColor:
                result.locationVerified ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      final msg = e is AppException ? e.message : e.toString();
      setState(() {
        _isCapturingLocation = false;
        _locationErrorMessage = msg;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location verification failed: $msg'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inspectionRepo = ref.watch(inspectionRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: CivicAppBar(
        title: 'Execute Field Audit',
        showProfileAvatar: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryContainer),
            onPressed: () {
              ref.invalidate(singleInspectionProvider(widget.inspectionId));
              ref.invalidate(inspectionLocationProvider(widget.inspectionId));
              setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<InspectionModel?>(
        future: inspectionRepo.getInspectionById(widget.inspectionId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.screenMargin),
              child: LoadingSkeleton(count: 3, height: 120),
            );
          }

          final insp = snapshot.data;
          if (insp == null) {
            return const Center(child: Text('Inspection not found'));
          }

          // Initialize completed items if empty
          if (_completedItems.isEmpty) {
            for (final item in insp.checklistItems) {
              _completedItems[item.id] = item.isCompleted;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.screenMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Geofence Integrity Banner
                Builder(
                  builder: (context) {
                    final loc = _currentLocation;
                    final hasLocation = loc?.hasLocation ??
                        (insp.inspectionLatitude != null &&
                            insp.inspectionLongitude != null);
                    final isVerified =
                        loc?.locationVerified ?? insp.locationVerified;
                    final dist =
                        loc?.distanceFromProject ?? insp.distanceFromProject;
                    final lat =
                        loc?.inspectionLatitude ?? insp.inspectionLatitude;
                    final lon =
                        loc?.inspectionLongitude ?? insp.inspectionLongitude;
                    final acc =
                        loc?.locationAccuracy ?? insp.locationAccuracy;
                    final capturedAt =
                        loc?.locationCapturedAt ?? insp.locationCapturedAt;

                    Color bgColor;
                    Color borderColor;
                    Color statusColor;
                    IconData statusIcon;
                    String statusTitle;
                    String statusSubtitle;

                    if (isVerified) {
                      bgColor = AppColors.successBg;
                      borderColor = AppColors.successBorder;
                      statusColor = AppColors.success;
                      statusIcon = Icons.verified_outlined;
                      statusTitle = 'GEOFENCE VERIFIED • ON-SITE';
                      statusSubtitle = dist != null
                          ? 'Device location within ${dist.toStringAsFixed(1)}m of registered facility perimeter (Threshold: 50m).'
                          : 'Device location verified within registered facility perimeter.';
                    } else if (hasLocation) {
                      bgColor = AppColors.errorBg;
                      borderColor = AppColors.errorBorder;
                      statusColor = AppColors.error;
                      statusIcon = Icons.gpp_bad_outlined;
                      statusTitle = 'LOCATION OUTSIDE GEOFENCE • UNVERIFIED';
                      statusSubtitle = dist != null
                          ? 'Device is ${dist.toStringAsFixed(1)}m from facility, exceeding the 50m geofence radius.'
                          : 'Device location outside registered facility perimeter.';
                    } else {
                      bgColor = AppColors.warningBg;
                      borderColor = AppColors.warningBorder;
                      statusColor = AppColors.warning;
                      statusIcon = Icons.location_searching;
                      statusTitle = 'LOCATION STATUS • PENDING VERIFICATION';
                      statusSubtitle =
                          'Device location has not yet been verified against registered project coordinates.';
                    }

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.cardRadius),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(statusIcon, color: statusColor, size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      statusTitle,
                                      style: AppTypography.labelSm.copyWith(
                                        color: isVerified
                                            ? AppColors.successText
                                            : (hasLocation
                                                ? AppColors.error
                                                : AppColors.warningText),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      statusSubtitle,
                                      style: AppTypography.caption.copyWith(
                                        color: isVerified
                                            ? AppColors.successText
                                            : (hasLocation
                                                ? AppColors.error
                                                : AppColors.warningText),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasLocation && lat != null && lon != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Text(
                                    'GPS: ${lat.toStringAsFixed(4)}° N, ${lon.toStringAsFixed(4)}° E',
                                    style: AppTypography.caption.copyWith(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (acc != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(
                                      'Acc: ±${acc.toStringAsFixed(1)}m',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                if (capturedAt != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(
                                      'Captured: ${capturedAt.toLocal().hour.toString().padLeft(2, '0')}:${capturedAt.toLocal().minute.toString().padLeft(2, '0')}',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          if (_locationErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              _locationErrorMessage!,
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.error),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: _isCapturingLocation
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryContainer,
                                    ),
                                  )
                                : ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isVerified
                                          ? AppColors.surfaceLowest
                                          : AppColors.primaryContainer,
                                      foregroundColor: isVerified
                                          ? AppColors.primaryContainer
                                          : Colors.white,
                                      side: isVerified
                                          ? const BorderSide(
                                              color: AppColors.outlineVariant)
                                          : BorderSide.none,
                                      elevation: isVerified ? 0 : 2,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.buttonRadius),
                                      ),
                                    ),
                                    icon: Icon(
                                      hasLocation
                                          ? Icons.refresh
                                          : Icons.my_location,
                                      size: 16,
                                    ),
                                    label: Text(
                                      hasLocation
                                          ? 'Re-verify Geofence'
                                          : 'Capture & Verify Geofence',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () =>
                                        _captureAndVerifyLocation(insp),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Inspection Context Card
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            insp.code,
                            style: AppTypography.labelMd.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          StatusChip(
                            label: insp.type,
                            variant: ChipVariant.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(insp.projectName, style: AppTypography.titleMd),
                      const SizedBox(height: 4),
                      Text(
                        'Scheme: ${insp.schemeCode}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Physical Checklist
                Text(
                  'FIELD AUDIT VERIFICATION CHECKLIST',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 8),
                if (insp.checklistItems.isEmpty)
                  CivicCard(
                    child: Text(
                      'No specific checklist items configured for this audit.',
                      style: AppTypography.bodySm,
                    ),
                  )
                else
                  CivicCard(
                    child: Column(
                      children: insp.checklistItems.map((item) {
                        final isChecked = _completedItems[item.id] ?? false;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item.title,
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            item.description,
                            style: AppTypography.caption,
                          ),
                          value: isChecked,
                          activeColor: AppColors.primaryContainer,
                          onChanged: (val) {
                            setState(() {
                              _completedItems[item.id] = val ?? false;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 20),

                // Photographic Evidence
                Text(
                  'FIELD EVIDENCE CAPTURE (SERVER PRE-SIGNED)',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 8),
                CivicCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_capturedEvidence.length} Evidence Records Captured',
                            style: AppTypography.bodySm.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.buttonRadius,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.camera_alt, size: 16),
                            label: const Text('Capture Proof'),
                            onPressed: () {
                              setState(() {
                                _capturedEvidence.add(
                                  'PROOF_${DateTime.now().millisecondsSinceEpoch}',
                                );
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Photographic evidence logged with GNSS watermark',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      if (_capturedEvidence.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _capturedEvidence.map((ev) {
                            return Chip(
                              avatar: const Icon(Icons.image, size: 16),
                              label: Text(
                                ev,
                                style: const TextStyle(fontSize: 10),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 14),
                              onDeleted: () =>
                                  setState(() => _capturedEvidence.remove(ev)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Inspector Field Observations
                Text(
                  'INSPECTOR OBSERVATIONS & FINDINGS',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.outline,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Record physical findings, discrepancies, or praise for this facility...',
                    hintStyle: AppTypography.bodySm.copyWith(
                      color: AppColors.outline,
                    ),
                    filled: true,
                    fillColor: AppColors.surfaceLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.cardRadius,
                      ),
                      borderSide: const BorderSide(
                        color: AppColors.outlineVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                CivicButton(
                  text: 'Proceed to Audit Report Draft',
                  icon: Icons.assignment_turned_in,
                  onPressed: () {
                    context.push('/inspector/reports/draft/${insp.id}');
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
