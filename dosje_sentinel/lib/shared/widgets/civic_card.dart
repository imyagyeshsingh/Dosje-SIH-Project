import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/spacing.dart';

class CivicCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? leadingStripeColor;
  final Color? backgroundColor;
  final BoxBorder? border;
  final VoidCallback? onTap;

  const CivicCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.leadingStripeColor,
    this.onTap,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.surfaceLowest,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: border ?? Border.all(color: AppColors.outlineVariant, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(10, 37, 64, 0.05),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (leadingStripeColor != null) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Stack(
          children: [
            cardContent,
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: Container(color: leadingStripeColor),
            ),
          ],
        ),
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}
