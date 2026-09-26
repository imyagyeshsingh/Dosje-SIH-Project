import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';
import '../../app/theme/spacing.dart';

enum ButtonType { primary, secondary, destructive, outline }

class CivicButton extends StatelessWidget {
  final String? label;
  final String? text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonType type;
  final bool isLoading;
  final double? width;
  final Color? backgroundColor;
  final Color? textColor;

  const CivicButton({
    super.key,
    this.label,
    this.text,
    this.onPressed,
    this.icon,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.width,
    this.backgroundColor,
    this.textColor,
  }) : assert(
         label != null || text != null,
         'Either label or text must be provided',
       );

  String get buttonText => label ?? text ?? '';

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    BorderSide? border;

    switch (type) {
      case ButtonType.primary:
        bg = backgroundColor ?? AppColors.primaryContainer;
        fg = textColor ?? AppColors.onPrimary;
        break;
      case ButtonType.secondary:
        bg = backgroundColor ?? AppColors.surfaceContainerHigh;
        fg = textColor ?? AppColors.primaryContainer;
        break;
      case ButtonType.destructive:
        bg = backgroundColor ?? AppColors.error;
        fg = textColor ?? AppColors.onError;
        break;
      case ButtonType.outline:
        bg = backgroundColor ?? Colors.transparent;
        fg = textColor ?? AppColors.primaryContainer;
        border = const BorderSide(
          color: AppColors.primaryContainer,
          width: 1.5,
        );
        break;
    }

    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(buttonText, style: AppTypography.labelLg.copyWith(color: fg)),
      ],
    );

    return SizedBox(
      width: width ?? double.infinity,
      height: AppSpacing.minTouchTarget,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          side: border,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: content,
      ),
    );
  }
}
