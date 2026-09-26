import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/ngo_profile_model.dart';
import '../../../../shared/providers/core_providers.dart';
import '../../../../core/realtime/realtime_service.dart';

class AllNgosNotifier extends StateNotifier<AsyncValue<List<NgoProfileModel>>> {
  final Ref ref;
  StreamSubscription<RealtimeEvent>? _subscription;
  String? latestEventBanner;

  AllNgosNotifier(this.ref) : super(const AsyncValue.loading()) {
    loadNgos();
    _listenToRealtimeEvents();
  }

  Future<void> loadNgos() async {
    state = const AsyncValue.loading();
    try {
      final repo = ref.read(officialNgoRepositoryProvider);
      final ngos = await repo.getAllNgos();
      state = AsyncValue.data(ngos);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _listenToRealtimeEvents() {
    final realtime = ref.read(realtimeServiceProvider);
    _subscription = realtime.eventStream.listen((event) {
      if (event.event == 'NGO_REGISTERED' ||
          event.event == 'NGO_PROFILE_UPDATED' ||
          event.event == 'NGO_REGISTRATION_STATUS_CHANGED') {
        // Refresh authoritative NGO list from repository without restarting app
        loadNgosSilently(event.data['ngoName'] as String? ?? 'New NGO');
      }
    });
  }

  Future<void> loadNgosSilently(String newNgoName) async {
    try {
      final repo = ref.read(officialNgoRepositoryProvider);
      final ngos = await repo.getAllNgos();
      latestEventBanner = 'New NGO registered: $newNgoName';
      state = AsyncValue.data(ngos);
    } catch (_) {}
  }

  void clearBanner() {
    latestEventBanner = null;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final allNgosProvider =
    StateNotifierProvider<AllNgosNotifier, AsyncValue<List<NgoProfileModel>>>((
      ref,
    ) {
      return AllNgosNotifier(ref);
    });

final ngoDetailProvider = FutureProvider.family<NgoProfileModel?, String>((
  ref,
  ngoId,
) async {
  final repo = ref.watch(officialNgoRepositoryProvider);
  return await repo.getNgoDetails(ngoId);
});
