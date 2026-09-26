import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/video_session_model.dart';
import '../../../../shared/widgets/civic_button.dart';

class NgoIncomingVideoScreen extends ConsumerStatefulWidget {
  final VideoSessionModel session;

  const NgoIncomingVideoScreen({super.key, required this.session});

  @override
  ConsumerState<NgoIncomingVideoScreen> createState() =>
      _NgoIncomingVideoScreenState();
}

class _NgoIncomingVideoScreenState extends ConsumerState<NgoIncomingVideoScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _countdownSeconds = 45;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        if (mounted) {
          context.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              // Top Alert Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.saffron.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.pillRadius),
                  border: Border.all(
                    color: AppColors.saffron.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.flash_on,
                      color: AppColors.saffron,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SURPRISE REMOTE AUDIT',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.saffron,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Animated Pulse Call Indicator
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 140 + (_pulseController.value * 20),
                    height: 140 + (_pulseController.value * 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer.withValues(
                        alpha: 0.3 * (1 - _pulseController.value),
                      ),
                      border: Border.all(
                        color: AppColors.saffron.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryContainer,
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          size: 52,
                          color: AppColors.saffron,
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Text(
                'Incoming Video Inspection',
                style: AppTypography.titleLg.copyWith(
                  color: AppColors.onPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.session.callerName,
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.session.callerDesignation,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Session Context Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.session.projectName,
                      style: AppTypography.titleSm.copyWith(
                        color: AppColors.onPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Session ID: ${widget.session.id}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: AppColors.saffron,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Response timeout: $_countdownSeconds s',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.saffron,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Response Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.errorContainer,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.buttonRadius,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.call_end, color: AppColors.error),
                      label: const Text('Decline'),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: CivicButton(
                      text: 'Accept Call',
                      icon: Icons.videocam,
                      backgroundColor: AppColors.success,
                      onPressed: () {
                        context.pushReplacement(
                          '/ngo/video/session',
                          extra: widget.session,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
