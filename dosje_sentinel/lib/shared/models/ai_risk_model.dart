enum RiskLevel {
  low,
  medium,
  high,
  critical;

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low Risk';
      case RiskLevel.medium:
        return 'Medium Risk';
      case RiskLevel.high:
        return 'High Risk';
      case RiskLevel.critical:
        return 'Critical Risk';
    }
  }

  static RiskLevel fromString(String? level) {
    switch (level?.toUpperCase()) {
      case 'CRITICAL':
        return RiskLevel.critical;
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      case 'LOW':
      default:
        return RiskLevel.low;
    }
  }
}

class RiskFactor {
  final String title;
  final String description;
  final double scoreImpact; // e.g. +14 pts

  const RiskFactor({
    required this.title,
    required this.description,
    required this.scoreImpact,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,
    'scoreImpact': scoreImpact,
  };

  factory RiskFactor.fromJson(Map<String, dynamic> json) => RiskFactor(
    title: json['title'] as String? ?? '',
    description: json['description'] as String? ?? '',
    scoreImpact: (json['scoreImpact'] as num?)?.toDouble() ?? 0.0,
  );
}

class AiRiskProfile {
  final String facilityId;
  final String facilityName;
  final int riskScore; // 0 - 100
  final RiskLevel riskLevel;
  final List<RiskFactor> riskFactors;
  final List<String> anomalyAlerts;
  final DateTime calculatedAt;

  const AiRiskProfile({
    required this.facilityId,
    required this.facilityName,
    required this.riskScore,
    required this.riskLevel,
    this.riskFactors = const [],
    this.anomalyAlerts = const [],
    required this.calculatedAt,
  });

  Map<String, dynamic> toJson() => {
    'facilityId': facilityId,
    'facilityName': facilityName,
    'riskScore': riskScore,
    'riskLevel': riskLevel.name,
    'riskFactors': riskFactors.map((e) => e.toJson()).toList(),
    'anomalyAlerts': anomalyAlerts,
    'calculatedAt': calculatedAt.toIso8601String(),
  };

  factory AiRiskProfile.fromJson(Map<String, dynamic> json) => AiRiskProfile(
    facilityId: json['facilityId'] as String? ?? '',
    facilityName: json['facilityName'] as String? ?? '',
    riskScore: json['riskScore'] as int? ?? 0,
    riskLevel: RiskLevel.values.firstWhere(
      (e) => e.name == json['riskLevel'],
      orElse: () => RiskLevel.low,
    ),
    riskFactors:
        (json['riskFactors'] as List<dynamic>?)
            ?.map((e) => RiskFactor.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    anomalyAlerts:
        (json['anomalyAlerts'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [],
    calculatedAt:
        DateTime.tryParse(json['calculatedAt'] as String? ?? '') ??
        DateTime.now(),
  );
}

class ProjectRiskModel {
  final int? score;
  final String? level;

  const ProjectRiskModel({
    this.score,
    this.level,
  });

  RiskLevel? get riskLevel => level != null ? RiskLevel.fromString(level) : null;

  factory ProjectRiskModel.fromJson(Map<String, dynamic> json) {
    return ProjectRiskModel(
      score: json['score'] as int?,
      level: json['level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'level': level,
    };
  }

  ProjectRiskModel copyWith({
    int? score,
    String? level,
  }) {
    return ProjectRiskModel(
      score: score ?? this.score,
      level: level ?? this.level,
    );
  }
}

