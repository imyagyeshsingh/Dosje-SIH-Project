import 'dart:async';

import '../../shared/models/evidence_model.dart';

enum EvidenceSyncStatus { pending, uploading, failed, synced }

class QueueItem {
  final EvidenceModel evidence;
  final String status; // WAITING_FOR_UPLOAD, UPLOADING, FAILED
  final DateTime queuedAt;
  final String? errorMessage;

  QueueItem({
    required this.evidence,
    this.status = 'WAITING_FOR_UPLOAD',
    DateTime? queuedAt,
    this.errorMessage,
  }) : queuedAt = queuedAt ?? DateTime.now();

  String get id => evidence.id;
  String get inspectionId => evidence.inspectionId;
  double get latitude => evidence.latitude ?? 27.1982;
  double get longitude => evidence.longitude ?? 78.0059;
  DateTime get timestamp => evidence.timestamp;
  EvidenceSyncStatus get syncStatus => status == 'FAILED'
      ? EvidenceSyncStatus.failed
      : EvidenceSyncStatus.pending;
}

typedef OfflineEvidenceItem = QueueItem;

abstract class OfflineQueueService {
  List<QueueItem> get pendingItems;
  Stream<List<QueueItem>> get queueStream;
  double get vaultStorageUsedMb;
  double get vaultStorageTotalMb;

  void enqueue(EvidenceModel evidence);
  void cancel(String evidenceId);
  Future<void> retryAll();
  Future<void> syncQueue();
  void retryItem(String evidenceId);
}

class DefaultOfflineQueueService implements OfflineQueueService {
  final StreamController<List<QueueItem>> _streamController =
      StreamController<List<QueueItem>>.broadcast();

  final List<QueueItem> _queue = [
    QueueItem(
      evidence: EvidenceModel(
        id: 'ev_offline_1',
        inspectionId: 'INS-2026-00482',
        title: 'Morning Shift Attendance Register Snapshot',
        fileName: 'Attendance_Register_23Sep2026_Morning.jpg',
        fileType: 'JPG',
        fileSizeBytes: 2400000,
        status: EvidenceStatus.uploadFailed,
        isGeoVerified: true,
        latitude: 27.1982,
        longitude: 78.0059,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      status: 'WAITING_FOR_UPLOAD',
    ),
    QueueItem(
      evidence: EvidenceModel(
        id: 'ev_offline_2',
        inspectionId: 'INS-2026-00482',
        title: 'Breakfast Distribution Register Copy',
        fileName: 'Breakfast_Nutrition_Distribution_Log.pdf',
        fileType: 'PDF',
        fileSizeBytes: 840000,
        status: EvidenceStatus.uploadFailed,
        isGeoVerified: true,
        latitude: 27.1982,
        longitude: 78.0059,
        timestamp: DateTime.now().subtract(const Duration(minutes: 18)),
      ),
      status: 'WAITING_FOR_UPLOAD',
    ),
  ];

  @override
  List<QueueItem> get pendingItems => List.unmodifiable(_queue);

  @override
  Stream<List<QueueItem>> get queueStream {
    // Yield current items immediately and on updates
    Future.microtask(() => _streamController.add(List.unmodifiable(_queue)));
    return _streamController.stream;
  }

  @override
  double get vaultStorageUsedMb => 3.24;

  @override
  double get vaultStorageTotalMb => 50.0;

  @override
  void enqueue(EvidenceModel evidence) {
    _queue.add(QueueItem(evidence: evidence));
    _streamController.add(List.unmodifiable(_queue));
  }

  @override
  void cancel(String evidenceId) {
    _queue.removeWhere((item) => item.evidence.id == evidenceId);
    _streamController.add(List.unmodifiable(_queue));
  }

  @override
  Future<void> retryAll() async {
    await Future.delayed(const Duration(milliseconds: 500));
    _queue.clear();
    _streamController.add(List.unmodifiable(_queue));
  }

  @override
  Future<void> syncQueue() => retryAll();

  @override
  void retryItem(String evidenceId) {
    _queue.removeWhere((item) => item.evidence.id == evidenceId);
    _streamController.add(List.unmodifiable(_queue));
  }
}
