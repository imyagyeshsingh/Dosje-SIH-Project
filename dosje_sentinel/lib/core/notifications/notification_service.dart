import 'dart:async';

import '../../repositories/notification_repository.dart';
import '../../shared/models/notification_model.dart';

abstract class NotificationService {
  Stream<NotificationItem> get notificationStream;
  Future<String?> getDeviceFcmToken();
  Future<void> markAsRead(dynamic notificationId);
}

class DefaultNotificationService implements NotificationService {
  final StreamController<NotificationItem> _streamController =
      StreamController<NotificationItem>.broadcast();
  final NotificationRepository? _repository;

  DefaultNotificationService([this._repository]);

  @override
  Stream<NotificationItem> get notificationStream => _streamController.stream;

  @override
  Future<String?> getDeviceFcmToken() async {
    return 'fcm_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> markAsRead(dynamic notificationId) async {
    final repo = _repository;
    if (repo != null) {
      await repo.markAsRead(notificationId);
    }
  }

  void notifyInApp(NotificationItem item) {
    _streamController.add(item);
  }

  void dispose() {
    _streamController.close();
  }
}
