class ScoringSession {
  final int id;
  final int athleteId;
  final String? athleteName;
  final String? athleteCode;
  final String bowCategory;
  final String sessionType;
  final String distance;
  final int arrowsPerEnd;
  final int totalEnds;
  final int currentEnd;
  final String status;
  final String? startedAt;
  final String? completedAt;

  ScoringSession({
    required this.id,
    required this.athleteId,
    this.athleteName,
    this.athleteCode,
    required this.bowCategory,
    required this.sessionType,
    required this.distance,
    required this.arrowsPerEnd,
    required this.totalEnds,
    required this.currentEnd,
    required this.status,
    this.startedAt,
    this.completedAt,
  });

  bool get isCompleted => status == 'completed';

  factory ScoringSession.fromJson(Map<String, dynamic> json) {
    return ScoringSession(
      id: json['id'] as int,
      athleteId: json['athlete_id'] as int,
      athleteName: json['athlete_name'] as String?,
      athleteCode: json['athlete_code'] as String?,
      bowCategory: json['bow_category'] as String,
      sessionType: json['session_type'] as String,
      distance: json['distance'] as String,
      arrowsPerEnd: json['arrows_per_end'] as int,
      totalEnds: json['total_ends'] as int,
      currentEnd: json['current_end'] as int,
      status: json['status'] as String,
      startedAt: json['started_at']?.toString(),
      completedAt: json['completed_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'athlete_id': athleteId,
    if (athleteName != null) 'athlete_name': athleteName,
    if (athleteCode != null) 'athlete_code': athleteCode,
    'bow_category': bowCategory,
    'session_type': sessionType,
    'distance': distance,
    'arrows_per_end': arrowsPerEnd,
    'total_ends': totalEnds,
    'current_end': currentEnd,
    'status': status,
    if (startedAt != null) 'started_at': startedAt,
    if (completedAt != null) 'completed_at': completedAt,
  };

  ScoringSession copyWith({
    int? id,
    int? athleteId,
    String? athleteName,
    String? athleteCode,
    String? bowCategory,
    String? sessionType,
    String? distance,
    int? arrowsPerEnd,
    int? totalEnds,
    int? currentEnd,
    String? status,
    String? startedAt,
    String? completedAt,
  }) {
    return ScoringSession(
      id: id ?? this.id,
      athleteId: athleteId ?? this.athleteId,
      athleteName: athleteName ?? this.athleteName,
      athleteCode: athleteCode ?? this.athleteCode,
      bowCategory: bowCategory ?? this.bowCategory,
      sessionType: sessionType ?? this.sessionType,
      distance: distance ?? this.distance,
      arrowsPerEnd: arrowsPerEnd ?? this.arrowsPerEnd,
      totalEnds: totalEnds ?? this.totalEnds,
      currentEnd: currentEnd ?? this.currentEnd,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
