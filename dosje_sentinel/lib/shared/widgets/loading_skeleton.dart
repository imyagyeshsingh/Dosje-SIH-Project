import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/spacing.dart';

class LoadingSkeletonCard extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const LoadingSkeletonCard({
    super.key,
    this.height = 100,
    this.width,
    this.borderRadius = AppSpacing.cardRadius,
  });

  @override
  State<LoadingSkeletonCard> createState() => _LoadingSkeletonCardState();
}

class _LoadingSkeletonCardState extends State<LoadingSkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width ?? double.infinity,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh.withValues(
              alpha: _animation.value,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class LoadingSkeleton extends StatelessWidget {
  final int count;
  final double height;
  final double spacing;

  const LoadingSkeleton({
    super.key,
    this.count = 3,
    this.height = 100,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? spacing : 0),
          child: LoadingSkeletonCard(height: height),
        ),
      ),
    );
  }
}
