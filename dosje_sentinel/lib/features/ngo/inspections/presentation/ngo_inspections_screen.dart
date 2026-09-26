import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/inspection_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';

final inspectionsProvider = FutureProvider<List<InspectionModel>>((ref) async {
  final repo = ref.watch(inspectionRepositoryProvider);
  return await repo.getInspections();
});

class NgoInspectionsScreen extends ConsumerStatefulWidget {
  const NgoInspectionsScreen({super.key});

  @override
  ConsumerState<NgoInspectionsScreen> createState() =>
      _NgoInspectionsScreenState();
}

class _NgoInspectionsScreenState extends ConsumerState<NgoInspectionsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inspectionsAsync = ref.watch(inspectionsProvider);

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Field Inspections',
        subtitle: 'Central Oversight & Audit Directorate',
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.surfaceLowest,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(10, 37, 64, 0.08),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  labelColor: AppColors.primaryContainer,
                  unselectedLabelColor: AppColors.onSurfaceVariant,
                  labelStyle: AppTypography.labelMd.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'CURRENT (1)'),
                    Tab(text: 'UPCOMING (1)'),
                    Tab(text: 'COMPLETED (1)'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: inspectionsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (inspections) {
                  return TabBarView(
                    controller: _tabController,
                    children: [
                      // Current Tab
                      _buildInspectionList(
                        inspections
                            .where((i) => i.status == 'IN_PROGRESS')
                            .toList(),
                      ),
                      // Upcoming Tab
                      _buildInspectionList(
                        inspections
                            .where((i) => i.status == 'SCHEDULED')
                            .toList(),
                      ),
                      // Completed Tab
                      _buildInspectionList(
                        inspections
                            .where((i) => i.status == 'COMPLETED')
                            .toList(),
                        isCompleted: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectionList(
    List<InspectionModel> list, {
    bool isCompleted = false,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No inspections in this category.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenMargin),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final insp = list[index];
        return CivicCard(
          leadingStripeColor: insp.status == 'IN_PROGRESS'
              ? AppColors.saffron
              : (insp.status == 'COMPLETED'
                    ? AppColors.success
                    : AppColors.outline),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusChip(
                    label: insp.type,
                    variant: insp.status == 'IN_PROGRESS'
                        ? ChipVariant.warning
                        : ChipVariant.info,
                  ),
                  Text(
                    insp.code,
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                insp.projectName,
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Scheme Code: ${insp.schemeCode}',
                style: AppTypography.bodySm,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_pin,
                    size: 16,
                    color: AppColors.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Officer: ${insp.nodalOfficerName}',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (isCompleted) ...[
                CivicButton(
                  label: 'View Outcome & Follow-Up',
                  icon: Icons.rate_review_outlined,
                  type: ButtonType.secondary,
                  onPressed: () =>
                      context.push('/ngo/inspections/${insp.id}/outcome'),
                ),
              ] else ...[
                CivicButton(
                  label: 'View Audit Details',
                  icon: Icons.arrow_forward,
                  type: ButtonType.secondary,
                  onPressed: () => context.push('/ngo/inspections/${insp.id}'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
