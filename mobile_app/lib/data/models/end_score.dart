class ArrowScore {
  final int? id;
  final int? endId;
  final int arrowNumber;
  final String score;
  final bool isX;
  final String source;

  ArrowScore({
    this.id,
    this.endId,
    required this.arrowNumber,
    required this.score,
    this.isX = false,
    this.source = 'manual',
  });

  factory ArrowScore.fromJson(Map<String, dynamic> json) {
    final rawScore = json['score'];
    final scoreStr = (rawScore == 0 && json['is_x'] != true) ? 'M' : rawScore.toString();
    return ArrowScore(
      id: json['id'] as int?,
      endId: json['end_id'] as int?,
      arrowNumber: json['arrow_number'] as int,
      score: scoreStr,
      isX: json['is_x'] == true || json['is_x'] == 1,
      source: (json['source'] ?? 'manual') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'arrow_number': arrowNumber,
    'score': isX ? '10X' : score,
    'is_x': isX,
    'source': source,
  };
}

class ScoringEnd {
  final int id;
  final int sessionId;
  final int endNumber;
  final int totalScore;
  final int xCount;
  final List<ArrowScore> arrows;
  final String? createdAt;

  ScoringEnd({
    required this.id,
    required this.sessionId,
    required this.endNumber,
    required this.totalScore,
    required this.xCount,
    required this.arrows,
    this.createdAt,
  });

  factory ScoringEnd.fromJson(Map<String, dynamic> json) {
    final rawArrows = json['arrows'] as List<dynamic>? ?? [];
    return ScoringEnd(
      id: json['id'] as int,
      sessionId: json['session_id'] as int,
      endNumber: json['end_number'] as int,
      totalScore: json['total_score'] as int,
      xCount: json['x_count'] as int,
      arrows: rawArrows
          .map((a) => ArrowScore.fromJson(a as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'end_number': endNumber,
    'total_score': totalScore,
    'x_count': xCount,
    'arrows': arrows.map((a) => a.toJson()).toList(),
    if (createdAt != null) 'created_at': createdAt,
  };

  ScoringEnd copyWith({
    int? id,
    int? sessionId,
    int? endNumber,
    int? totalScore,
    int? xCount,
    List<ArrowScore>? arrows,
    String? createdAt,
  }) {
    return ScoringEnd(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      endNumber: endNumber ?? this.endNumber,
      totalScore: totalScore ?? this.totalScore,
      xCount: xCount ?? this.xCount,
      arrows: arrows ?? this.arrows,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

