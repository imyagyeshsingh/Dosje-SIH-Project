import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/loading_skeleton.dart';

class CctvMonitorScreen extends ConsumerStatefulWidget {
  const CctvMonitorScreen({super.key});

  @override
  ConsumerState<CctvMonitorScreen> createState() => _CctvMonitorScreenState();
}

class _CctvMonitorScreenState extends ConsumerState<CctvMonitorScreen> {
  String? _selectedFacilityId;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(allRegisteredProjectsProvider);
    final camerasAsync = ref.watch(cctvCamerasProvider(_selectedFacilityId));

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: CivicAppBar(
        title: 'CCTV Monitoring Wall',
        showProfileAvatar: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryContainer),
            tooltip: 'Refresh CCTV Feeds',
            onPressed: () {
              ref.invalidate(cctvCamerasProvider(_selectedFacilityId));
              ref.invalidate(allRegisteredProjectsProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
              vertical: 10,
            ),
            color: AppColors.surfaceLowest,
            child: Row(
              children: [
                const Icon(
                  Icons.videocam_outlined,
                  size: 20,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedFacilityId,
                      hint: Text(
                        'All Registered Facilities',
                        style: AppTypography.bodySm,
                      ),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All Facilities (Nationwide)'),
                        ),
                        ...?projectsAsync.value?.map(
                          (p) => DropdownMenuItem<String?>(
                            value: p.id,
                            child: Text(
                              '${p.name} (${p.code})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _selectedFacilityId = val),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Dynamic Camera Grid
          Expanded(
            child: camerasAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.screenMargin),
                child: LoadingSkeleton(count: 4, height: 160),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  child: Text(
                    'Error loading CCTV feeds: $e',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (cameras) {
                if (cameras.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.videocam_off_outlined,
                    title: 'No Active Cameras',
                    subtitle:
                        'No CCTV feeds are currently provisioned for this facility.',
                  );
                }

                final total = cameras.length;
                final active = cameras.where((c) => c.healthStatus == 'ACTIVE').length;
                final stale = cameras.where((c) => c.healthStatus == 'STALE').length;
                final offline = cameras.where((c) => c.healthStatus == 'OFFLINE').length;

                return Column(
                  children: [
                    // Authoritative Camera Health Summary Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenMargin,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.outlineVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildHealthMetricChip('Total', '$total', AppColors.primaryContainer),
                          _buildHealthMetricChip('Live', '$active', AppColors.success),
                          _buildHealthMetricChip('Stale', '$stale', AppColors.warning),
                          _buildHealthMetricChip('Offline', '$offline', AppColors.error),
                        ],
                      ),
                    ),
                    Expanded(
                      child: GridView.builder(
                        padding: const EdgeInsets.all(AppSpacing.screenMargin),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.84,
                        ),
                        itemCount: cameras.length,
                        itemBuilder: (context, index) {
                          final cam = cameras[index];
                          Color badgeColor;
                          String badgeLabel;
                          switch (cam.healthStatus) {
                            case 'ACTIVE':
                              badgeColor = AppColors.success;
                              badgeLabel = 'LIVE';
                              break;
                            case 'STALE':
                              badgeColor = AppColors.warning;
                              badgeLabel = 'STALE';
                              break;
                            default:
                              badgeColor = AppColors.error;
                              badgeLabel = 'OFFLINE';
                          }

                          return CivicCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Video Surface
                                Expanded(
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF111827),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(AppSpacing.cardRadius),
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Center(
                                          child: Icon(
                                            Icons.videocam_rounded,
                                            size: 36,
                                            color: Colors.white.withValues(
                                              alpha: 0.3,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 6,
                                          left: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    color: badgeColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  badgeLabel,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.6,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${cam.resolution} • ${cam.fps}fps',
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 8,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Camera Meta
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cam.name,
                                        style: AppTypography.labelSm.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        cam.facilityName,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.outline,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time_rounded,
                                            size: 11,
                                            color: AppColors.outline,
                                          ),
                                          const SizedBox(width: 3),
                                          Expanded(
                                            child: Text(
                                              cam.formattedLastActive,
                                              style: AppTypography.caption.copyWith(
                                                color: AppColors.outline,
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (cam.healthStatus != 'ACTIVE')
                                            InkWell(
                                              onTap: () async {
                                                await ref
                                                    .read(cctvRepositoryProvider)
                                                    .updateCameraStatus(cam.id, 'ACTIVE');
                                                ref.invalidate(cctvCamerasProvider(_selectedFacilityId));
                                              },
                                              borderRadius: BorderRadius.circular(4),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 1,
                                                ),
                                                child: Text(
                                                  'Ping',
                                                  style: AppTypography.caption.copyWith(
                                                    color: AppColors.primaryContainer,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetricChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: AppTypography.caption.copyWith(
            color: AppColors.outline,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: AppTypography.caption.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
