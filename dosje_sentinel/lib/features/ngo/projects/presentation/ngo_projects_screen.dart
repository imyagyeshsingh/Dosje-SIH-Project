import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/project_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';

final ngoProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final repo = ref.watch(projectRepositoryProvider);
  return await repo.getProjects(onlyAssigned: true);
});

class NgoProjectsScreen extends ConsumerStatefulWidget {
  const NgoProjectsScreen({super.key});

  @override
  ConsumerState<NgoProjectsScreen> createState() => _NgoProjectsScreenState();
}

class _NgoProjectsScreenState extends ConsumerState<NgoProjectsScreen> {
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(ngoProjectsProvider);

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'My Registered Projects',
        subtitle: 'Samarpan Welfare Society (NGO-8821)',
        showEmblem: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Search project name, ID, or district...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All Projects (3)', 'all'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Active (2)', 'active'),
                        const SizedBox(width: 8),
                        _buildFilterChip('Under Review (1)', 'review'),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Inspection Ongoing (1)',
                          'inspection',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Projects List
            Expanded(
              child: projectsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (projects) {
                  final filtered = projects.where((p) {
                    final matchesQuery =
                        _searchQuery.isEmpty ||
                        p.name.toLowerCase().contains(_searchQuery) ||
                        p.code.toLowerCase().contains(_searchQuery) ||
                        p.district.toLowerCase().contains(_searchQuery);

                    bool matchesFilter = true;
                    if (_selectedFilter == 'active') {
                      matchesFilter = p.status == 'ACTIVE';
                    } else if (_selectedFilter == 'review') {
                      matchesFilter = p.status == 'UNDER REVIEW';
                    } else if (_selectedFilter == 'inspection') {
                      matchesFilter = p.hasActiveInspection;
                    }
                    return matchesQuery && matchesFilter;
                  }).toList();

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMargin,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      return CivicCard(
                        leadingStripeColor: p.hasActiveInspection
                            ? AppColors.saffron
                            : (p.status == 'ACTIVE'
                                  ? AppColors.success
                                  : AppColors.outline),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainer,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        p.code,
                                        style: AppTypography.labelSm.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryContainer,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    StatusChip(
                                      label: p.status,
                                      variant: p.status == 'ACTIVE'
                                          ? ChipVariant.success
                                          : ChipVariant.warning,
                                    ),
                                  ],
                                ),
                                if (p.hasActiveInspection)
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.saffron,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Live Audit',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.saffron,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              p.name,
                              style: AppTypography.titleMd.copyWith(
                                color: AppColors.primaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${p.category} • ${p.district}, ${p.state}',
                              style: AppTypography.bodySm,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            if (p.hasActiveInspection) ...[
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryFixed.withOpacity(
                                    0.5,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.warning,
                                      size: 16,
                                      color: AppColors.secondary,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Surprise Inspection In Progress • Auditor on site',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            CivicButton(
                              label: 'View Project Details',
                              icon: Icons.arrow_forward,
                              type: ButtonType.secondary,
                              onPressed: () =>
                                  context.push('/ngo/projects/${p.id}'),
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: AppTypography.labelSm.copyWith(
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }
}
