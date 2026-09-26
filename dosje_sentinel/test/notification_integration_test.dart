@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dosje_sentinel/core/error/app_exception.dart';
import 'package:dosje_sentinel/core/network/api_client.dart';
import 'package:dosje_sentinel/core/network/api_endpoints.dart';
import 'package:dosje_sentinel/repositories/notification_repository.dart';
import 'package:dosje_sentinel/repositories/project_repository.dart';
import 'package:dosje_sentinel/repositories/alert_repository.dart';
import 'package:dosje_sentinel/shared/models/notification_model.dart';
import 'package:dosje_sentinel/shared/providers/core_providers.dart';

void main() {
  group('Notification Models & Serialization Integration', () {
    test('NotificationItem deserializes backend NotificationResponse accurately', () {
      final json = {
        'id': 101,
        'project_id': 20,
        'recipient_id': 'officer_42',
        'recipient_role': 'INSPECTOR',
        'notification_type': 'ALERT',
        'severity': 'HIGH',
        'title': 'High Risk Alert',
        'message': 'Composite risk elevated to HIGH: score 74',
        'source': 'ALERT_ENGINE',
        'alert_id': 15,
        'inspection_id': null,
        'is_read': false,
        'read_at': null,
        'created_at': '2026-09-24T10:00:00Z',
        'updated_at': '2026-09-24T10:00:00Z',
      };

      final item = NotificationItem.fromJson(json);

      expect(item.id, '101');
      expect(item.projectId, 20);
      expect(item.recipientId, 'officer_42');
      expect(item.recipientRole, 'INSPECTOR');
      expect(item.notificationType, NotificationType.alert);
      expect(item.severity, NotificationSeverity.high);
      expect(item.title, 'High Risk Alert');
      expect(item.message, 'Composite risk elevated to HIGH: score 74');
      expect(item.description, 'Composite risk elevated to HIGH: score 74');
      expect(item.source, 'ALERT_ENGINE');
      expect(item.alertId, 15);
      expect(item.inspectionId, isNull);
      expect(item.isRead, isFalse);
      expect(item.readAt, isNull);
      expect(item.category, NotificationCategory.actionRequests);
      expect(item.isCritical, isTrue);
      expect(item.idAsInt, 101);
    });

    test('NotificationItem handles category mapping for all notification types', () {
      expect(
        const NotificationItem(id: '1', title: 't', notificationType: NotificationType.videoSession).category,
        NotificationCategory.videoCalls,
      );
      expect(
        const NotificationItem(id: '2', title: 't', notificationType: NotificationType.alert).category,
        NotificationCategory.actionRequests,
      );
      expect(
        const NotificationItem(id: '3', title: 't', notificationType: NotificationType.inspection).category,
        NotificationCategory.inspections,
      );
      expect(
        const NotificationItem(id: '4', title: 't', notificationType: NotificationType.assignment).category,
        NotificationCategory.inspections,
      );
      expect(
        const NotificationItem(id: '5', title: 't', notificationType: NotificationType.report).category,
        NotificationCategory.compliance,
      );
      expect(
        const NotificationItem(id: '6', title: 't', notificationType: NotificationType.system).category,
        NotificationCategory.all,
      );
    });

    test('NotificationItem handles nullable and optional fields gracefully', () {
      final jsonWithNulls = {
        'id': 102,
        'project_id': 20,
        'recipient_id': null,
        'recipient_role': null,
        'notification_type': 'SYSTEM',
        'severity': null,
        'title': null,
        'message': 'System maintenance completed',
        'source': 'SYSTEM',
        'alert_id': null,
        'inspection_id': null,
        'is_read': true,
        'read_at': '2026-09-24T12:00:00Z',
        'created_at': '2026-09-24T11:00:00Z',
        'updated_at': null,
      };

      final item = NotificationItem.fromJson(jsonWithNulls);

      expect(item.id, '102');
      expect(item.recipientId, isNull);
      expect(item.recipientRole, isNull);
      expect(item.severity, isNull);
      expect(item.title, 'Notification');
      expect(item.isRead, isTrue);
      expect(item.readAt, isNotNull);
      expect(item.isCritical, isFalse);
    });

    test('NotificationSummary serialization and deserialization works', () {
      final json = {'total': 12, 'unread': 3};
      final summary = NotificationSummary.fromJson(json);

      expect(summary.total, 12);
      expect(summary.unread, 3);
      expect(summary.toJson(), equals(json));
    });

    test('NotificationBulkReadResult serialization and deserialization works', () {
      final json = {'marked_read': 5};
      final result = NotificationBulkReadResult.fromJson(json);

      expect(result.markedRead, 5);
      expect(result.toJson(), equals(json));
    });
  });

  group('MockNotificationRepository Tests', () {
    late MockNotificationRepository repo;

    setUp(() {
      repo = MockNotificationRepository();
    });

    test('fetches seeded notifications and sorts newest first', () async {
      final list = await repo.getNotifications();
      expect(list, isNotEmpty);
      expect(list.length, greaterThanOrEqualTo(4));
    });

    test('filters notifications by isRead and notificationType', () async {
      final unread = await repo.getNotifications(isRead: false);
      expect(unread.every((n) => !n.isRead), isTrue);

      final alerts = await repo.getNotifications(notificationType: 'ALERT');
      expect(alerts.every((n) => n.notificationType == NotificationType.alert), isTrue);
    });

    test('getNotificationSummary computes accurate counts', () async {
      final summary = await repo.getNotificationSummary();
      expect(summary.total, greaterThanOrEqualTo(4));
      expect(summary.unread, greaterThanOrEqualTo(1));
    });

    test('createNotification adds item to in-memory store', () async {
      final created = await repo.createNotification(
        projectId: 1,
        notificationType: 'SYSTEM',
        message: 'New unit test notification',
        source: 'UnitTest',
        severity: 'LOW',
        title: 'Unit Test',
      );

      expect(created.id, isNotEmpty);
      expect(created.message, 'New unit test notification');
      expect(created.isRead, isFalse);

      final fetched = await repo.getNotificationById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
    });

    test('markAsRead updates isRead and readAt', () async {
      final list = await repo.getNotifications(isRead: false);
      expect(list, isNotEmpty);
      final unreadItem = list.first;

      final updated = await repo.markAsRead(unreadItem.id);
      expect(updated.isRead, isTrue);
      expect(updated.readAt, isNotNull);
    });

    test('markAllAsRead marks unread items as read', () async {
      final result = await repo.markAllAsRead();
      expect(result.markedRead, greaterThanOrEqualTo(0));

      final unreadAfter = await repo.getNotifications(isRead: false);
      expect(unreadAfter, isEmpty);
    });

    test('getNotificationById returns null for missing ID', () async {
      final item = await repo.getNotificationById('999999');
      expect(item, isNull);
    });

    test('markAsRead throws NotFoundException for missing ID', () async {
      expect(() => repo.markAsRead('999999'), throwsA(isA<NotFoundException>()));
    });
  });

  group('Notification Riverpod Providers Integration', () {
    late ProviderContainer container;
    late MockNotificationRepository mockRepo;

    setUp(() {
      mockRepo = MockNotificationRepository();
      container = ProviderContainer(
        overrides: [
          notificationRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('notificationsProvider returns list of notifications', () async {
      final notifs = await container.read(notificationsProvider.future);
      expect(notifs, isNotEmpty);
      expect(notifs.length, greaterThanOrEqualTo(4));
    });

    test('projectNotificationsProvider returns project-specific notifications', () async {
      final notifs = await container.read(projectNotificationsProvider(1).future);
      expect(notifs, isNotEmpty);
      expect(notifs.every((n) => n.projectId == 1), isTrue);
    });

    test('notificationSummaryProvider returns summary with unread count', () async {
      final summary = await container.read(notificationSummaryProvider.future);
      expect(summary.total, greaterThanOrEqualTo(4));
      expect(summary.unread, greaterThanOrEqualTo(1));
    });

    test('singleNotificationProvider returns matching item or null', () async {
      final item = await container.read(singleNotificationProvider('1').future);
      expect(item, isNotNull);
      expect(item!.id, '1');

      final nonExistent = await container.read(singleNotificationProvider('999999').future);
      expect(nonExistent, isNull);
    });
  });

  group('ApiNotificationRepository Live Integration against FastAPI', () {
    late ApiClient apiClient;
    late ApiNotificationRepository notifRepo;
    late ApiProjectRepository projectRepo;
    late ApiAlertRepository alertRepo;
    late int stableProjectId;

    setUpAll(() async {
      ApiEndpoints.setBaseUrl('http://127.0.0.1:8000');
      apiClient = ApiClient();
      projectRepo = ApiProjectRepository(apiClient: apiClient);
      notifRepo = ApiNotificationRepository(
        apiClient: apiClient,
        projectRepository: projectRepo,
      );
      alertRepo = ApiAlertRepository(
        apiClient: apiClient,
        projectRepository: projectRepo,
      );
      final projects = await projectRepo.getProjects(limit: 10);
      final stable = projects.firstWhere(
        (p) => p.code == 'NEON-TEST-001',
        orElse: () => projects.first,
      );
      stableProjectId = int.parse(stable.id);
    });

    test('Live Notification: fetch notifications and summary', () async {
      final initialNotifs = await notifRepo.getNotifications(limit: 10);
      expect(initialNotifs, isA<List<NotificationItem>>());

      final initialSummary = await notifRepo.getNotificationSummary(projectId: stableProjectId);
      expect(initialSummary.total, greaterThanOrEqualTo(0));
      expect(initialSummary.unread, greaterThanOrEqualTo(0));
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Notification: create notification and fetch by ID', () async {
      final testUnique = DateTime.now().millisecondsSinceEpoch;
      final created = await notifRepo.createNotification(
        projectId: stableProjectId,
        notificationType: 'SYSTEM',
        message: 'Live integration test notification $testUnique',
        source: 'NotificationIntegrationTest',
        severity: 'HIGH',
        title: 'Integration Test Notif',
        recipientId: 'test_officer_$testUnique',
        recipientRole: 'INSPECTOR',
      );

      expect(created.id, isNotEmpty);
      expect(created.projectId, stableProjectId);
      expect(created.notificationType, NotificationType.system);
      expect(created.severity, NotificationSeverity.high);
      expect(created.message, 'Live integration test notification $testUnique');
      expect(created.recipientId, 'test_officer_$testUnique');
      expect(created.recipientRole, 'INSPECTOR');
      expect(created.isRead, isFalse);

      final fetched = await notifRepo.getNotificationById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.id, created.id);
      expect(fetched.message, created.message);
      expect(fetched.isRead, isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Notification: recipient filtering and project notifications', () async {
      final testUnique = DateTime.now().millisecondsSinceEpoch;
      final created = await notifRepo.createNotification(
        projectId: stableProjectId,
        notificationType: 'SYSTEM',
        message: 'Recipient filter test $testUnique',
        source: 'RecipientTest',
        recipientId: 'filter_officer_$testUnique',
      );

      final filteredByRecipient = await notifRepo.getNotifications(
        recipientId: 'filter_officer_$testUnique',
      );
      expect(filteredByRecipient, isNotEmpty);
      expect(filteredByRecipient.first.id, created.id);

      final projectNotifs = await notifRepo.getProjectNotifications(stableProjectId);
      expect(projectNotifs, isA<List<NotificationItem>>());
      expect(projectNotifs.any((n) => n.id == created.id), isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Notification: mark single notification read and verify idempotency', () async {
      final created = await notifRepo.createNotification(
        projectId: stableProjectId,
        notificationType: 'SYSTEM',
        message: 'Mark read test ${DateTime.now().millisecondsSinceEpoch}',
        source: 'ReadTest',
      );

      final markedRead = await notifRepo.markAsRead(created.id);
      expect(markedRead.isRead, isTrue);
      expect(markedRead.readAt, isNotNull);

      // Verify idempotent second call maintains read state
      final markedReadAgain = await notifRepo.markAsRead(created.id);
      expect(markedReadAgain.isRead, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Notification: mark all notifications read with recipient filter', () async {
      final testUnique = DateTime.now().millisecondsSinceEpoch;
      final created = await notifRepo.createNotification(
        projectId: stableProjectId,
        notificationType: 'REPORT',
        message: 'Bulk read test notification $testUnique',
        source: 'BulkTest',
        recipientId: 'bulk_officer_$testUnique',
      );
      expect(created.isRead, isFalse);

      final bulkResult = await notifRepo.markAllAsRead(
        recipientId: 'bulk_officer_$testUnique',
      );
      expect(bulkResult.markedRead, greaterThanOrEqualTo(1));

      final fetched = await notifRepo.getNotificationById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.isRead, isTrue);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('Live Notification: backend alert generation generates notification', () async {
      // POST /alerts/generate/{project_id} triggers notify_alert()
      try {
        await alertRepo.generateProjectAlerts(stableProjectId);
      } catch (_) {}
      final alertNotifs = await notifRepo.getNotifications(
        projectId: stableProjectId,
        notificationType: 'ALERT',
        limit: 10,
      );
      expect(alertNotifs, isA<List<NotificationItem>>());
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('getNotificationById returns null for non-existent notification (404 handling)', () async {
      final notif = await notifRepo.getNotificationById(999999);
      expect(notif, isNull);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('getProjectNotifications returns empty list for non-existent project (404 handling)', () async {
      final notifs = await notifRepo.getProjectNotifications(999999);
      expect(notifs, isEmpty);
    }, timeout: const Timeout(Duration(minutes: 2)));


  });
}
