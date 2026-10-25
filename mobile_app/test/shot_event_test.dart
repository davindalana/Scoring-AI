import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/data/models/shot_event.dart';
import 'package:mobile_app/data/services/api_service.dart';
import 'package:mobile_app/data/services/local_storage_service.dart';
import 'package:mobile_app/data/services/watch_connectivity_service.dart';
import 'package:mobile_app/providers/scoring_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShotEvent Model Tests', () {
    test('JSON serialization & deserialization round-trip', () {
      final now = DateTime.now();
      final shot = ShotEvent(
        id: 'shot_101',
        sessionId: 42,
        timestamp: now,
        confidence: 0.95,
        peakAcceleration: 5.4,
        drawDurationMs: 3200,
        matchedEndNumber: 1,
        matchedArrowNumber: 2,
        isManual: false,
        status: 'matched',
      );

      final json = shot.toJson();
      expect(json['id'], 'shot_101');
      expect(json['session_id'], 42);
      expect(json['confidence'], 0.95);
      expect(json['peak_acceleration'], 5.4);
      expect(json['draw_duration_ms'], 3200);
      expect(json['matched_end'], 1);
      expect(json['matched_arrow'], 2);
      expect(json['status'], 'matched');

      final deserialized = ShotEvent.fromJson(json);
      expect(deserialized.id, shot.id);
      expect(deserialized.sessionId, shot.sessionId);
      expect(deserialized.confidence, shot.confidence);
      expect(deserialized.peakAcceleration, shot.peakAcceleration);
      expect(deserialized.drawDurationMs, shot.drawDurationMs);
      expect(deserialized.matchedEndNumber, shot.matchedEndNumber);
      expect(deserialized.matchedArrowNumber, shot.matchedArrowNumber);
      expect(deserialized.isMatched, isTrue);
      expect(deserialized.isIgnored, isFalse);
    });

    test('copyWith works correctly', () {
      final shot = ShotEvent(
        id: 'shot_1',
        sessionId: 10,
        timestamp: DateTime.now(),
        confidence: 0.8,
        peakAcceleration: 4.0,
        drawDurationMs: 2500,
        status: 'unmatched',
      );

      final updated = shot.copyWith(
        matchedEndNumber: 2,
        matchedArrowNumber: 1,
        status: 'matched',
      );

      expect(updated.id, 'shot_1');
      expect(updated.matchedEndNumber, 2);
      expect(updated.matchedArrowNumber, 1);
      expect(updated.status, 'matched');
      expect(updated.isMatched, isTrue);
    });
  });

  group('LocalStorageService Shot Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saves, retrieves, and updates session shot events', () async {
      final storage = LocalStorageService();
      await storage.init();

      final shot1 = ShotEvent(
        id: 's1',
        sessionId: 99,
        timestamp: DateTime.now(),
        confidence: 0.9,
        peakAcceleration: 4.5,
        drawDurationMs: 3000,
      );

      final shot2 = ShotEvent(
        id: 's2',
        sessionId: 99,
        timestamp: DateTime.now().add(const Duration(seconds: 15)),
        confidence: 0.85,
        peakAcceleration: 5.1,
        drawDurationMs: 3400,
      );

      await storage.saveSessionShots(99, [shot1, shot2]);

      final loaded = await storage.getSessionShots(99);
      expect(loaded.length, 2);
      expect(loaded[0].id, 's1');
      expect(loaded[1].id, 's2');

      // Add a third shot
      final shot3 = ShotEvent(
        id: 's3',
        sessionId: 99,
        timestamp: DateTime.now().add(const Duration(seconds: 30)),
        confidence: 1.0,
        peakAcceleration: 0.0,
        drawDurationMs: 3000,
        isManual: true,
      );
      await storage.addSessionShot(99, shot3);

      final loadedUpdated = await storage.getSessionShots(99);
      expect(loadedUpdated.length, 3);
      expect(loadedUpdated.last.isManual, isTrue);

      // Update shot1 match
      final updatedShot1 = shot1.copyWith(matchedEndNumber: 1, matchedArrowNumber: 1, status: 'matched');
      await storage.updateShotEvent(99, updatedShot1);

      final finalLoaded = await storage.getSessionShots(99);
      expect(finalLoaded.first.matchedArrowNumber, 1);
      expect(finalLoaded.first.isMatched, isTrue);
    });
  });

  group('ScoringProvider Shot Matching & Telemetry Tests', () {
    late LocalStorageService storage;
    late ApiService api;
    late WatchConnectivityService watchService;
    late ScoringProvider provider;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      storage = LocalStorageService();
      await storage.init();
      await storage.setOfflineForced(true);

      api = ApiService();
      watchService = WatchConnectivityService();

      provider = ScoringProvider(
        apiService: api,
        localStorageService: storage,
        watchService: watchService,
      );
      await provider.init();
    });

    test('manual linking, unlinking, and ignoring shots', () async {
      // Create session
      await provider.createSession(
        athleteId: 1,
        bowCategory: 'Recurve',
        sessionType: 'training',
        distance: '18m',
        arrowsPerEnd: 3,
        totalEnds: 2,
      );

      final session = provider.currentSession;
      expect(session, isNotNull);

      // Inject simulated shot
      final shot = await provider.simulateShot(
        confidence: 0.95,
        peakAcceleration: 5.2,
        drawDurationMs: 3300,
      );
      expect(shot, isNotNull);
      expect(provider.sessionShots.length, 1);

      // Verify shot was auto-linked to slot 1
      final slot1Shot = provider.getShotForArrow(1, 1);
      expect(slot1Shot, isNotNull);
      expect(slot1Shot!.id, shot!.id);

      // Manually unlink shot
      await provider.unlinkShot(shot.id);
      expect(provider.getShotForArrow(1, 1), isNull);
      expect(provider.getUnmatchedShots().length, 1);

      // Manually relink to slot 3
      await provider.linkShotToArrow(shot.id, 1, 3);
      expect(provider.getShotForArrow(1, 3)?.id, shot.id);

      // Ignore shot (mark as false positive)
      await provider.ignoreShot(shot.id);
      expect(provider.getShotForArrow(1, 3), isNull);
      expect(provider.sessionShots.first.isIgnored, isTrue);
    });

    test('autoAlignShotsForEnd sequentially matches shots to arrows', () async {
      await provider.createSession(
        athleteId: 1,
        bowCategory: 'Recurve',
        sessionType: 'training',
        distance: '18m',
        arrowsPerEnd: 3,
        totalEnds: 1,
      );

      final now = DateTime.now();
      // Add 3 unassigned shots in time order
      final s1 = ShotEvent(id: 's1', sessionId: provider.currentSession!.id, timestamp: now, confidence: 0.9, peakAcceleration: 4.0, drawDurationMs: 3000);
      final s2 = ShotEvent(id: 's2', sessionId: provider.currentSession!.id, timestamp: now.add(const Duration(seconds: 10)), confidence: 0.9, peakAcceleration: 4.2, drawDurationMs: 3100);
      final s3 = ShotEvent(id: 's3', sessionId: provider.currentSession!.id, timestamp: now.add(const Duration(seconds: 20)), confidence: 0.9, peakAcceleration: 4.5, drawDurationMs: 2900);

      await storage.saveSessionShots(provider.currentSession!.id, [s1, s2, s3]);
      await provider.openSession(provider.currentSession!.id);

      // Auto align end 1
      await provider.autoAlignShotsForEnd(1);

      expect(provider.getShotForArrow(1, 1)?.id, 's1');
      expect(provider.getShotForArrow(1, 2)?.id, 's2');
      expect(provider.getShotForArrow(1, 3)?.id, 's3');
    });
  });
}
