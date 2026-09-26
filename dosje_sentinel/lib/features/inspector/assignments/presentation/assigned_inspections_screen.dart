import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/inspection_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/empty_state_view.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/status_chip.dart';

class AssignedInspectionsScreen extends ConsumerStatefulWidget {
  const AssignedInspectionsScreen({super.key});

  @override
  ConsumerState<AssignedInspectionsScreen> createState() =>
      _AssignedInspectionsScreenState();
}

class _AssignedInspectionsScreenState
    extends ConsumerState<AssignedInspectionsScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final inspectionRepo = ref.watch(inspectionRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Assigned Inspections',
        showProfileAvatar: false,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenMargin,
              vertical: 12,
            ),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Audits'),
                const SizedBox(width: 8),
                _buildFilterChip('IN_PROGRESS', 'Active'),
                const SizedBox(width: 8),
                _buildFilterChip('SCHEDULED', 'Scheduled'),
                const SizedBox(width: 8),
                _buildFilterChip('COMPLETED', 'Done'),
              ],
            ),
          ),

          // Inspection List
          Expanded(
            child: FutureBuilder<List<InspectionModel>>(
              future: inspectionRepo.getInspections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.screenMargin),
                    child: LoadingSkeleton(count: 3, height: 110),
                  );
                }

                final allList = snapshot.data ?? [];
                final filtered = _selectedFilter == 'ALL'
                    ? allList
                    : allList
                          .where((i) => i.status == _selectedFilter)
                          .toList();

                if (filtered.isEmpty) {
                  return const EmptyStateView(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'No Audits Found',
                    subtitle:
                        'There are no inspections matching this status filter.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.screenMargin),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final insp = filtered[index];
                    return CivicCard(
                      onTap: () => context.push(
                        '/inspector/assignments/execute/${insp.id}',
                      ),
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
                                label: insp.status,
                                variant: insp.status == 'COMPLETED'
                                    ? ChipVariant.success
                                    : (insp.status == 'IN_PROGRESS'
                                          ? ChipVariant.warning
                                          : ChipVariant.neutral),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(insp.projectName, style: AppTypography.titleSm),
                          const SizedBox(height: 4),
                          Text(
                            'Scheme: ${insp.schemeCode} • Nodal: ${insp.nodalOfficerName}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event_note,
                                    size: 14,
                                    color: AppColors.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy, HH:mm')
                                        .format(insp.scheduledDate),
                                    style: AppTypography.caption,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '${insp.checklistItems.length} Checklist Items',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 16,
                                    color: AppColors.outline,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _selectedFilter = key),
      selectedColor: AppColors.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: AppColors.surfaceLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
        side: BorderSide(
          color: isSelected
              ? AppColors.primaryContainer
              : AppColors.outlineVariant,
        ),
      ),
    );
  }
}
