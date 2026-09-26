
enum NotificationCategory {
  all,
  videoCalls,
  actionRequests,
  inspections,
  compliance;

  String get label {
    switch (this) {
      case NotificationCategory.all:
        return 'All';
      case NotificationCategory.videoCalls:
        return 'Video Calls';
      case NotificationCategory.actionRequests:
        return 'Action Requests';
      case NotificationCategory.inspections:
        return 'Inspections';
      case NotificationCategory.compliance:
        return 'Compliance';
    }
  }
}

enum NotificationType {
  alert('ALERT'),
  inspection('INSPECTION'),
  assignment('ASSIGNMENT'),
  report('REPORT'),
  videoSession('VIDEO_SESSION'),
  system('SYSTEM');

  final String value;
  const NotificationType(this.value);

  static NotificationType fromString(String? type) {
    if (type == null) return NotificationType.system;
    final upper = type.toUpperCase().replaceAll('-', '_');
    for (final val in NotificationType.values) {
      if (val.value == upper || val.name.toUpperCase() == upper) return val;
    }
    return NotificationType.system;
  }
}

enum NotificationSeverity {
  low('LOW'),
  medium('MEDIUM'),
  high('HIGH'),
  critical('CRITICAL');

  final String value;
  const NotificationSeverity(this.value);

  static NotificationSeverity? fromString(String? severity) {
    if (severity == null) return null;
    final upper = severity.toUpperCase();
    for (final val in NotificationSeverity.values) {
      if (val.value == upper || val.name.toUpperCase() == upper) return val;
    }
    return null;
  }
}

class NotificationItem {
  final String id;
  final int projectId;
  final String? recipientId;
  final String? recipientRole;
  final NotificationType notificationType;
  final NotificationSeverity? severity;
  final String title;
  final String message;
  final String source;
  final int? alertId;
  final int? inspectionId;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? projectCode;
  final String? countdownTarget;
  final String? routePath;
  final NotificationCategory? explicitCategory;
  final bool? explicitIsCritical;

  const NotificationItem({
    required this.id,
    this.projectId = 0,
    this.recipientId,
    this.recipientRole,
    this.notificationType = NotificationType.system,
    this.severity,
    required this.title,
    String? message,
    String? description,
    this.source = 'SYSTEM',
    this.alertId,
    this.inspectionId,
    this.isRead = false,
    this.readAt,
    DateTime? createdAt,
    DateTime? timestamp,
    this.updatedAt,
    this.projectCode,
    this.countdownTarget,
    this.routePath,
    NotificationCategory? category,
    bool? isCritical,
  })  : message = message ?? description ?? '',
        createdAt = createdAt ?? timestamp ?? const _DefaultDateTime(),
        explicitCategory = category,
        explicitIsCritical = isCritical;

  /// Backward-compatibility getters
  String get description => message;
  DateTime get timestamp => createdAt;

  NotificationCategory get category {
    if (explicitCategory != null) return explicitCategory!;
    switch (notificationType) {
      case NotificationType.videoSession:
        return NotificationCategory.videoCalls;
      case NotificationType.alert:
        return NotificationCategory.actionRequests;
      case NotificationType.inspection:
      case NotificationType.assignment:
        return NotificationCategory.inspections;
      case NotificationType.report:
        return NotificationCategory.compliance;
      case NotificationType.system:
        return NotificationCategory.all;
    }
  }

  bool get isCritical {
    if (explicitIsCritical != null) return explicitIsCritical!;
    return severity == NotificationSeverity.critical ||
        severity == NotificationSeverity.high;
  }

  int? get idAsInt => int.tryParse(id);

  NotificationItem copyWith({
    String? id,
    int? projectId,
    String? recipientId,
    String? recipientRole,
    NotificationType? notificationType,
    NotificationSeverity? severity,
    String? title,
    String? message,
    String? description,
    String? source,
    int? alertId,
    int? inspectionId,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? timestamp,
    DateTime? updatedAt,
    String? projectCode,
    String? countdownTarget,
    String? routePath,
    NotificationCategory? category,
    bool? isCritical,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      recipientId: recipientId ?? this.recipientId,
      recipientRole: recipientRole ?? this.recipientRole,
      notificationType: notificationType ?? this.notificationType,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? description ?? this.message,
      source: source ?? this.source,
      alertId: alertId ?? this.alertId,
      inspectionId: inspectionId ?? this.inspectionId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? timestamp ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      projectCode: projectCode ?? this.projectCode,
      countdownTarget: countdownTarget ?? this.countdownTarget,
      routePath: routePath ?? this.routePath,
      category: category ?? explicitCategory,
      isCritical: isCritical ?? explicitIsCritical,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': idAsInt ?? id,
    'project_id': projectId,
    'recipient_id': recipientId,
    'recipient_role': recipientRole,
    'notification_type': notificationType.value,
    'severity': severity?.value,
    'title': title,
    'message': message,
    'description': message,
    'source': source,
    'alert_id': alertId,
    'inspection_id': inspectionId,
    'is_read': isRead,
    'isRead': isRead,
    'read_at': readAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'timestamp': createdAt.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'category': category.name,
    'isCritical': isCritical,
    'projectCode': projectCode,
    'countdownTarget': countdownTarget,
    'routePath': routePath,
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final idStr = rawId != null ? rawId.toString() : '';

    final typeStr = json['notification_type'] as String?;
    final notifType = typeStr != null
        ? NotificationType.fromString(typeStr)
        : (json['category'] != null
            ? _typeFromCategoryName(json['category'] as String?)
            : NotificationType.system);

    final rawSeverity = json['severity'] as String?;
    final notifSeverity = rawSeverity != null
        ? NotificationSeverity.fromString(rawSeverity)
        : null;

    final msg = json['message'] as String? ?? json['description'] as String? ?? '';
    final title = json['title'] as String? ?? (notifType == NotificationType.alert ? 'Alert Notification' : 'Notification');

    final createdStr = json['created_at'] as String? ?? json['timestamp'] as String?;
    final created = createdStr != null
        ? DateTime.tryParse(createdStr) ?? DateTime.now()
        : DateTime.now();

    final readAtStr = json['read_at'] as String?;
    final readAt = readAtStr != null ? DateTime.tryParse(readAtStr) : null;

    final updatedStr = json['updated_at'] as String?;
    final updated = updatedStr != null ? DateTime.tryParse(updatedStr) : null;

    final isRead = (json['is_read'] as bool?) ?? (json['isRead'] as bool?) ?? false;

    // Route path inference if not explicitly provided
    String? routePath = json['routePath'] as String?;
    if (routePath == null) {
      if (json['inspection_id'] != null) {
        routePath = '/ngo/inspections/detail/${json['inspection_id']}';
      } else if (json['alert_id'] != null) {
        routePath = '/ngo/inspections';
      }
    }

    return NotificationItem(
      id: idStr,
      projectId: (json['project_id'] as num?)?.toInt() ?? 0,
      recipientId: json['recipient_id'] as String?,
      recipientRole: json['recipient_role'] as String?,
      notificationType: notifType,
      severity: notifSeverity,
      title: title,
      message: msg,
      source: json['source'] as String? ?? 'SYSTEM',
      alertId: (json['alert_id'] as num?)?.toInt(),
      inspectionId: (json['inspection_id'] as num?)?.toInt(),
      isRead: isRead,
      readAt: readAt,
      createdAt: created,
      updatedAt: updated,
      projectCode: json['projectCode'] as String?,
      countdownTarget: json['countdownTarget'] as String?,
      routePath: routePath,
      isCritical: json['isCritical'] as bool?,
    );
  }

  static NotificationType _typeFromCategoryName(String? catName) {
    if (catName == null) return NotificationType.system;
    switch (catName) {
      case 'videoCalls':
        return NotificationType.videoSession;
      case 'actionRequests':
        return NotificationType.alert;
      case 'inspections':
        return NotificationType.inspection;
      case 'compliance':
        return NotificationType.report;
      default:
        return NotificationType.system;
    }
  }
}

/// Fallback helper for default DateTime when unspecified in const constructor
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();

  DateTime get _now => DateTime.now();

  @override
  bool isAfter(DateTime other) => _now.isAfter(other);
  @override
  bool isBefore(DateTime other) => _now.isBefore(other);
  @override
  bool isAtSameMomentAs(DateTime other) => _now.isAtSameMomentAs(other);
  @override
  int compareTo(DateTime other) => _now.compareTo(other);
  @override
  DateTime add(Duration duration) => _now.add(duration);
  @override
  DateTime subtract(Duration duration) => _now.subtract(duration);
  @override
  Duration difference(DateTime other) => _now.difference(other);
  @override
  int get millisecondsSinceEpoch => _now.millisecondsSinceEpoch;
  @override
  int get microsecondsSinceEpoch => _now.microsecondsSinceEpoch;
  @override
  String get timeZoneName => _now.timeZoneName;
  @override
  Duration get timeZoneOffset => _now.timeZoneOffset;
  @override
  int get year => _now.year;
  @override
  int get month => _now.month;
  @override
  int get day => _now.day;
  @override
  int get hour => _now.hour;
  @override
  int get minute => _now.minute;
  @override
  int get second => _now.second;
  @override
  int get millisecond => _now.millisecond;
  @override
  int get microsecond => _now.microsecond;
  @override
  int get weekday => _now.weekday;
  @override
  bool get isUtc => _now.isUtc;
  @override
  DateTime toLocal() => _now.toLocal();
  @override
  DateTime toUtc() => _now.toUtc();
  @override
  String toIso8601String() => _now.toIso8601String();
  @override
  String toString() => _now.toString();
}

/// Type alias for parity across codebase naming conventions
typedef NotificationModel = NotificationItem;

class NotificationSummary {
  final int total;
  final int unread;

  const NotificationSummary({this.total = 0, this.unread = 0});

  factory NotificationSummary.fromJson(Map<String, dynamic> json) =>
      NotificationSummary(
        total: (json['total'] as num?)?.toInt() ?? 0,
        unread: (json['unread'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'total': total,
    'unread': unread,
  };
}

class NotificationBulkReadResult {
  final int markedRead;

  const NotificationBulkReadResult({this.markedRead = 0});

  factory NotificationBulkReadResult.fromJson(Map<String, dynamic> json) =>
      NotificationBulkReadResult(
        markedRead: (json['marked_read'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'marked_read': markedRead,
  };
}
