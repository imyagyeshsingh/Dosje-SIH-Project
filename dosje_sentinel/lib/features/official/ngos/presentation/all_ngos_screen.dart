import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/ngo_profile_model.dart';
import '../../../../shared/models/ngo_registration_status.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/widgets/error_state_view.dart';
import '../providers/official_ngos_provider.dart';

class AllNgosScreen extends ConsumerStatefulWidget {
  const AllNgosScreen({super.key});

  @override
  ConsumerState<AllNgosScreen> createState() => _AllNgosScreenState();
}

class _AllNgosScreenState extends ConsumerState<AllNgosScreen> {
  String _searchQuery = '';
  NgoRegistrationStatus? _filterStatus;
  String? _processingNgoId;

  Future<void> _handleApprove(NgoProfileModel ngo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppColors.success, size: 24),
            SizedBox(width: 8),
            Text('Approve Registration'),
          ],
        ),
        content: Text(
          'Are you sure you want to approve and sanction "${ngo.ngoName}" (Reg: ${ngo.registrationNumber})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve NGO'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _processingNgoId = ngo.id);
      try {
        await ref
            .read(allNgosProvider.notifier)
            .updateNgoStatus(ngo.id, NgoRegistrationStatus.approved);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ngo.ngoName} marked as APPROVED.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve NGO: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _processingNgoId = null);
      }
    }
  }

  Future<void> _handleMarkUnderReview(NgoProfileModel ngo) async {
    setState(() => _processingNgoId = ngo.id);
    try {
      await ref
          .read(allNgosProvider.notifier)
          .updateNgoStatus(ngo.id, NgoRegistrationStatus.underReview);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ngo.ngoName} marked as UNDER REVIEW.'),
            backgroundColor: AppColors.saffron,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingNgoId = null);
    }
  }

  Future<void> _handleRequestCorrection(NgoProfileModel ngo) async {
    final controller = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.edit_note, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Flag Correction Needed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Specify required amendments or missing documents for "${ngo.ngoName}":',
              style: AppTypography.bodySm,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Upload clear copy of PAN Card, renewed Darpan registration...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Submit Correction Request'),
          ),
        ],
      ),
    );

    if (submitted == true) {
      setState(() => _processingNgoId = ngo.id);
      try {
        await ref
            .read(allNgosProvider.notifier)
            .updateNgoStatus(
              ngo.id,
              NgoRegistrationStatus.correctionRequired,
              notes: controller.text.trim(),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${ngo.ngoName} flagged for CORRECTION.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _processingNgoId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final canView = authState.hasPermission(Permission.viewAllNgos);

    if (!canView) {
      return Scaffold(
        appBar: const CivicAppBar(title: 'All Registered NGOs'),
        body: const ErrorStateView(
          title: 'Permission Denied',
          message: 'Your official credentials lack the viewAllNgos permission.',
        ),
      );
    }

    final ngosAsync = ref.watch(allNgosProvider);
    final notifier = ref.read(allNgosProvider.notifier);
    final bannerMessage = notifier.latestEventBanner;

    return Scaffold(
      appBar: CivicAppBar(
        title: 'All Registered NGOs',
        subtitle: 'State Directory & Verification',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(allNgosProvider.notifier).loadNgos(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Realtime notification banner if a new NGO registered
            if (bannerMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: AppColors.successBg,
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_active,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bannerMessage,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.successText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => notifier.clearBanner()),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.successText,
                      ),
                    ),
                  ],
                ),
              ),

            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              child: Column(
                children: [
                  TextField(
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.toLowerCase()),
                    decoration: InputDecoration(
                      hintText:
                          'Search by NGO name, registration # or district...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      fillColor: AppColors.surfaceLowest,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All', null),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Approved',
                          NgoRegistrationStatus.approved,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Under Review',
                          NgoRegistrationStatus.underReview,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Submitted',
                          NgoRegistrationStatus.submitted,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          'Correction Needed',
                          NgoRegistrationStatus.correctionRequired,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // List of NGOs
            Expanded(
              child: ngosAsync.when(
                loading: () => ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenMargin,
                  ),
                  itemCount: 4,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, __) =>
                      const LoadingSkeletonCard(height: 110),
                ),
                error: (e, _) => ErrorStateView(
                  message: e.toString(),
                  onRetry: () => ref.read(allNgosProvider.notifier).loadNgos(),
                ),
                data: (ngos) {
                  final filtered = ngos.where((n) {
                    final matchesQuery =
                        _searchQuery.isEmpty ||
                        n.ngoName.toLowerCase().contains(_searchQuery) ||
                        n.registrationNumber.toLowerCase().contains(
                          _searchQuery,
                        ) ||
                        n.district.toLowerCase().contains(_searchQuery);
                    final matchesStatus =
                        _filterStatus == null || n.status == _filterStatus;
                    return matchesQuery && matchesStatus;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No organizations match the filter.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenMargin,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final ngo = filtered[index];
                      return CivicCard(
                        leadingStripeColor: _getStatusStripeColor(ngo.status),
                        onTap: () {
                          context.push('/official/ngos/${ngo.id}');
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ngo.ngoName,
                                    style: AppTypography.titleMd.copyWith(
                                      color: AppColors.primaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                _buildStatusChip(ngo.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reg: ${ngo.registrationNumber} • Est. ${ngo.establishmentYear}',
                              style: AppTypography.bodySm,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 14,
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${ngo.fullName} (${ngo.designation})',
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: AppColors.outline,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ngo.district}, ${ngo.state}',
                                  style: AppTypography.bodySm,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(height: 1, thickness: 0.5),
                            const SizedBox(height: 8),

                            // Official Status Action Buttons (Approve / Under Review / Correction Needed)
                            if (_processingNgoId == ngo.id)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Center(
                                  child: SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                        minimumSize: const Size(0, 32),
                                        side: BorderSide(
                                          color: ngo.status == NgoRegistrationStatus.approved
                                              ? AppColors.success
                                              : AppColors.outlineVariant,
                                          width: ngo.status == NgoRegistrationStatus.approved ? 1.5 : 1,
                                        ),
                                        backgroundColor: ngo.status == NgoRegistrationStatus.approved
                                            ? AppColors.successBg
                                            : Colors.transparent,
                                        foregroundColor: AppColors.success,
                                      ),
                                      icon: const Icon(Icons.check_circle_outline, size: 14),
                                      label: const Text('Approve', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _handleApprove(ngo),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                        minimumSize: const Size(0, 32),
                                        side: BorderSide(
                                          color: ngo.status == NgoRegistrationStatus.underReview
                                              ? AppColors.saffron
                                              : AppColors.outlineVariant,
                                          width: ngo.status == NgoRegistrationStatus.underReview ? 1.5 : 1,
                                        ),
                                        backgroundColor: ngo.status == NgoRegistrationStatus.underReview
                                            ? AppColors.warningBg
                                            : Colors.transparent,
                                        foregroundColor: AppColors.saffron,
                                      ),
                                      icon: const Icon(Icons.pending_actions_outlined, size: 14),
                                      label: const Text('Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _handleMarkUnderReview(ngo),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                        minimumSize: const Size(0, 32),
                                        side: BorderSide(
                                          color: ngo.status == NgoRegistrationStatus.correctionRequired
                                              ? AppColors.error
                                              : AppColors.outlineVariant,
                                          width: ngo.status == NgoRegistrationStatus.correctionRequired ? 1.5 : 1,
                                        ),
                                        backgroundColor: ngo.status == NgoRegistrationStatus.correctionRequired
                                            ? AppColors.errorBg
                                            : Colors.transparent,
                                        foregroundColor: AppColors.error,
                                      ),
                                      icon: const Icon(Icons.edit_note_outlined, size: 14),
                                      label: const Text('Correction', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      onPressed: () => _handleRequestCorrection(ngo),
                                    ),
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
      ),
    );
  }

  Widget _buildFilterChip(String label, NgoRegistrationStatus? status) {
    final isSelected = _filterStatus == status;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primaryContainer,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: AppTypography.labelSm.copyWith(
        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => setState(() => _filterStatus = status),
    );
  }

  Color _getStatusStripeColor(NgoRegistrationStatus status) {
    switch (status) {
      case NgoRegistrationStatus.approved:
        return AppColors.success;
      case NgoRegistrationStatus.underReview:
      case NgoRegistrationStatus.submitted:
        return AppColors.saffron;
      case NgoRegistrationStatus.correctionRequired:
        return AppColors.error;
      case NgoRegistrationStatus.incomplete:
        return AppColors.outline;
    }
  }

  Widget _buildStatusChip(NgoRegistrationStatus status) {
    switch (status) {
      case NgoRegistrationStatus.approved:
        return const StatusChip(
          label: 'Approved',
          variant: ChipVariant.success,
        );
      case NgoRegistrationStatus.underReview:
        return const StatusChip(
          label: 'Under Review',
          variant: ChipVariant.warning,
        );
      case NgoRegistrationStatus.submitted:
        return const StatusChip(label: 'Submitted', variant: ChipVariant.info);
      case NgoRegistrationStatus.correctionRequired:
        return const StatusChip(
          label: 'Correction Needed',
          variant: ChipVariant.critical,
        );
      case NgoRegistrationStatus.incomplete:
        return const StatusChip(
          label: 'Incomplete',
          variant: ChipVariant.neutral,
        );
    }
  }
}
