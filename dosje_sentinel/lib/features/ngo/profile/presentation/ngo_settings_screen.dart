import 'package:flutter/material.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';

class NgoSettingsScreen extends StatefulWidget {
  const NgoSettingsScreen({super.key});

  @override
  State<NgoSettingsScreen> createState() => _NgoSettingsScreenState();
}

class _NgoSettingsScreenState extends State<NgoSettingsScreen> {
  bool _biometricsEnabled = true;
  bool _pushNotifications = true;
  bool _auditAlerts = true;
  bool _autoSyncWifi = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceCanvas,
      appBar: const CivicAppBar(
        title: 'Settings & Security',
        showProfileAvatar: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenMargin),
        children: [
          Text(
            'SECURITY & AUTHENTICATION',
            style: AppTypography.labelSm.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 8),
          CivicCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Biometric App Lock',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Require FaceID / Fingerprint on launch',
                    style: AppTypography.caption,
                  ),
                  value: _biometricsEnabled,
                  activeColor: AppColors.primaryContainer,
                  onChanged: (val) => setState(() => _biometricsEnabled = val),
                ),
                const Divider(height: 1, color: AppColors.surfaceContainer),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Active Session',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Authenticated via Secure Government SSO',
                    style: AppTypography.caption,
                  ),
                  trailing: const Icon(
                    Icons.shield_outlined,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'NOTIFICATIONS & ALERTS',
            style: AppTypography.labelSm.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 8),
          CivicCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Push Notifications',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Receive inspection notices & action requests',
                    style: AppTypography.caption,
                  ),
                  value: _pushNotifications,
                  activeColor: AppColors.primaryContainer,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                const Divider(height: 1, color: AppColors.surfaceContainer),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Surprise Video Audit Alert',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Play high-priority chime on incoming video inspection',
                    style: AppTypography.caption,
                  ),
                  value: _auditAlerts,
                  activeColor: AppColors.primaryContainer,
                  onChanged: (val) => setState(() => _auditAlerts = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'DATA & FIELD SYNC',
            style: AppTypography.labelSm.copyWith(color: AppColors.outline),
          ),
          const SizedBox(height: 8),
          CivicCard(
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Auto-Sync on Any Network',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Upload queued evidence on cellular and Wi-Fi',
                    style: AppTypography.caption,
                  ),
                  value: _autoSyncWifi,
                  activeColor: AppColors.primaryContainer,
                  onChanged: (val) => setState(() => _autoSyncWifi = val),
                ),
                const Divider(height: 1, color: AppColors.surfaceContainer),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Clear Local Offline Cache',
                    style: AppTypography.bodySm.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Free up temporary photographic media storage',
                    style: AppTypography.caption,
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline media cache cleared'),
                        ),
                      );
                    },
                    child: Text(
                      'Clear',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'DoSJE Sentinel Mobile Client v2.4.0\nDepartment of Social Justice & Empowerment, Govt. of India',
              style: AppTypography.caption.copyWith(
                color: AppColors.outline,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
