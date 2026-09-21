import '../models/end_score.dart';
import '../models/session_summary.dart';

class ParsedArrowScore {
  final int score;
  final bool isX;

  const ParsedArrowScore({required this.score, required this.isX});
}

class EndScoreCalculation {
  final int totalScore;
  final int xCount;
  final int arrowCount;
  final double averageScore;

  const EndScoreCalculation({
    required this.totalScore,
    required this.xCount,
    required this.arrowCount,
    required this.averageScore,
  });
}

/// Pure Dart implementation of World Archery scoring engine rules.
/// Ports logic directly from utils/scoring.py with 100% mathematical fidelity.
class OfflineScoringEngine {
  static const Set<String> validScores = {
    'X', '10X', '10', '9', '8', '7', '6', '5', '4', '3', '2', '1', 'M'
  };

  /// Parses an arrow score and returns [ParsedArrowScore].
  /// Allowed values:
  /// - 'X' or '10X': 10 points, isX: true
  /// - 'M': 0 points, isX: false
  /// - 0 to 10 (int or numeric String): points, isX according to flag
  static ParsedArrowScore parseArrowScore(dynamic scoreVal, {bool isX = false}) {
    if (scoreVal == null) {
      throw ArgumentError('Arrow score cannot be null');
    }

    if (scoreVal is String) {
      final normalized = scoreVal.trim().toUpperCase();
      if (normalized == 'X' || normalized == '10X') {
        return const ParsedArrowScore(score: 10, isX: true);
      }
      if (normalized == 'M') {
        return const ParsedArrowScore(score: 0, isX: false);
      }
      final num = int.tryParse(normalized);
      if (num != null) {
        if (num >= 0 && num <= 10) {
          return ParsedArrowScore(score: num, isX: (isX || (num == 10 && isX)));
        }
        throw ArgumentError('Numeric score out of range (0-10): $num');
      }
      throw ArgumentError("Invalid score value: '$scoreVal'. Allowed: X, 10, 9..1, M");
    }

    if (scoreVal is num) {
      final num = scoreVal.toInt();
      if (num >= 0 && num <= 10) {
        return ParsedArrowScore(score: num, isX: (isX && num == 10));
      }
      throw ArgumentError('Numeric score out of range (0-10): $num');
    }

    throw ArgumentError('Unsupported score type: ${scoreVal.runtimeType}');
  }

  /// Calculates statistics for a single end.
  static EndScoreCalculation calculateEndScore(List<ArrowScore> arrows) {
    if (arrows.isEmpty) {
      return const EndScoreCalculation(
        totalScore: 0,
        xCount: 0,
        arrowCount: 0,
        averageScore: 0.0,
      );
    }

    int totalScore = 0;
    int xCount = 0;

    for (final arrow in arrows) {
      if (arrow.score.trim().isEmpty) continue;
      final parsed = parseArrowScore(arrow.score, isX: arrow.isX);
      totalScore += parsed.score;
      if (parsed.isX) {
        xCount++;
      }
    }

    final arrowCount = arrows.length;
    final average = arrowCount > 0 ? (totalScore / arrowCount) : 0.0;
    final roundedAvg = double.parse(average.toStringAsFixed(2));

    return EndScoreCalculation(
      totalScore: totalScore,
      xCount: xCount,
      arrowCount: arrowCount,
      averageScore: roundedAvg,
    );
  }

  /// Calculates cumulative session statistics from a list of completed ends.
  static SessionSummary calculateSessionSummary(
    int sessionId,
    List<ScoringEnd> ends, {
    int totalEnds = 10,
  }) {
    int totalScore = 0;
    int totalX = 0;
    int totalArrows = 0;
    EndScoreHighlight? highestEnd;
    EndScoreHighlight? lowestEnd;
    final List<EndSummaryItem> endsSummary = [];

    // Sort ends by endNumber to ensure proper progression calculation
    final sortedEnds = List<ScoringEnd>.from(ends)
      ..sort((a, b) => a.endNumber.compareTo(b.endNumber));

    for (final end in sortedEnds) {
      final endNum = end.endNumber;
      final endScore = end.totalScore;
      final endX = end.xCount;
      final arrowCount = end.arrows.length;

      totalScore += endScore;
      totalX += endX;
      totalArrows += arrowCount;

      if (highestEnd == null || endScore > highestEnd.score) {
        highestEnd = EndScoreHighlight(endNumber: endNum, score: endScore);
      }
      if (lowestEnd == null || endScore < lowestEnd.score) {
        lowestEnd = EndScoreHighlight(endNumber: endNum, score: endScore);
      }

      endsSummary.add(
        EndSummaryItem(
          endNumber: endNum,
          totalScore: endScore,
          xCount: endX,
          arrowCount: arrowCount,
          cumulativeScore: totalScore,
        ),
      );
    }

    final endCount = sortedEnds.length;
    final avgPerArrow = totalArrows > 0 ? (totalScore / totalArrows) : 0.0;
    final avgPerEnd = endCount > 0 ? (totalScore / endCount) : 0.0;

    return SessionSummary(
      sessionId: sessionId,
      totalScore: totalScore,
      totalX: totalX,
      totalArrows: totalArrows,
      totalEnds: totalEnds,
      averageScorePerArrow: double.parse(avgPerArrow.toStringAsFixed(2)),
      averageScorePerEnd: double.parse(avgPerEnd.toStringAsFixed(2)),
      highestScoringEnd: highestEnd,
      lowestScoringEnd: lowestEnd,
      endsSummary: endsSummary,
    );
  }
}
