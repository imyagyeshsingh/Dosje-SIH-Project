import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../app/theme/spacing.dart';
import '../../../../shared/models/permission.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../shared/widgets/civic_app_bar.dart';
import '../../../../shared/widgets/civic_card.dart';
import '../../../../shared/widgets/civic_button.dart';
import '../../../../shared/widgets/error_state_view.dart';
import '../providers/official_ngos_provider.dart';

class NgoRegistrationReviewScreen extends ConsumerStatefulWidget {
  final String ngoId;

  const NgoRegistrationReviewScreen({super.key, required this.ngoId});

  @override
  ConsumerState<NgoRegistrationReviewScreen> createState() =>
      _NgoRegistrationReviewScreenState();
}

class _NgoRegistrationReviewScreenState
    extends ConsumerState<NgoRegistrationReviewScreen> {
  final _notesController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(officialNgoRepositoryProvider);
      await repo.approveRegistration(widget.ngoId);
      ref.invalidate(allNgosProvider);
      ref.invalidate(ngoDetailProvider(widget.ngoId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('NGO Registration Approved successfully.'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _requestCorrection() async {
    final notes = _notesController.text.trim();
    if (notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please specify correction requirements.'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(officialNgoRepositoryProvider);
      await repo.requestCorrection(widget.ngoId, notes);
      ref.invalidate(allNgosProvider);
      ref.invalidate(ngoDetailProvider(widget.ngoId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Correction request dispatched to NGO.'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final canApprove = authState.hasPermission(
      Permission.approveNgoRegistration,
    );

    if (!canApprove) {
      return const Scaffold(
        appBar: CivicAppBar(title: 'Review Registration'),
        body: ErrorStateView(
          title: 'Permission Denied',
          message: 'Your official credentials lack approveNgoRegistration permission.',
        ),
      );
    }

    final ngoAsync = ref.watch(ngoDetailProvider(widget.ngoId));

    return Scaffold(
      appBar: const CivicAppBar(
        title: 'Review NGO Application',
        subtitle: 'Official Sanctioning Desk',
      ),
      body: SafeArea(
        child: ngoAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorStateView(message: e.toString()),
          data: (ngo) {
            if (ngo == null) {
              return const ErrorStateView(message: 'NGO record not found.');
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.screenMargin),
              children: [
                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ngo.ngoName,
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Representative: ${ngo.fullName} (${ngo.designation})',
                        style: AppTypography.bodySm,
                      ),
                      Text(
                        'Location: ${ngo.city}, ${ngo.state}',
                        style: AppTypography.bodySm,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                CivicCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Review Evaluation Notes',
                        style: AppTypography.labelLg.copyWith(
                          color: AppColors.primaryContainer,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Enter findings or required amendments if returning application for correction.',
                        style: AppTypography.bodySm,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _notesController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Enter observation / correction notes...',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                CivicButton(
                  label: 'Approve & Sanction NGO',
                  icon: Icons.check_circle,
                  isLoading: _isProcessing,
                  onPressed: _approve,
                ),
                const SizedBox(height: AppSpacing.sm),
                CivicButton(
                  label: 'Flag Correction Required',
                  icon: Icons.edit_note,
                  type: ButtonType.destructive,
                  isLoading: _isProcessing,
                  onPressed: _requestCorrection,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
