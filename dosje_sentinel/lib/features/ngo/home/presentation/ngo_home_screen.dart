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
                          'Namaste & Good Morning,',
                          style: AppTypography.bodySm,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rajesh Sharma',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Samarpan Welfare Society (NGO-UP-8821)',
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

            // 2. Urgent Video Inspection Action Card (High Priority Alert)
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
                    'District Rehabilitation & Support Centre',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Scheme ID: DSJ-AG-1042', style: AppTypography.bodySm),
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
                        onPressed: () => context.push('/ngo/inspections/ins_1'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed,
                    borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  ),
                  child: Text(
                    '2 Pending Requests',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSecondaryFixed,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Action Card 1
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.badge,
                          size: 20,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Staff Attendance Register Submission',
                              style: AppTypography.titleMd.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.alarm,
                                  size: 14,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Deadline: Today, 5:00 PM',
                                  style: AppTypography.bodySm.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Upload certified staff attendance register snapshot certified by center superintendent for cycle #2.',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CivicButton(
                      label: 'Respond',
                      icon: Icons.chevron_right,
                      width: 120,
                      onPressed: () =>
                          context.push('/ngo/inspections/ins_1/response'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Action Card 2
            CivicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          size: 20,
                          color: AppColors.saffron,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Facility Meal Quality Evidence',
                              style: AppTypography.titleMd.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Inspection: INS-2026-00482',
                              style: AppTypography.bodySm,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Provide timestamped photographs of mess storage and daily preparation register.',
                    style: AppTypography.bodySm,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: CivicButton(
                      label: 'Upload Evidence',
                      icon: Icons.photo_camera,
                      type: ButtonType.secondary,
                      width: 160,
                      onPressed: () => context.push('/ngo/evidence/capture'),
                    ),
                  ),
                ],
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
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      child: Icon(
                        Icons.description,
                        size: 18,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    title: const Text(
                      'Inspection Report INS-2026-00419 published',
                    ),
                    subtitle: const Text(
                      '2 hours ago • Central Monitoring Desk',
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push('/ngo/notifications'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      child: Icon(
                        Icons.workspace_premium,
                        size: 18,
                        color: AppColors.saffron,
                      ),
                    ),
                    title: const Text(
                      'Quarterly compliance certificate validated & stamped',
                    ),
                    subtitle: const Text('Yesterday • State Division'),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => context.push('/ngo/notifications'),
                  ),
                ],
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
    final facilityName = proj != null && proj.name.isNotEmpty
        ? proj.name
        : 'District Rehabilitation & Support Centre';
    final facilityCode = proj != null && proj.code.isNotEmpty
        ? proj.code
        : 'DSJ-AG-1042';
    final facilityStatus = proj != null && proj.status.isNotEmpty
        ? proj.status
        : 'Active';
    final facilityAddress = proj != null && proj.address.isNotEmpty
        ? proj.address
        : 'Agra, Uttar Pradesh';
    final activeCams = summary?.activeCameras ?? proj?.cctvActiveCameras ?? 4;
    final projectId = proj?.id ?? 'proj_1';

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
