import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import '../../app/theme/spacing.dart';

enum ChipVariant { success, warning, critical, neutral, info }

class StatusChip extends StatelessWidget {
  final String label;
  final ChipVariant variant;
  final IconData? icon;
  final bool isPill;

  const StatusChip({
    super.key,
    required this.label,
    this.variant = ChipVariant.neutral,
    this.icon,
    this.isPill = true,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color text;
    Color border;

    switch (variant) {
      case ChipVariant.success:
        bg = AppColors.successBg;
        text = AppColors.successText;
        border = AppColors.successBorder;
        break;
      case ChipVariant.warning:
        bg = AppColors.warningBg;
        text = AppColors.warningText;
        border = AppColors.warningBorder;
        break;
      case ChipVariant.critical:
        bg = AppColors.errorBg;
        text = AppColors.error;
        border = AppColors.errorBorder;
        break;
      case ChipVariant.info:
        bg = AppColors.surfaceContainer;
        text = AppColors.primaryContainer;
        border = AppColors.surfaceContainerHigh;
        break;
      case ChipVariant.neutral:
        bg = AppColors.surfaceContainerLow;
        text = AppColors.onSurfaceVariant;
        border = AppColors.outlineVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(isPill ? AppSpacing.pillRadius : 6),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: text),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: AppTypography.labelSm.copyWith(
              color: text,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
