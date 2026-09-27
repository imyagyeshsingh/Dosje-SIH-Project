import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_skeleton.dart';
import '../../../../shared/models/project_model.dart';
import '../../../../shared/providers/core_providers.dart';

class NgoHomeScreen extends ConsumerWidget {
  const NgoHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user = authState.user;
    final primarySummaryAsync = ref.watch(primaryProjectSummaryProvider);
    final notifSummaryAsync = ref.watch(notificationSummaryProvider);
    final unreadCount = notifSummaryAsync.value?.unread ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Image.asset(
              'assets/images/emblem.png',
              height: 32,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.account_balance,
                color: AppColors.primaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'DoSJE Sentinel',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'GOV',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'NGO Workspace • Dashboard Home',
                  style: AppTypography.bodySm.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () => context.push('/ngo/notifications'),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 16,
              backgroundImage: const AssetImage(
                'assets/images/representative_avatar.png',
              ),
              backgroundColor: AppColors.surfaceContainer,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenMargin),
          children: [
            // 1. Representative Greeting Header
            CivicCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Namaste & Welcome,',
                          style: AppTypography.bodySm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.name ?? 'NGO Representative',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.organizationName != null
                              ? '${user!.organizationName} (${user.organizationId ?? "NGO"})'
                              : 'DoSJE Monitoring Portal',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const StatusChip(
                    label: 'Authorized NGO',
                    variant: ChipVariant.success,
                    icon: Icons.verified,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 2. Urgent Video Inspection Action Card (Only if active surprise evaluation is ongoing)
            if (primarySummaryAsync.value?.project.hasActiveInspection == true) ...[
              CivicCard(
                leadingStripeColor: AppColors.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.errorBg,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.pillRadius,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'SURPRISE VIDEO INSPECTION REQUESTED',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'URGENT',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      primarySummaryAsync.value?.project.name ?? 'Assigned Facility',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Scheme ID: ${primarySummaryAsync.value?.project.code ?? "N/A"}',
                      style: AppTypography.bodySm,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.crisis_alert,
                            size: 20,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Department inspection officer is ready to initiate live video inspection. Video authorization required.',
                              style: AppTypography.bodyMd.copyWith(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: CivicButton(
                            label: 'Join Video Inspection',
                            icon: Icons.videocam,
                            onPressed: () => context.push('/ngo/video/incoming'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        CivicButton(
                          label: 'Details',
                          type: ButtonType.secondary,
                          width: 90,
                          onPressed: () => context.push('/ngo/inspections/${primarySummaryAsync.value?.project.activeInspectionId ?? "1"}'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // 3. Primary Assigned Project Summary Card
            primarySummaryAsync.when(
              loading: () => const LoadingSkeletonCard(height: 160),
              error: (err, stack) => _buildPrimaryProjectCard(context, null),
              data: (summary) => _buildPrimaryProjectCard(context, summary),
            ),
            const SizedBox(height: AppSpacing.md),

            // 4. Action Required Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Action Required',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            CivicCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No pending action requests. All submissions up to date.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 5. Recent Official Notifications
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Official Notifications',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/ngo/notifications'),
                  child: const Text('View All'),
                ),
              ],
            ),
            CivicCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notifications_none,
                      color: AppColors.outline,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No new official notifications from the department.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryProjectCard(BuildContext context, ProjectSummaryModel? summary) {
    final proj = summary?.project;
    if (proj == null) {
      return CivicCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ASSIGNED FACILITY',
                style: AppTypography.labelSm,
              ),
              const SizedBox(height: 6),
              Text(
                'No Facility Assigned Yet',
                style: AppTypography.titleMd.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Projects allocated to your organization by the Directorate will appear here automatically.',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final facilityName = proj.name;
    final facilityCode = proj.code;
    final facilityStatus = proj.status;
    final facilityAddress = proj.address;
    final activeCams = summary?.activeCameras ?? proj.cctvActiveCameras;
    final projectId = proj.id;

    return CivicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ASSIGNED FACILITY',
                    style: AppTypography.labelSm,
                  ),
                  Text(
                    facilityName,
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(facilityCode, style: AppTypography.bodySm),
                ],
              ),
              StatusChip(
                label: facilityStatus,
                variant: ChipVariant.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: AppColors.saffron,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          facilityAddress,
                          style: AppTypography.bodySm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.buttonRadius,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.videocam,
                        size: 18,
                        color: AppColors.primaryContainer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$activeCams Cameras Active',
                          style: AppTypography.bodySm,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CivicButton(
            label: 'View Project Details',
            icon: Icons.arrow_forward,
            type: ButtonType.secondary,
            onPressed: () => context.push('/ngo/projects/$projectId'),
          ),
        ],
      ),
    );
  }
}
