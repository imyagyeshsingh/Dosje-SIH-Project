import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/colors.dart';
import '../../../app/theme/typography.dart';
import '../../../app/theme/spacing.dart';
import '../../../core/auth/auth_guard.dart';
import '../../../shared/models/ngo_registration_status.dart';
import '../../../shared/models/user_role.dart';
import '../../../shared/providers/core_providers.dart';
import '../../../shared/widgets/civic_card.dart';
import '../../../shared/widgets/civic_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Empty credentials controllers - user enters their own email
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isLoading = false;
  bool _otpSent = false;
  String? _devOtp;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Dispatching verification code to $email...';
    });

    try {
      final code = await ref.read(authStateProvider.notifier).sendOtp(email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _devOtp = code;
        _otpController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Official verification code sent to $email. Please check your inbox.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to dispatch verification code: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }

  Future<void> _verifyOtp([
    NgoRegistrationStatus? forcedStatus,
    UserRole? forcedRole,
  ]) async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 6-digit verification code'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying code & resolving role authorization...';
    });

    try {
      await ref.read(authStateProvider.notifier).verifyOtp(
            email: email,
            otp: otp,
            status: forcedStatus,
            roleHint: forcedRole,
          );

      if (!mounted) return;

      final authState = ref.read(authStateProvider);
      final roleLabel = authState.user?.role.displayName ?? 'Authorized User';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access Granted: $roleLabel (${authState.user?.email})'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
        ),
      );

      // Role-based routing based on backend authorization context
      if (authState.isNgo) {
        final target = AuthGuard.resolveNgoInitialRoute(
          authState.ngoRegistrationStatus,
        );
        context.go(target);
      } else if (authState.isInspector) {
        context.go('/inspector/dashboard');
      } else if (authState.isOfficial) {
        context.go('/official/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = null;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenMargin,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.md),
              // Header Emblem & Civic Brand
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLowest,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Image.asset(
                        'assets/images/emblem.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shield_outlined,
                          size: 36,
                          color: AppColors.primaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.pillRadius,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_user,
                            size: 12,
                            color: AppColors.saffron,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'OFFICIAL PUBLIC SERVICE PORTAL',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'DoSJE Sentinel',
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Government Inspection & Monitoring System',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Department of Social Justice and Empowerment • Govt. of India',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 10,
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Single Unified Login Form Card
              CivicCard(
                leadingStripeColor: AppColors.saffron,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sign In',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.primaryContainer,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.shield,
                                size: 12,
                                color: AppColors.saffron,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'NIC Secured',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _otpSent
                          ? 'Enter the 6-digit verification code sent to your registered email.'
                          : 'National single sign-on portal. Enter your authorized official email address to access your dashboard.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (!_otpSent) ...[
                      // Step 1: Email Input
                      TextField(
                        controller: _emailController,
                        style: AppTypography.bodyMd,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          labelText: 'Authorized Email Address *',
                          hintText: 'e.g. itsmerudraksha@gmail.com',
                          prefixIcon: Icon(Icons.mail_outline, size: 18),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      CivicButton(
                        label: 'Get Verification Code',
                        icon: Icons.send_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _sendOtp,
                      ),
                    ] else ...[
                      // Step 2: OTP Verification
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              color: AppColors.success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Code dispatched to:',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    _emailController.text,
                                    style: AppTypography.bodySm.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() => _otpSent = false),
                              child: const Text('Change', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 6-Digit OTP Field
                      TextField(
                        controller: _otpController,
                        style: AppTypography.headlineSm.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        enabled: !_isLoading,
                        decoration: const InputDecoration(
                          labelText: '6-Digit Verification Code *',
                          hintText: '• • • • • •',
                          counterText: '',
                          prefixIcon: Icon(Icons.pin_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primaryContainer.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.mark_email_unread_outlined,
                              size: 18,
                              color: AppColors.primaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Verification Code Sent',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.primaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Please check your email inbox (and spam folder) for the 6-digit verification code.',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      CivicButton(
                        label: 'Verify & Sign In',
                        icon: Icons.verified_user_rounded,
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : () => _verifyOtp(),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.arrow_back, size: 14),
                            label: const Text('Change Email', style: TextStyle(fontSize: 12)),
                            onPressed: _isLoading
                                ? null
                                : () => setState(() => _otpSent = false),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Resend Code', style: TextStyle(fontSize: 12)),
                            onPressed: _isLoading ? null : _sendOtp,
                          ),
                        ],
                      ),
                    ],

                    if (_statusMessage != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _statusMessage!,
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Footer Assurance
              Center(
                child: Text(
                  'DoSJE National Inspection & Monitoring System • NIC Security Standards\nDepartment of Social Justice and Empowerment, Government of India',
                  style: AppTypography.bodySm.copyWith(fontSize: 11),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
