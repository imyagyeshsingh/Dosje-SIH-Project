import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/models/video_session_model.dart';

import '../../../../shared/providers/core_providers.dart';

class NgoVideoSessionScreen extends ConsumerStatefulWidget {
  final VideoSessionModel session;

  const NgoVideoSessionScreen({super.key, required this.session});

  @override
  ConsumerState<NgoVideoSessionScreen> createState() =>
      _NgoVideoSessionScreenState();
}

class _NgoVideoSessionScreenState extends ConsumerState<NgoVideoSessionScreen> {
  int _secondsElapsed = 0;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isFrontCamera = false;

  @override
  void initState() {
    super.initState();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _endSession() async {
    if (widget.session.numericId > 0) {
      try {
        final sessionRepo = ref.read(videoSessionRepositoryProvider);
        await sessionRepo.endVideoSession(widget.session.numericId);
      } catch (_) {}
    }

    final completedSession = VideoSessionModel(
      id: widget.session.id,
      inspectionId: widget.session.inspectionId,
      projectName: widget.session.projectName,
      callerName: widget.session.callerName,
      callerDesignation: widget.session.callerDesignation,
      startedAt: widget.session.startedAt,
      durationSeconds: _secondsElapsed,
      status: VideoSessionStatus.completed,
    );
    if (mounted) {
      context.pushReplacement('/ngo/video/completed', extra: completedSession);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nowFormatted = DateFormat('yyyy-MM-dd HH:mm:ss')
        .format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main Video Surface (Simulated Camera Feed)
          Positioned.fill(
            child: Container(
              color: const Color(0xFF151C28),
              child: Center(
                child: _isCameraOff
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.videocam_off,
                            color: Colors.white54,
                            size: 64,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Camera Feed Paused',
                            style: AppTypography.titleSm.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 100,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                          Text(
                            'ENCRYPTED FIELD STREAM (WEBRTC)',
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white24,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // Inspector PiP (Remote Inspector Stream)
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              width: 110,
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.saffron, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.white70,
                          size: 36,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.session.callerName.split(' ').first,
                          style: AppTypography.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'OFFICIAL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top Telemetry & Watermark Overlay
          Positioned(
            top: 48,
            left: 16,
            right: 140,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'REC ${_formatDuration(_secondsElapsed)}',
                        style: AppTypography.labelSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SESSION: ${widget.session.id}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    'GPS: 28.6139° N, 77.2090° E',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    nowFormatted,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Control Bar
          Positioned(
            bottom: 36,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryNavy.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: AppColors.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _isMuted
                          ? AppColors.error
                          : AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                    onPressed: () => setState(() => _isMuted = !_isMuted),
                  ),

                  // Camera Toggle Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: _isCameraOff
                          ? AppColors.error
                          : AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: Icon(
                      _isCameraOff ? Icons.videocam_off : Icons.videocam,
                    ),
                    onPressed: () =>
                        setState(() => _isCameraOff = !_isCameraOff),
                  ),

                  // Flip Camera Button
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryContainer,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.flip_camera_ios),
                    onPressed: () =>
                        setState(() => _isFrontCamera = !_isFrontCamera),
                  ),

                  // End Call Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.buttonRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.call_end, size: 20),
                    label: const Text('End Audit'),
                    onPressed: _endSession,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
