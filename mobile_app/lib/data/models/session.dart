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
}
