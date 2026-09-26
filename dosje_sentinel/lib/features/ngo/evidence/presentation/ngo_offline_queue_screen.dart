import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/storage/offline_queue_service.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/status_chip.dart';

final offlineQueueProvider = StreamProvider<List<OfflineEvidenceItem>>((ref) {
  final queueService = ref.watch(offlineQueueServiceProvider);
  return queueService.queueStream;
});

class NgoOfflineQueueScreen extends ConsumerStatefulWidget {
  const NgoOfflineQueueScreen({super.key});

  @override
  ConsumerState<NgoOfflineQueueScreen> createState() =>
      _NgoOfflineQueueScreenState();
}

class _NgoOfflineQueueScreenState extends ConsumerState<NgoOfflineQueueScreen> {
  bool _isSyncing = false;

  Future<void> _handleSyncAll() async {
    setState(() => _isSyncing = true);
    try {
      final queueService = ref.read(offlineQueueServiceProvider);
      await queueService.syncQueue();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Field sync initiated for queued evidence'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(offlineQueueProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Offline Sync Queue',
        showProfileAvatar: false,
      ),
      body: queueAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyStateView(
              icon: Icons.cloud_done_outlined,
              title: 'Queue is Clear',
              subtitle: 'All field evidence records, geotags, and telemetry have been synchronized with the DoSJE backend.',
            );
          }

          return Column(
            children: [
              // Sync Notice Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: AppColors.warningBg,
                child: Row(
                  children: [
                    const Icon(
                      Icons.sync_problem,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${items.length} item(s) pending field upload. Auto-sync triggers when network is restored.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.warningText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CivicCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.buttonRadius,
                              ),
                            ),
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              color: AppColors.primaryContainer,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Inspection #${item.inspectionId}',
                                        style: AppTypography.titleSm,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    StatusChip(
                                      label:
                                          item.syncStatus ==
                                              EvidenceSyncStatus.failed
                                          ? 'Failed'
                                          : 'Pending',
                                      variant:
                                          item.syncStatus ==
                                              EvidenceSyncStatus.failed
                                          ? ChipVariant.critical
                                          : ChipVariant.warning,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'GPS: ${item.latitude.toStringAsFixed(4)}, ${item.longitude.toStringAsFixed(4)}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Queued: ${item.timestamp.toLocal().toString().substring(0, 16)}',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.outline,
                                  ),
                                ),
                                if (item.errorMessage != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    item.errorMessage!,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.sync,
                              color: AppColors.primaryContainer,
                            ),
                            tooltip: 'Retry Upload',
                            onPressed: () => ref
                                .read(offlineQueueServiceProvider)
                                .retryItem(item.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.screenMargin),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLowest,
                  border: Border(
                    top: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                child: CivicButton(
                  text: 'Force Sync All Evidence',
                  icon: Icons.sync,
                  isLoading: _isSyncing,
                  onPressed: _handleSyncAll,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
