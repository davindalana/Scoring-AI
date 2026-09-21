import 'package:test/test.dart';
import 'package:mobile_app/data/models/end_score.dart';
import 'package:mobile_app/data/models/session.dart';
import 'package:mobile_app/data/services/offline_scoring_engine.dart';

void main() {
  group('OfflineScoringEngine - parseArrowScore', () {
    test('parses X scores correctly', () {
      final x1 = OfflineScoringEngine.parseArrowScore('X');
      expect(x1.score, 10);
      expect(x1.isX, true);

      final x2 = OfflineScoringEngine.parseArrowScore('10X');
      expect(x2.score, 10);
      expect(x2.isX, true);

      final x3 = OfflineScoringEngine.parseArrowScore('x');
      expect(x3.score, 10);
      expect(x3.isX, true);
    });

    test('parses M (Miss) scores correctly', () {
      final m1 = OfflineScoringEngine.parseArrowScore('M');
      expect(m1.score, 0);
      expect(m1.isX, false);

      final m2 = OfflineScoringEngine.parseArrowScore('m');
      expect(m2.score, 0);
      expect(m2.isX, false);
    });

    test('parses numeric 0-10 correctly', () {
      final s10 = OfflineScoringEngine.parseArrowScore('10');
      expect(s10.score, 10);
      expect(s10.isX, false);

      final s10x = OfflineScoringEngine.parseArrowScore(10, isX: true);
      expect(s10x.score, 10);
      expect(s10x.isX, true);

      for (int i = 1; i <= 9; i++) {
        final parsedStr = OfflineScoringEngine.parseArrowScore('$i');
        expect(parsedStr.score, i);
        expect(parsedStr.isX, false);

        final parsedNum = OfflineScoringEngine.parseArrowScore(i);
        expect(parsedNum.score, i);
        expect(parsedNum.isX, false);
      }
    });

    test('throws ArgumentError on invalid score inputs', () {
      expect(() => OfflineScoringEngine.parseArrowScore('11'), throwsA(isA<ArgumentError>()));
      expect(() => OfflineScoringEngine.parseArrowScore('-1'), throwsA(isA<ArgumentError>()));
      expect(() => OfflineScoringEngine.parseArrowScore('INVALID'), throwsA(isA<ArgumentError>()));
      expect(() => OfflineScoringEngine.parseArrowScore(null), throwsA(isA<ArgumentError>()));
    });
  });

  group('OfflineScoringEngine - calculateEndScore', () {
    test('calculates end score accurately according to WA specification', () {
      // 10X, 10, 9, 8, 7, M -> Total = 44, X = 1, average = 7.33
      final arrows = [
        ArrowScore(arrowNumber: 1, score: '10X', isX: true),
        ArrowScore(arrowNumber: 2, score: '10', isX: false),
        ArrowScore(arrowNumber: 3, score: '9', isX: false),
        ArrowScore(arrowNumber: 4, score: '8', isX: false),
        ArrowScore(arrowNumber: 5, score: '7', isX: false),
        ArrowScore(arrowNumber: 6, score: 'M', isX: false),
      ];

      final result = OfflineScoringEngine.calculateEndScore(arrows);
      expect(result.totalScore, 44);
      expect(result.xCount, 1);
      expect(result.arrowCount, 6);
      expect(result.averageScore, 7.33);
    });

    test('handles empty arrows gracefully', () {
      final result = OfflineScoringEngine.calculateEndScore([]);
      expect(result.totalScore, 0);
      expect(result.xCount, 0);
      expect(result.arrowCount, 0);
      expect(result.averageScore, 0.0);
    });
  });

  group('OfflineScoringEngine - calculateSessionSummary', () {
    test('calculates cumulative session summary with highlights and progression', () {
      final ends = [
        ScoringEnd(
          id: -1,
          sessionId: -100,
          endNumber: 1,
          totalScore: 53,
          xCount: 1,
          arrows: [
            ArrowScore(arrowNumber: 1, score: '10X', isX: true),
            ArrowScore(arrowNumber: 2, score: '10'),
            ArrowScore(arrowNumber: 3, score: '9'),
            ArrowScore(arrowNumber: 4, score: '9'),
            ArrowScore(arrowNumber: 5, score: '8'),
            ArrowScore(arrowNumber: 6, score: '7'),
          ],
        ),
        ScoringEnd(
          id: -2,
          sessionId: -100,
          endNumber: 2,
          totalScore: 47,
          xCount: 2,
          arrows: [
            ArrowScore(arrowNumber: 1, score: '10X', isX: true),
            ArrowScore(arrowNumber: 2, score: '10X', isX: true),
            ArrowScore(arrowNumber: 3, score: '8'),
            ArrowScore(arrowNumber: 4, score: '8'),
            ArrowScore(arrowNumber: 5, score: '6'),
            ArrowScore(arrowNumber: 6, score: '5'),
          ],
        ),
      ];

      final summary = OfflineScoringEngine.calculateSessionSummary(-100, ends, totalEnds: 10);

      expect(summary.sessionId, -100);
      expect(summary.totalScore, 100);
      expect(summary.totalX, 3);
      expect(summary.totalArrows, 12);
      expect(summary.totalEnds, 10);
      expect(summary.averageScorePerArrow, 8.33);
      expect(summary.averageScorePerEnd, 50.0);
      expect(summary.highestScoringEnd?.endNumber, 1);
      expect(summary.highestScoringEnd?.score, 53);
      expect(summary.lowestScoringEnd?.endNumber, 2);
      expect(summary.lowestScoringEnd?.score, 47);
      expect(summary.endsSummary.length, 2);
      expect(summary.endsSummary[0].cumulativeScore, 53);
      expect(summary.endsSummary[1].cumulativeScore, 100);
    });
  });

  group('JSON Serialization Roundtrips', () {
    test('ScoringSession serialization and copyWith', () {
      final session = ScoringSession(
        id: -99,
        athleteId: 1,
        athleteName: 'Arjuna',
        bowCategory: 'Recurve',
        sessionType: 'training',
        distance: '70m',
        arrowsPerEnd: 6,
        totalEnds: 10,
        currentEnd: 1,
        status: 'in_progress',
        startedAt: '2026-09-22T05:00:00Z',
      );

      final json = session.toJson();
      final restored = ScoringSession.fromJson(json);

      expect(restored.id, -99);
      expect(restored.athleteName, 'Arjuna');
      expect(restored.bowCategory, 'Recurve');
      expect(restored.status, 'in_progress');

      final completed = restored.copyWith(status: 'completed', currentEnd: 10);
      expect(completed.status, 'completed');
      expect(completed.currentEnd, 10);
      expect(completed.isCompleted, true);
    });

    test('ScoringEnd serialization', () {
      final end = ScoringEnd(
        id: -1,
        sessionId: -99,
        endNumber: 1,
        totalScore: 50,
        xCount: 2,
        arrows: [
          ArrowScore(arrowNumber: 1, score: '10X', isX: true),
          ArrowScore(arrowNumber: 2, score: '9'),
        ],
      );

      final json = end.toJson();
      final restored = ScoringEnd.fromJson(json);

      expect(restored.id, -1);
      expect(restored.totalScore, 50);
      expect(restored.arrows.length, 2);
      expect(restored.arrows.first.isX, true);
    });
  });
}
