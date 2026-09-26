import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/notification_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/status_chip.dart';

final notificationsListProvider = StateProvider<List<NotificationItem>>((ref) {
  return [
    NotificationItem(
      id: 'NOTIF_001',
      title: 'Action Required: Response Due for INSP-2026-089',
      description:
          'Inspector flagged deficiency in residential dining area. Submit geotagged photographic remediation within 48 hours.',
      category: NotificationCategory.actionRequests,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isCritical: true,
      projectCode: 'DOSJE-DL-2024-001',
      routePath: '/ngo/inspections/detail/INSP-2026-089',
    ),
    NotificationItem(
      id: 'NOTIF_002',
      title: 'Surprise Video Inspection Logged',
      description:
          'Scheduled remote spot audit was successfully completed by Shri R. K. Sharma (Joint Director).',
      category: NotificationCategory.videoCalls,
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: true,
      projectCode: 'DOSJE-DL-2024-001',
    ),
    NotificationItem(
      id: 'NOTIF_003',
      title: 'Compliance Audit Dossier Verified',
      description:
          'Departmental review of Project PRJ-002 quarterly outcomes has been approved.',
      category: NotificationCategory.compliance,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      projectCode: 'DOSJE-DL-2024-002',
    ),
    NotificationItem(
      id: 'NOTIF_004',
      title: 'Field Inspection Scheduled for INSP-2026-091',
      description:
          'PMU inspection team assigned for on-site physical verification on 26 Sep 2026.',
      category: NotificationCategory.inspections,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      projectCode: 'DOSJE-DL-2024-003',
    ),
  ];
});

class NgoNotificationsScreen extends ConsumerStatefulWidget {
  const NgoNotificationsScreen({super.key});

  @override
  ConsumerState<NgoNotificationsScreen> createState() =>
      _NgoNotificationsScreenState();
}

class _NgoNotificationsScreenState
    extends ConsumerState<NgoNotificationsScreen> {
  NotificationCategory _selectedCategory = NotificationCategory.all;

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(notificationsProvider);
    final backendNotifs = notifsAsync.value;
    final allNotifs = (backendNotifs != null && backendNotifs.isNotEmpty)
        ? backendNotifs
        : ref.watch(notificationsListProvider);

    final filtered = _selectedCategory == NotificationCategory.all
        ? allNotifs
        : allNotifs.where((n) => n.category == _selectedCategory).toList();

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: CivicAppBar(
        title: 'Action Center',
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await ref.read(notificationRepositoryProvider).markAllAsRead();
              } catch (_) {}
              ref.read(notificationsListProvider.notifier).update(
                    (items) =>
                        items.map((i) => i.copyWith(isRead: true)).toList(),
                  );
              ref.invalidate(notificationsProvider);
              ref.invalidate(notificationSummaryProvider);
            },
            child: Text(
              'Mark All Read',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primaryContainer,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
              vertical: 12,
            ),
            child: Row(
              children: NotificationCategory.values.map((cat) {
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.label),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() => _selectedCategory = cat);
                    },
                    selectedColor: AppColors.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    backgroundColor: AppColors.surfaceLowest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.pillRadius,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryContainer
                            : AppColors.outlineVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Notification List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(notificationsProvider);
                ref.invalidate(notificationSummaryProvider);
                await ref.read(notificationsProvider.future);
              },
              child: filtered.isEmpty
                  ? const EmptyStateView(
                      icon: Icons.notifications_none_outlined,
                      title: 'No Notifications',
                      subtitle:
                          'You are completely caught up with all inspection and compliance notices.',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenMargin,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return CivicCard(
                          backgroundColor: item.isRead
                              ? AppColors.surfaceLowest
                              : AppColors.surfaceContainerLow,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (!item.isRead) ...[
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.saffron,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(
                                        DateFormat('dd MMM, HH:mm')
                                            .format(item.timestamp),
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.isCritical)
                                    const StatusChip(
                                      label: 'URGENT',
                                      variant: ChipVariant.critical,
                                    )
                                  else
                                    StatusChip(
                                      label: item.category.label,
                                      variant: ChipVariant.neutral,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                style: AppTypography.titleSm.copyWith(
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.description,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              if (item.routePath != null) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(
                                      Icons.arrow_forward,
                                      size: 16,
                                      color: AppColors.primaryContainer,
                                    ),
                                    label: Text(
                                      'Take Action',
                                      style: AppTypography.labelMd.copyWith(
                                        color: AppColors.primaryContainer,
                                      ),
                                    ),
                                    onPressed: () async {
                                      try {
                                        if (!item.isRead) {
                                          await ref
                                              .read(
                                                  notificationRepositoryProvider)
                                              .markAsRead(item.id);
                                        }
                                      } catch (_) {}
                                      ref
                                          .read(
                                            notificationsListProvider.notifier,
                                          )
                                          .update((items) {
                                        return items.map((i) {
                                          return i.id == item.id
                                              ? i.copyWith(isRead: true)
                                              : i;
                                        }).toList();
                                      });
                                      ref.invalidate(notificationsProvider);
                                      ref.invalidate(
                                          notificationSummaryProvider);
                                      if (item.routePath != null &&
                                          context.mounted) {
                                        context.push(item.routePath!);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
