import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import '../../app/theme/spacing.dart';

class OfflineStatusBanner extends StatelessWidget {
  final int pendingUploadsCount;
  final VoidCallback? onTapQueue;

  const OfflineStatusBanner({
    super.key,
    this.pendingUploadsCount = 0,
    this.onTapQueue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: AppColors.saffron.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.wifi_off, size: 14, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              pendingUploadsCount > 0
                  ? 'Offline: $pendingUploadsCount evidence file(s) waiting to sync'
                  : 'Operating in Field Offline Mode',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSecondaryFixed,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onTapQueue != null)
            InkWell(
              onTap: onTapQueue,
              child: Text(
                'View Queue',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
