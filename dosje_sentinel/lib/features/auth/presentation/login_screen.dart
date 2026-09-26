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
        _otpController.text = code ?? '123456';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('6-digit verification code sent to $email'),
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

  // Debug sheet shortcut: directly sets credentials and logs in
  Future<void> _login([
    NgoRegistrationStatus? forcedStatus,
    UserRole? forcedRole,
  ]) async {
    if (_otpController.text.trim().isEmpty) {
      _otpController.text = '123456';
    }
    return _verifyOtp(forcedStatus, forcedRole);
  }

  void _showDebugAuthSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Debug Mock Authentication',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Chip(
                    label: Text(
                      'kDebugMode Only',
                      style: TextStyle(fontSize: 10),
                    ),
                    backgroundColor: AppColors.secondaryFixed,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Development testing tool. Tap a persona to populate credentials, or tap "Sign In" to immediately authenticate through Clerk and route to the authorized destination.',
                style: AppTypography.bodySm,
              ),
              const Divider(height: 20),

              // 1. NGO Approved
              ListTile(
                dense: true,
                leading: const Icon(Icons.verified, color: AppColors.success),
                title: const Text('NGO Representative (Approved)'),
                subtitle: const Text(
                  'rep.officer@samarpan-ngo.org → /ngo/home',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'rep.officer@samarpan-ngo.org';
                    await _login(
                      NgoRegistrationStatus.approved,
                      UserRole.ngoRepresentative,
                    );
                  },
                ),
                onTap: () {
                  _emailController.text = 'rep.officer@samarpan-ngo.org';
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.approved,
                      );
                  Navigator.pop(ctx);
                },
              ),

              // 2. NGO Incomplete / New
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.app_registration,
                  color: AppColors.saffron,
                ),
                title: const Text('NGO Representative (New / Incomplete)'),
                subtitle: const Text(
                  'new.rep@gramin-vikas.org → /ngo/onboarding/register',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'new.rep@gramin-vikas.org';
                    await _login(
                      NgoRegistrationStatus.incomplete,
                      UserRole.ngoRepresentative,
                    );
                  },
                ),
                onTap: () {
                  _emailController.text = 'new.rep@gramin-vikas.org';
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.incomplete,
                      );
                  Navigator.pop(ctx);
                },
              ),

              // 3. NGO Submitted
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.mark_email_read_outlined,
                  color: AppColors.primaryContainer,
                ),
                title: const Text('NGO Representative (Submitted)'),
                subtitle: const Text(
                  'submitted.rep@sewa-trust.org → /ngo/onboarding/submitted',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'submitted.rep@sewa-trust.org';
                    await _login(
                      NgoRegistrationStatus.submitted,
                      UserRole.ngoRepresentative,
                    );
                  },
                ),
                onTap: () {
                  _emailController.text = 'submitted.rep@sewa-trust.org';
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.submitted,
                      );
                  Navigator.pop(ctx);
                },
              ),

              // 4. NGO Under Review
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.hourglass_top_outlined,
                  color: AppColors.secondary,
                ),
                title: const Text('NGO Representative (Under Review)'),
                subtitle: const Text(
                  'review.rep@pratham-shiksha.org → /ngo/onboarding/under-review',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'review.rep@pratham-shiksha.org';
                    await _login(
                      NgoRegistrationStatus.underReview,
                      UserRole.ngoRepresentative,
                    );
                  },
                ),
                onTap: () {
                  _emailController.text = 'review.rep@pratham-shiksha.org';
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.underReview,
                      );
                  Navigator.pop(ctx);
                },
              ),

              // 5. NGO Correction Required
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                ),
                title: const Text('NGO Representative (Correction Required)'),
                subtitle: const Text(
                  'correction.rep@gramin-vikas.org → /ngo/onboarding/correction',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'correction.rep@gramin-vikas.org';
                    await _login(
                      NgoRegistrationStatus.correctionRequired,
                      UserRole.ngoRepresentative,
                    );
                  },
                ),
                onTap: () {
                  _emailController.text = 'correction.rep@gramin-vikas.org';
                  ref
                      .read(authStateProvider.notifier)
                      .updateNgoRegistrationStatus(
                        NgoRegistrationStatus.correctionRequired,
                      );
                  Navigator.pop(ctx);
                },
              ),

              const Divider(height: 16),

              // 6. PMU Inspector (Whitelisted)
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.policy,
                  color: AppColors.secondary,
                ),
                title: const Text('PMU / Field Inspector (Whitelisted)'),
                subtitle: const Text(
                  'itsmerudraksha1@gmail.com → /inspector/dashboard',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'itsmerudraksha1@gmail.com';
                    await _login(null, UserRole.inspector);
                  },
                ),
                onTap: () {
                  _emailController.text = 'itsmerudraksha1@gmail.com';
                  Navigator.pop(ctx);
                },
              ),

              // 7. Department Official (Whitelisted)
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primaryContainer,
                ),
                title: const Text('Department Official (Whitelisted)'),
                subtitle: const Text(
                  'itsmerudraksha@gmail.com → /official/dashboard',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'itsmerudraksha@gmail.com';
                    await _login(null, UserRole.official);
                  },
                ),
                onTap: () {
                  _emailController.text = 'itsmerudraksha@gmail.com';
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
                      'Project Monitoring & Compliance Portal',
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
                          : 'Unified single sign-on for all authorized stakeholders. Authenticate via Clerk to access your portal.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    if (!_otpSent) ...[
                      // Step 1: Email Input
                      // Quick Stakeholder Selector Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ChoiceChip(
                            avatar: const Icon(
                              Icons.admin_panel_settings,
                              size: 14,
                              color: AppColors.primaryContainer,
                            ),
                            label: const Text(
                              'Official (Rudraksha)',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected: _emailController.text ==
                                'itsmerudraksha@gmail.com',
                            selectedColor:
                                AppColors.primaryContainer.withValues(alpha: 0.15),
                            onSelected: _isLoading
                                ? null
                                : (sel) {
                                    setState(() {
                                      _emailController.text = sel
                                          ? 'itsmerudraksha@gmail.com'
                                          : '';
                                    });
                                  },
                          ),
                          ChoiceChip(
                            avatar: const Icon(
                              Icons.policy,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            label: const Text(
                              'PMU (Rudraksha 1)',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected: _emailController.text ==
                                'itsmerudraksha1@gmail.com',
                            selectedColor:
                                AppColors.secondary.withValues(alpha: 0.15),
                            onSelected: _isLoading
                                ? null
                                : (sel) {
                                    setState(() {
                                      _emailController.text = sel
                                          ? 'itsmerudraksha1@gmail.com'
                                          : '';
                                    });
                                  },
                          ),
                          ChoiceChip(
                            avatar: const Icon(
                              Icons.business,
                              size: 14,
                              color: AppColors.saffron,
                            ),
                            label: const Text(
                              'NGO Rep',
                              style: TextStyle(fontSize: 11),
                            ),
                            selected: _emailController.text ==
                                'rep.officer@samarpan-ngo.org',
                            selectedColor:
                                AppColors.saffron.withValues(alpha: 0.15),
                            onSelected: _isLoading
                                ? null
                                : (sel) {
                                    setState(() {
                                      _emailController.text = sel
                                          ? 'rep.officer@samarpan-ngo.org'
                                          : '';
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Single Email Field
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
                        label: 'Continue with Clerk',
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

                      if (_devOtp != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.vpn_key_outlined,
                                size: 14,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Verification Code: $_devOtp (or 123456)',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _otpController.text = _devOtp!;
                                  });
                                },
                                child: const Text(
                                  'Auto-Fill',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryContainer,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

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

              // Debug Mock Auth Launcher (Strictly kDebugMode)
              if (kDebugMode) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.bug_report_outlined, size: 16),
                  label: const Text('Debug Mock Auth Switcher'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.saffron,
                    side: const BorderSide(color: AppColors.saffron),
                    minimumSize: const Size.fromHeight(40),
                  ),
                  onPressed: _isLoading ? null : _showDebugAuthSheet,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Footer Assurance
              Center(
                child: Text(
                  'Unified Identity Handshake • Powered by Clerk & NIC Standards\nAuthorized representatives, inspectors, and directorate officers.',
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
