class FollowUpAction {
  final String id;
  final String inspectionId;
  final String title;
  final String description;
  final DateTime deadline;
  final String status; // PENDING, SUBMITTED, RESOLVED
  final String? responseText;
  final List<String> evidenceIds;
  final DateTime? submittedAt;

  const FollowUpAction({
    required this.id,
    required this.inspectionId,
    required this.title,
    required this.description,
    required this.deadline,
    this.status = 'PENDING',
    this.responseText,
    this.evidenceIds = const [],
    this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'title': title,
    'description': description,
    'deadline': deadline.toIso8601String(),
    'status': status,
    'responseText': responseText,
    'evidenceIds': evidenceIds,
    'submittedAt': submittedAt?.toIso8601String(),
  };

  factory FollowUpAction.fromJson(Map<String, dynamic> json) => FollowUpAction(
    id: json['id'] as String? ?? '',
    inspectionId: json['inspectionId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    deadline:
        DateTime.tryParse(json['deadline'] as String? ?? '') ?? DateTime.now(),
    status: json['status'] as String? ?? 'PENDING',
    responseText: json['responseText'] as String?,
    evidenceIds:
        (json['evidenceIds'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    submittedAt: json['submittedAt'] != null
        ? DateTime.tryParse(json['submittedAt'] as String)
        : null,
  );
}
