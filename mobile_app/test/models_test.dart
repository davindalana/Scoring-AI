import 'package:test/test.dart';
import 'package:mobile_app/data/models/athlete.dart';
import 'package:mobile_app/data/models/end_score.dart';
import 'package:mobile_app/data/models/session.dart';
import 'package:mobile_app/data/models/session_summary.dart';

void main() {
  test('Athlete model serialization', () {
    final athlete = Athlete.fromJson({
      'id': 1,
      'name': 'Arjuna Pratama',
      'athlete_code': 'INA-01',
    });
    expect(athlete.id, 1);
    expect(athlete.name, 'Arjuna Pratama');
    expect(athlete.athleteCode, 'INA-01');

    final json = athlete.toJson();
    expect(json['name'], 'Arjuna Pratama');
    expect(json['athlete_code'], 'INA-01');
  });

  test('ArrowScore model parsing', () {
    final arrowX = ArrowScore.fromJson({
      'arrow_number': 1,
      'score': 10,
      'is_x': true,
      'source': 'ai',
    });
    expect(arrowX.arrowNumber, 1);
    expect(arrowX.isX, true);
    expect(arrowX.source, 'ai');

    final arrowM = ArrowScore.fromJson({
      'arrow_number': 2,
      'score': 0,
      'is_x': false,
      'source': 'manual',
    });
    expect(arrowM.score, 'M');
    expect(arrowM.isX, false);
  });

  test('ScoringSession model properties', () {
    final session = ScoringSession.fromJson({
      'id': 42,
      'athlete_id': 1,
      'athlete_name': 'Arjuna Pratama',
      'bow_category': 'Recurve',
      'session_type': 'training',
      'distance': '70m',
      'arrows_per_end': 6,
      'total_ends': 10,
      'current_end': 2,
      'status': 'in_progress',
    });
    expect(session.id, 42);
    expect(session.athleteName, 'Arjuna Pratama');
    expect(session.bowCategory, 'Recurve');
    expect(session.isCompleted, false);
  });

  test('SessionSummary calculation deserialization', () {
    final summary = SessionSummary.fromJson({
      'session_id': 42,
      'total_score': 100,
      'total_x': 3,
      'total_arrows': 12,
      'total_ends': 2,
      'average_score_per_arrow': 8.33,
      'average_score_per_end': 50.0,
      'highest_scoring_end': {'end_number': 1, 'score': 53},
      'lowest_scoring_end': {'end_number': 2, 'score': 47},
      'ends_summary': [
        {
          'end_number': 1,
          'total_score': 53,
          'x_count': 1,
          'arrow_count': 6,
          'cumulative_score': 53,
        },
        {
          'end_number': 2,
          'total_score': 47,
          'x_count': 2,
          'arrow_count': 6,
          'cumulative_score': 100,
        },
      ],
    });

    expect(summary.totalScore, 100);
    expect(summary.totalX, 3);
    expect(summary.highestScoringEnd?.score, 53);
    expect(summary.lowestScoringEnd?.score, 47);
    expect(summary.endsSummary.length, 2);
    expect(summary.endsSummary[1].cumulativeScore, 100);
  });
}
