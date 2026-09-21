class EndSummaryItem {
  final int endNumber;
  final int totalScore;
  final int xCount;
  final int arrowCount;
  final int cumulativeScore;

  EndSummaryItem({
    required this.endNumber,
    required this.totalScore,
    required this.xCount,
    required this.arrowCount,
    required this.cumulativeScore,
  });

  factory EndSummaryItem.fromJson(Map<String, dynamic> json) {
    return EndSummaryItem(
      endNumber: json['end_number'] as int,
      totalScore: json['total_score'] as int,
      xCount: json['x_count'] as int,
      arrowCount: json['arrow_count'] as int? ?? 0,
      cumulativeScore: json['cumulative_score'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'end_number': endNumber,
    'total_score': totalScore,
    'x_count': xCount,
    'arrow_count': arrowCount,
    'cumulative_score': cumulativeScore,
  };
}

class EndScoreHighlight {
  final int endNumber;
  final int score;

  EndScoreHighlight({required this.endNumber, required this.score});

  factory EndScoreHighlight.fromJson(Map<String, dynamic> json) {
    return EndScoreHighlight(
      endNumber: json['end_number'] as int,
      score: json['score'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'end_number': endNumber,
    'score': score,
  };
}

class SessionSummary {
  final int sessionId;
  final int totalScore;
  final int totalX;
  final int totalArrows;
  final int totalEnds;
  final double averageScorePerArrow;
  final double averageScorePerEnd;
  final EndScoreHighlight? highestScoringEnd;
  final EndScoreHighlight? lowestScoringEnd;
  final List<EndSummaryItem> endsSummary;

  SessionSummary({
    required this.sessionId,
    required this.totalScore,
    required this.totalX,
    required this.totalArrows,
    required this.totalEnds,
    required this.averageScorePerArrow,
    required this.averageScorePerEnd,
    this.highestScoringEnd,
    this.lowestScoringEnd,
    required this.endsSummary,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    final rawEnds = json['ends_summary'] as List<dynamic>? ?? [];
    return SessionSummary(
      sessionId: json['session_id'] as int? ?? 0,
      totalScore: json['total_score'] as int? ?? 0,
      totalX: json['total_x'] as int? ?? 0,
      totalArrows: json['total_arrows'] as int? ?? 0,
      totalEnds: json['total_ends'] as int? ?? 0,
      averageScorePerArrow:
          (json['average_score_per_arrow'] as num?)?.toDouble() ?? 0.0,
      averageScorePerEnd:
          (json['average_score_per_end'] as num?)?.toDouble() ?? 0.0,
      highestScoringEnd: json['highest_scoring_end'] != null
          ? EndScoreHighlight.fromJson(
              json['highest_scoring_end'] as Map<String, dynamic>)
          : null,
      lowestScoringEnd: json['lowest_scoring_end'] != null
          ? EndScoreHighlight.fromJson(
              json['lowest_scoring_end'] as Map<String, dynamic>)
          : null,
      endsSummary: rawEnds
          .map((e) => EndSummaryItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'total_score': totalScore,
    'total_x': totalX,
    'total_arrows': totalArrows,
    'total_ends': totalEnds,
    'average_score_per_arrow': averageScorePerArrow,
    'average_score_per_end': averageScorePerEnd,
    'highest_scoring_end': highestScoringEnd?.toJson(),
    'lowest_scoring_end': lowestScoringEnd?.toJson(),
    'ends_summary': endsSummary.map((e) => e.toJson()).toList(),
  };
}

