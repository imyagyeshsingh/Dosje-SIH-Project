import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/theme/colors.dart';
import '../../../../../app/theme/spacing.dart';
import '../../../../../app/theme/typography.dart';
import '../../../../../shared/models/ai_risk_model.dart';
import '../../../../../shared/providers/core_providers.dart';
import '../../../../../shared/widgets/civic_app_bar.dart';
import '../../../../../shared/widgets/civic_card.dart';
import '../../../../../shared/widgets/loading_skeleton.dart';
import '../../../../../shared/widgets/status_chip.dart';

class AiRiskAnalyticsScreen extends ConsumerStatefulWidget {
  const AiRiskAnalyticsScreen({super.key});

  @override
  ConsumerState<AiRiskAnalyticsScreen> createState() =>
      _AiRiskAnalyticsScreenState();
}

class _AiRiskAnalyticsScreenState
    extends ConsumerState<AiRiskAnalyticsScreen> {
  // Current SIH test project connected to the AI engine.
  static const int projectId = 163;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    // Refresh AI detections every 5 seconds.
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.invalidate(projectDetectionsProvider(projectId));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detectionsAsync =
        ref.watch(projectDetectionsProvider(projectId));   
        
    final riskAsync =
      ref.watch(projectRiskProvider(projectId));

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'AI RISK ANALYTICS TEST',
        showProfileAvatar: false,
      ),
      body: detectionsAsync.when(
        loading: () {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.screenMargin),
            child: LoadingSkeleton(
              count: 3,
              height: 140,
            ),
          );
        },

        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: CivicCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 42,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load AI detections',
                      style: AppTypography.titleSm,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Make sure the DoSJE backend is running.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        ref.invalidate(
                          projectDetectionsProvider(projectId),
                        );
                        ref.invalidate(projectRiskProvider(projectId));
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },

        data: (detections) {
          if (detections.isEmpty) {
            return const Center(
              child: Text('No AI detections available yet.'),
            );
          }

          // Make sure newest detection appears first.
          final sortedDetections = [...detections]
            ..sort(
              (a, b) => b.timestamp.compareTo(a.timestamp),
            );

          final latest = sortedDetections.first;

          return RefreshIndicator(


            onRefresh: () async {
               ref.invalidate(
                projectDetectionsProvider(projectId),
                );
                ref.invalidate(
                  projectRiskProvider(projectId),);
                  
                  
                await Future.wait([
                  ref.read(
                    projectDetectionsProvider(projectId).future,
                    ),
                    ref.read(
                      projectRiskProvider(projectId).future,
                      ),
                      ]);
                      },
         
         
              child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [

                // PROJECT RISK ANALYTICS
riskAsync.when(
  loading: () => const CivicCard(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Calculating project risk...'),
        ],
      ),
    ),
  ),

  error: (error, stackTrace) => CivicCard(
    child: Row(
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Project risk unavailable',
            style: AppTypography.titleSm,
          ),
        ),
        IconButton(
          onPressed: () {
            ref.invalidate(projectRiskProvider(projectId));
          },
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  ),

  data: (risk) {
    final score = risk?.score;
    final level = risk?.riskLevel;

    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROJECT RISK ANALYTICS',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.outline,
            ),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _MetricBox(
                  icon: Icons.shield,
                  label: 'RISK SCORE',
                  value: score != null ? '$score / 100' : '--',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: _MetricBox(
                  icon: Icons.warning_rounded,
                  label: 'RISK LEVEL',
                  value: level?.label ?? '--',
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Composite project risk calculated by the backend risk engine.',
            style: AppTypography.caption.copyWith(
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  },
),

const SizedBox(height: 16),
                // LIVE AI STATUS
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'LIVE AI STATUS',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.outline,
                            ),
                          ),
                          StatusChip(
                            label: 'LIVE',
                            variant: ChipVariant.success,
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'Project $projectId',
                        style: AppTypography.titleSm,
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _MetricBox(
                              icon: Icons.people,
                              label: 'PEOPLE',
                              value:
                                  '${latest.peopleDetected}',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricBox(
                              icon: Icons.analytics,
                              label: 'ACTIVITY',
                              value: latest.activity,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricBox(
                              icon: Icons.verified,
                              label: 'CONFIDENCE',
                              value:
                                  '${(latest.confidence * 100).toStringAsFixed(0)}%',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Camera ID: ${latest.cameraId}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.outline,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Last detection: ${_formatDateTime(latest.timestamp)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // AI DETECTION HISTORY
                Text(
                  'AI DETECTION HISTORY',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.outline,
                  ),
                ),

                const SizedBox(height: 10),

                ...sortedDetections.take(10).map(
                  (detection) {
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: 12),
                      child: CivicCard(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    detection.activity,
                                    style:
                                        AppTypography.titleSm,
                                  ),
                                ),
                                StatusChip(
                                  label:
                                      '${detection.peopleDetected} PEOPLE',
                                  variant:
                                      _activityChipVariant(
                                    detection.activity,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: [
                                const Icon(
                                  Icons.camera_alt,
                                  size: 16,
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Camera ${detection.cameraId}',
                                  style:
                                      AppTypography.caption,
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${(detection.confidence * 100).toStringAsFixed(0)}%',
                                  style:
                                      AppTypography.caption,
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Text(
                              _formatDateTime(
                                detection.timestamp,
                              ),
                              style:
                                  AppTypography.caption.copyWith(
                                color: AppColors.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  ChipVariant _activityChipVariant(String activity) {
    switch (activity.toUpperCase()) {
      case 'SUSPICIOUS':
        return ChipVariant.critical;

      case 'HIGH':
        return ChipVariant.warning;

      case 'LOW':
        return ChipVariant.warning;

      case 'NO_ACTIVITY':
        return ChipVariant.warning;

      case 'NORMAL':
      default:
        return ChipVariant.success;
    }
  }

  String _formatDateTime(DateTime time) {
    final local = time.toLocal();

    String twoDigits(int value) =>
        value.toString().padLeft(2, '0');

    return '${local.day}/${local.month}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}:'
        '${twoDigits(local.second)}';
  }
}

class _MetricBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.saffron,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTypography.labelSm.copyWith(
              color: AppColors.outline,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleSm,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}