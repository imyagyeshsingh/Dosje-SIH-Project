import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/ngo_profile_model.dart';
import '../../../../shared/models/ngo_registration_status.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../core/realtime/realtime_service.dart';

final ngoProfileFutureProvider = FutureProvider<NgoProfileModel?>((ref) async {
  final repo = ref.watch(ngoRepositoryProvider);
  return await repo.getMyProfile();
});

class NgoRegistrationNotifier
    extends StateNotifier<AsyncValue<NgoProfileModel?>> {
  final Ref ref;

  NgoRegistrationNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadProfile();
  }

  Future<void> loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(ngoRepositoryProvider);
      final profile = await repo.getMyProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<NgoProfileModel> submitRegistration(
    NgoProfileModel updatedProfile,
  ) async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(ngoRepositoryProvider);
      // Save profile
      await repo.updateProfile(updatedProfile);
      // Submit registration
      final submitted = await repo.submitRegistration(updatedProfile.id);

      // Update auth state registration status
      ref
          .read(authStateProvider.notifier)
          .updateNgoRegistrationStatus(NgoRegistrationStatus.submitted);

      // Publish Realtime Event: NGO_REGISTERED
      final realtime = ref.read(realtimeServiceProvider);
      final event = RealtimeEvent(
        event: 'NGO_REGISTERED',
        data: submitted.toJson(),
      );
      realtime.emitSimulatedEvent(event);

      // Also ensure Official repo receives the newly registered NGO directly
      ref.read(officialNgoRepositoryProvider).addRegisteredNgo(submitted);

      state = AsyncValue.data(submitted);
      return submitted;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

final ngoRegistrationProvider =
    StateNotifierProvider<
      NgoRegistrationNotifier,
      AsyncValue<NgoProfileModel?>
    >((ref) {
      return NgoRegistrationNotifier(ref);
    });
