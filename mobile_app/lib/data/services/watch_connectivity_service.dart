import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/shot_event.dart';

class WatchStatus {
  final bool isSupported;
  final bool isPaired;
  final bool isAppInstalled;
  final bool isReachable;

  const WatchStatus({
    this.isSupported = false,
    this.isPaired = false,
    this.isAppInstalled = false,
    this.isReachable = false,
  });

  factory WatchStatus.fromMap(Map<dynamic, dynamic> map) {
    return WatchStatus(
      isSupported: map['is_supported'] == true,
      isPaired: map['is_paired'] == true,
      isAppInstalled: map['is_app_installed'] == true,
      isReachable: map['is_reachable'] == true,
    );
  }
}

class WatchConnectivityService {
  static const MethodChannel _methodChannel = MethodChannel('archery/watch_control');
  static const EventChannel _eventChannel = EventChannel('archery/watch_events');

  final StreamController<ShotEvent> _shotDetectedController = StreamController<ShotEvent>.broadcast();
  final StreamController<WatchStatus> _statusController = StreamController<WatchStatus>.broadcast();
  final StreamController<bool> _reachabilityController = StreamController<bool>.broadcast();

  Stream<ShotEvent> get onShotDetected => _shotDetectedController.stream;
  Stream<WatchStatus> get onStatusChanged => _statusController.stream;
  Stream<bool> get onReachabilityChanged => _reachabilityController.stream;

  WatchStatus _currentStatus = const WatchStatus();
  WatchStatus get currentStatus => _currentStatus;

  bool _isInitialized = false;
  StreamSubscription? _eventSubscription;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Platform channels are active on iOS; graceful fallback on Android
    if (!Platform.isIOS) {
      _currentStatus = const WatchStatus(isSupported: false);
      return;
    }

    try {
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleIncomingEvent,
        onError: (err) {
          // Log without crashing
        },
      );

      _currentStatus = await getWatchStatus();
      _statusController.add(_currentStatus);
    } catch (_) {
      // Fallback if platform bridge is not registered
    }
  }

  void _handleIncomingEvent(dynamic rawEvent) {
    if (rawEvent is! Map) return;

    final eventType = rawEvent['event'] as String?;
    final data = rawEvent['data'];

    if (eventType == 'shot_detected' && data is Map) {
      final shot = ShotEvent.fromJson(Map<String, dynamic>.from(data));
      _shotDetectedController.add(shot);
    } else if (eventType == 'watch_status_changed' && data is Map) {
      _currentStatus = WatchStatus.fromMap(data);
      _statusController.add(_currentStatus);
    } else if (eventType == 'watch_reachability_changed' && data is Map) {
      final reachable = data['is_reachable'] == true;
      _currentStatus = WatchStatus(
        isSupported: _currentStatus.isSupported,
        isPaired: _currentStatus.isPaired,
        isAppInstalled: _currentStatus.isAppInstalled,
        isReachable: reachable,
      );
      _reachabilityController.add(reachable);
      _statusController.add(_currentStatus);
    }
  }

  Future<WatchStatus> getWatchStatus() async {
    if (!Platform.isIOS) return const WatchStatus(isSupported: false);
    try {
      final res = await _methodChannel.invokeMethod('getWatchStatus');
      if (res is Map) {
        _currentStatus = WatchStatus.fromMap(res);
        return _currentStatus;
      }
    } catch (_) {}
    return const WatchStatus();
  }

  Future<bool> startWatchSession({
    required int sessionId,
    String? athleteName,
    int currentEnd = 1,
  }) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _methodChannel.invokeMethod('startWatchSession', {
        'session_id': sessionId,
        'athlete_name': athleteName,
        'current_end': currentEnd,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> endWatchSession() async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _methodChannel.invokeMethod('endWatchSession');
      return res == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateSessionState({required int currentEnd}) async {
    if (!Platform.isIOS) return false;
    try {
      final res = await _methodChannel.invokeMethod('updateSessionState', {
        'current_end': currentEnd,
      });
      return res == true;
    } catch (_) {
      return false;
    }
  }

  /// Inject or simulate a candidate shot event (useful for desk/simulator testing)
  Future<ShotEvent?> simulateShot({
    int sessionId = 1,
    double confidence = 0.92,
    double peakAcceleration = 4.8,
    int drawDurationMs = 3200,
  }) async {
    if (Platform.isIOS) {
      try {
        final res = await _methodChannel.invokeMethod('simulateShot', {
          'session_id': sessionId,
          'confidence': confidence,
          'peak_acceleration': peakAcceleration,
          'draw_duration_ms': drawDurationMs,
        });
        if (res is Map) {
          final shot = ShotEvent.fromJson(Map<String, dynamic>.from(res));
          _shotDetectedController.add(shot);
          return shot;
        }
      } catch (_) {}
    }

    // Pure Dart local fallback simulation
    final localShot = ShotEvent(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      timestamp: DateTime.now(),
      confidence: confidence,
      peakAcceleration: peakAcceleration,
      drawDurationMs: drawDurationMs,
      isManual: false,
    );
    _shotDetectedController.add(localShot);
    return localShot;
  }

  void dispose() {
    _eventSubscription?.cancel();
    _shotDetectedController.close();
    _statusController.close();
    _reachabilityController.close();
  }
}
