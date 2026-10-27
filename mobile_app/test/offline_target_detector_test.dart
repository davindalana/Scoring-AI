import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/data/services/offline_target_detector.dart';

void main() {
  group('OfflineTargetDetector Tests', () {
    test('calculateScoreFromDistanceRatio correctly classifies World Archery rings', () {
      // 10X (inner 5%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.02), (score: '10X', isX: true));
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.05), (score: '10X', isX: true));

      // 10 (5% to 10%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.08), (score: '10', isX: false));
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.10), (score: '10', isX: false));

      // 9 (10% to 20%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.15), (score: '9', isX: false));

      // 8 (20% to 30%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.25), (score: '8', isX: false));

      // 7 (30% to 40%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.35), (score: '7', isX: false));

      // 6 (40% to 50%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.45), (score: '6', isX: false));

      // 5 (50% to 60%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.55), (score: '5', isX: false));

      // 4 (60% to 70%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.65), (score: '4', isX: false));

      // 3 (70% to 80%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.75), (score: '3', isX: false));

      // 2 (80% to 90%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.85), (score: '2', isX: false));

      // 1 (90% to 100%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(0.95), (score: '1', isX: false));

      // Miss (> 100%)
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(1.05), (score: 'M', isX: false));
      expect(OfflineTargetDetector.calculateScoreFromDistanceRatio(2.50), (score: 'M', isX: false));
    });

    test('detectFromBytes successfully detects target and outputs valid arrows', () {
      // Create a 200x200 synthetic image with a yellow bullseye center
      final image = img.Image(width: 200, height: 200);
      img.fill(image, color: img.ColorRgb8(240, 240, 240)); // light background

      // Draw yellow center (10/9 ring zone)
      img.fillCircle(
        image,
        x: 100,
        y: 100,
        radius: 20,
        color: img.ColorRgb8(255, 215, 0), // Gold yellow
      );

      final pngBytes = img.encodePng(image);

      final result = OfflineTargetDetector.detectFromBytes(pngBytes, expectedArrowCount: 3);

      expect(result.targetDetected, isTrue);
      expect(result.centerX, closeTo(100, 5));
      expect(result.centerY, closeTo(100, 5));
      expect(result.targetRadius, greaterThan(30));
      expect(result.detectedArrows.length, equals(3));
      expect(result.detectionMode, equals('on_device_offline'));

      for (final arrow in result.detectedArrows) {
        expect(arrow.arrowNumber, inInclusiveRange(1, 3));
        expect(arrow.score, isNotEmpty);
        expect(arrow.angleDeg, isNotNull);
      }
    });
  });
}
