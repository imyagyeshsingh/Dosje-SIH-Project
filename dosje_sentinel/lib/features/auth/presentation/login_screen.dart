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
  // Single unified credentials controller
  final _emailController = TextEditingController(
    text: 'rep.officer@samarpan-ngo.org',
  );
  final _passwordController = TextEditingController(
    text: 'SentinelSecure2024!',
  );

  bool _rememberMe = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login([
    NgoRegistrationStatus? forcedStatus,
    UserRole? forcedRole,
  ]) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to Clerk identity service...';
    });

    try {
      await ref
          .read(authStateProvider.notifier)
          .signInWithClerk(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
            status: forcedStatus,
            roleHint: forcedRole,
          );

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Resolving application authorization & role...';
      });

      final authState = ref.read(authStateProvider);

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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Authentication failed: $e')));
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

              // 6. PMU Inspector
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.policy,
                  color: AppColors.primaryContainer,
                ),
                title: const Text('PMU / Field Inspector'),
                subtitle: const Text(
                  'inspector.saxena@dosje.gov.in → /inspector/dashboard',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'inspector.saxena@dosje.gov.in';
                    await _login(null, UserRole.inspector);
                  },
                ),
                onTap: () {
                  _emailController.text = 'inspector.saxena@dosje.gov.in';
                  Navigator.pop(ctx);
                },
              ),

              // 7. Department Official
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.admin_panel_settings,
                  color: AppColors.primaryContainer,
                ),
                title: const Text('Department Official (State Directorate)'),
                subtitle: const Text(
                  'official.sharma@dosje.gov.in → /official/dashboard',
                ),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 14),
                  label: const Text('Sign In'),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    _emailController.text = 'official.sharma@dosje.gov.in';
                    await _login(null, UserRole.official);
                  },
                ),
                onTap: () {
                  _emailController.text = 'official.sharma@dosje.gov.in';
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
                      'Unified single sign-on for all authorized stakeholders. Authenticate via Clerk to access your portal.',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Single Email Field
                    TextField(
                      controller: _emailController,
                      style: AppTypography.bodyMd,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        labelText: 'Authorized Email / User Identifier *',
                        prefixIcon: Icon(Icons.mail_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Single Password Field
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: AppTypography.bodyMd,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        labelText: 'Security Password *',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 18,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Remember Me & Forgot Password
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primaryContainer,
                              onChanged: _isLoading
                                  ? null
                                  : (v) =>
                                        setState(() => _rememberMe = v ?? true),
                            ),
                            Text('Remember me', style: AppTypography.bodySm),
                          ],
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : () {},
                          child: Text(
                            'Forgot password?',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),

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

                    const SizedBox(height: AppSpacing.md),

                    // Single Clerk Authentication Action Button
                    CivicButton(
                      label: 'Continue with Clerk',
                      icon: Icons.lock_open_rounded,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : () => _login(),
                    ),
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
