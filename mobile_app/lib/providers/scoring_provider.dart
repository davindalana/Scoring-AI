import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/athlete.dart';
import '../data/models/session.dart';
import '../data/models/end_score.dart';
import '../data/models/session_summary.dart';
import '../data/models/shot_event.dart';
import '../data/services/api_service.dart';
import '../data/services/local_storage_service.dart';
import '../data/services/offline_scoring_engine.dart';
import '../data/services/offline_target_detector.dart';
import '../data/services/watch_connectivity_service.dart';

class ScoringProvider extends ChangeNotifier {
  final ApiService apiService;
  final LocalStorageService localStorageService;
  final WatchConnectivityService watchService;

  ScoringProvider({
    required this.apiService,
    LocalStorageService? localStorageService,
    WatchConnectivityService? watchService,
  })  : localStorageService = localStorageService ?? LocalStorageService(),
        watchService = watchService ?? WatchConnectivityService();

  WatchStatus _watchStatus = const WatchStatus();
  WatchStatus get watchStatus => _watchStatus;

  List<ShotEvent> _sessionShots = [];
  List<ShotEvent> get sessionShots => _sessionShots;

  StreamSubscription? _shotSubscription;
  StreamSubscription? _watchStatusSubscription;

  List<Athlete> _athletes = [];
  List<Athlete> get athletes => _athletes;

  Athlete? _selectedAthlete;
  Athlete? get selectedAthlete => _selectedAthlete;

  List<ScoringSession> _sessions = [];
  List<ScoringSession> get sessions => _sessions;

  ScoringSession? _currentSession;
  ScoringSession? get currentSession => _currentSession;

  Athlete? _currentSessionAthlete;
  Athlete? get currentSessionAthlete => _currentSessionAthlete;

  SessionSummary? _currentSessionSummary;
  SessionSummary? get currentSessionSummary => _currentSessionSummary;

  List<ScoringEnd> _completedEnds = [];
  List<ScoringEnd> get completedEnds => _completedEnds;

  // Active End State
  int _currentEndNumber = 1;
  int get currentEndNumber => _currentEndNumber;

  List<ArrowScore> _currentEndArrows = [];
  List<ArrowScore> get currentEndArrows => _currentEndArrows;

  int _activeSlotIndex = 0;
  int get activeSlotIndex => _activeSlotIndex;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Offline Mode State
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  void setActiveSlotIndex(int index) {
    if (index >= 0 && index < _currentEndArrows.length) {
      _activeSlotIndex = index;
      notifyListeners();
    }
  }

  void setSelectedAthlete(Athlete? athlete) {
    _selectedAthlete = athlete;
    notifyListeners();
  }

  /// Toggle or set manual offline mode
  Future<void> toggleOfflineMode([bool? forceState]) async {
    final newState = forceState ?? !_isOfflineMode;
    _isOfflineMode = newState;
    await localStorageService.setOfflineForced(newState);
    _errorMessage = null;
    await loadAthletes();
    await loadSessions();
    notifyListeners();
  }

  // Load Initial Data
  Future<void> init() async {
    await localStorageService.init();
    await apiService.init();
    await watchService.init();

    _watchStatus = watchService.currentStatus;
    _watchStatusSubscription = watchService.onStatusChanged.listen((status) {
      _watchStatus = status;
      notifyListeners();
    });

    _shotSubscription = watchService.onShotDetected.listen(_handleIncomingShot);

    _isOfflineMode = localStorageService.isOfflineForced;

    await loadAthletes();
    await loadSessions();
  }

  void _handleIncomingShot(ShotEvent shot) async {
    if (_currentSession == null) return;
    
    // Auto-match with current active slot if unassigned
    final slotNumber = _activeSlotIndex + 1;
    final slotAlreadyMatched = _sessionShots.any(
      (s) => s.matchedEndNumber == _currentEndNumber && s.matchedArrowNumber == slotNumber && !s.isIgnored,
    );

    ShotEvent processedShot = shot.copyWith(sessionId: _currentSession!.id);
    if (!slotAlreadyMatched && _activeSlotIndex < _currentEndArrows.length) {
      processedShot = processedShot.copyWith(
        matchedEndNumber: _currentEndNumber,
        matchedArrowNumber: slotNumber,
        status: 'matched',
      );
    }

    _sessionShots.add(processedShot);
    await localStorageService.addSessionShot(_currentSession!.id, processedShot);
    notifyListeners();
  }

  @override
  void dispose() {
    _shotSubscription?.cancel();
    _watchStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> loadAthletes() async {
    _errorMessage = null;
    if (_isOfflineMode) {
      _athletes = await localStorageService.getAthletes();
      if (_athletes.isNotEmpty && _selectedAthlete == null) {
        _selectedAthlete = _athletes.first;
      }
      notifyListeners();
      return;
    }

    try {
      _athletes = await apiService.getAthletes();
      // Cache to local storage for offline use
      if (_athletes.isNotEmpty) {
        await localStorageService.saveAthletes(_athletes);
      }
      if (_athletes.isNotEmpty && _selectedAthlete == null) {
        _selectedAthlete = _athletes.first;
      }
      notifyListeners();
    } catch (e) {
      // Automatic fallback to offline cache
      _isOfflineMode = true;
      _athletes = await localStorageService.getAthletes();
      if (_athletes.isNotEmpty && _selectedAthlete == null) {
        _selectedAthlete = _athletes.first;
      }
      _errorMessage = 'Server unreachable. Switched to Offline Mode.';
      notifyListeners();
    }
  }

  Future<Athlete> updateAthleteProfile(String name, String? code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final current = _selectedAthlete ?? Athlete(id: -1, name: 'Athlete');
      final updated = Athlete(
        id: current.id,
        name: name,
        athleteCode: code,
        createdAt: current.createdAt,
      );
      _selectedAthlete = updated;
      _athletes = [updated];
      await localStorageService.saveAthletes([updated]);
      notifyListeners();
      return updated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Athlete> addAthlete(String name, String? code) async {
    return await updateAthleteProfile(name, code);
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_isOfflineMode) {
        _sessions = await localStorageService.getSessions();
        return;
      }

      try {
        final remoteSessions = await apiService.getSessions();
        final localSessions = await localStorageService.getSessions();

        // Merge: keep local offline sessions (negative IDs) and server sessions
        final offlineOnly = localSessions.where((s) => s.id < 0).toList();
        _sessions = [...offlineOnly, ...remoteSessions];
        // Cache server sessions locally as well
        await localStorageService.saveSessions(_sessions);
      } catch (e) {
        _isOfflineMode = true;
        _sessions = await localStorageService.getSessions();
        _errorMessage = 'Server unreachable. Loaded local sessions.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ScoringSession> createSession({
    required int athleteId,
    required String bowCategory,
    required String sessionType,
    required String distance,
    required int arrowsPerEnd,
    required int totalEnds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_isOfflineMode) {
        return await _createOfflineSession(
          athleteId: athleteId,
          bowCategory: bowCategory,
          sessionType: sessionType,
          distance: distance,
          arrowsPerEnd: arrowsPerEnd,
          totalEnds: totalEnds,
        );
      }

      try {
        final session = await apiService.createSession(
          athleteId: athleteId,
          bowCategory: bowCategory,
          sessionType: sessionType,
          distance: distance,
          arrowsPerEnd: arrowsPerEnd,
          totalEnds: totalEnds,
        );
        await openSession(session.id);
        await loadSessions();
        return session;
      } catch (e) {
        // Server failed, create locally
        _isOfflineMode = true;
        return await _createOfflineSession(
          athleteId: athleteId,
          bowCategory: bowCategory,
          sessionType: sessionType,
          distance: distance,
          arrowsPerEnd: arrowsPerEnd,
          totalEnds: totalEnds,
        );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ScoringSession> _createOfflineSession({
    required int athleteId,
    required String bowCategory,
    required String sessionType,
    required String distance,
    required int arrowsPerEnd,
    required int totalEnds,
  }) async {
    // Negative timestamp ID for offline sessions
    final localSessionId = -1 * (DateTime.now().millisecondsSinceEpoch);
    final athlete = _athletes.firstWhere(
      (a) => a.id == athleteId,
      orElse: () => _selectedAthlete ?? Athlete(id: athleteId, name: 'Athlete'),
    );

    final session = ScoringSession(
      id: localSessionId,
      athleteId: athleteId,
      athleteName: athlete.name,
      athleteCode: athlete.athleteCode,
      bowCategory: bowCategory,
      sessionType: sessionType,
      distance: distance,
      arrowsPerEnd: arrowsPerEnd,
      totalEnds: totalEnds,
      currentEnd: 1,
      status: 'in_progress',
      startedAt: DateTime.now().toIso8601String(),
    );

    await localStorageService.saveSession(session);
    await openSession(session.id);
    await loadSessions();
    return session;
  }

  Future<void> openSession(int sessionId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_isOfflineMode || sessionId < 0) {
        await _openOfflineSession(sessionId);
        return;
      }

      try {
        final details = await apiService.getSessionDetails(sessionId);
        _currentSession = details['session'] as ScoringSession;
        _currentSessionAthlete = details['athlete'] as Athlete?;
        _currentSessionSummary = details['summary'] as SessionSummary;
        _completedEnds = details['ends'] as List<ScoringEnd>;

        _currentEndNumber = _currentSession!.currentEnd;
        _initEndSlots(_currentSession!.arrowsPerEnd);

        // Load shot events & notify watch
        _sessionShots = await localStorageService.getSessionShots(sessionId);
        await watchService.startWatchSession(
          sessionId: sessionId,
          athleteName: _currentSessionAthlete?.name ?? _currentSession?.athleteName,
          currentEnd: _currentEndNumber,
        );

        // Backup to local storage
        await localStorageService.saveSession(_currentSession!);
        await localStorageService.saveSessionEnds(sessionId, _completedEnds);
        await localStorageService.saveSessionSummary(sessionId, _currentSessionSummary!);
      } catch (e) {
        // Fallback to local storage if available
        await _openOfflineSession(sessionId);
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _openOfflineSession(int sessionId) async {
    final session = await localStorageService.getSessionById(sessionId);
    if (session == null) {
      throw Exception('Session $sessionId not found in local storage');
    }
    _currentSession = session;

    _currentSessionAthlete = _athletes.firstWhere(
      (a) => a.id == session.athleteId,
      orElse: () => Athlete(
        id: session.athleteId,
        name: session.athleteName ?? 'Athlete',
        athleteCode: session.athleteCode,
      ),
    );

    _completedEnds = await localStorageService.getSessionEnds(sessionId);

    // Calculate or retrieve summary
    final savedSummary = await localStorageService.getSessionSummary(sessionId);
    if (savedSummary != null) {
      _currentSessionSummary = savedSummary;
    } else {
      _currentSessionSummary = OfflineScoringEngine.calculateSessionSummary(
        sessionId,
        _completedEnds,
        totalEnds: session.totalEnds,
      );
      await localStorageService.saveSessionSummary(sessionId, _currentSessionSummary!);
    }

    _currentEndNumber = _currentSession!.currentEnd;
    _initEndSlots(_currentSession!.arrowsPerEnd);

    // Load shot events & notify watch
    _sessionShots = await localStorageService.getSessionShots(sessionId);
    await watchService.startWatchSession(
      sessionId: sessionId,
      athleteName: _currentSessionAthlete?.name ?? _currentSession?.athleteName,
      currentEnd: _currentEndNumber,
    );
  }

  void _initEndSlots(int arrowsCount) {
    _currentEndArrows = List.generate(
      arrowsCount,
      (i) => ArrowScore(
        arrowNumber: i + 1,
        score: '',
        isX: false,
        source: 'manual',
      ),
    );
    _activeSlotIndex = 0;
  }

  // Scoring Keypad Logic
  void enterScore(String scoreVal) {
    if (_activeSlotIndex >= _currentEndArrows.length) return;

    final norm = scoreVal.trim().toUpperCase();
    final isX = norm == 'X' || norm == '10X';
    final cleanScore = isX ? '10X' : (norm == 'M' ? 'M' : norm);

    _currentEndArrows[_activeSlotIndex] = ArrowScore(
      arrowNumber: _activeSlotIndex + 1,
      score: cleanScore,
      isX: isX,
      source: 'manual',
    );

    // Auto advance to next slot
    if (_activeSlotIndex < _currentEndArrows.length - 1) {
      _activeSlotIndex++;
    }
    notifyListeners();
  }

  void undoScore() {
    if (_currentEndArrows.isEmpty) return;

    if (_currentEndArrows[_activeSlotIndex].score.isNotEmpty) {
      _currentEndArrows[_activeSlotIndex] = ArrowScore(
        arrowNumber: _activeSlotIndex + 1,
        score: '',
        isX: false,
      );
    } else if (_activeSlotIndex > 0) {
      _activeSlotIndex--;
      _currentEndArrows[_activeSlotIndex] = ArrowScore(
        arrowNumber: _activeSlotIndex + 1,
        score: '',
        isX: false,
      );
    }
    notifyListeners();
  }

  // Calculate local end total preview
  int get currentEndTotal {
    int total = 0;
    for (final a in _currentEndArrows) {
      if (a.score.isNotEmpty) {
        if (a.isX || a.score == 'X' || a.score == '10X') {
          total += 10;
        } else if (a.score == 'M') {
          total += 0;
        } else {
          total += int.tryParse(a.score) ?? 0;
        }
      }
    }
    return total;
  }

  int get currentEndXCount {
    return _currentEndArrows.where((a) => a.isX || a.score == 'X' || a.score == '10X').length;
  }

  Future<void> submitEnd() async {
    if (_currentSession == null) return;

    // Fill blank slots with M
    for (int i = 0; i < _currentEndArrows.length; i++) {
      if (_currentEndArrows[i].score.isEmpty) {
        _currentEndArrows[i] = ArrowScore(
          arrowNumber: i + 1,
          score: 'M',
          isX: false,
          source: 'manual',
        );
      }
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_isOfflineMode || _currentSession!.id < 0) {
        await _submitEndOffline();
        return;
      }

      try {
        await apiService.recordEnd(
          sessionId: _currentSession!.id,
          endNumber: _currentEndNumber,
          arrows: _currentEndArrows,
        );
        // Reload session details from server
        await openSession(_currentSession!.id);
        await loadSessions();
      } catch (e) {
        // Network failure mid-session: fall back to offline save
        _isOfflineMode = true;
        await _submitEndOffline();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _submitEndOffline() async {
    final sessionId = _currentSession!.id;
    final endCalc = OfflineScoringEngine.calculateEndScore(_currentEndArrows);

    final newEnd = ScoringEnd(
      id: -1 * DateTime.now().millisecondsSinceEpoch,
      sessionId: sessionId,
      endNumber: _currentEndNumber,
      totalScore: endCalc.totalScore,
      xCount: endCalc.xCount,
      arrows: List<ArrowScore>.from(_currentEndArrows),
      createdAt: DateTime.now().toIso8601String(),
    );

    await localStorageService.saveEnd(sessionId, newEnd);

    // Refresh completed ends list
    _completedEnds = await localStorageService.getSessionEnds(sessionId);

    // Recompute and persist session summary
    _currentSessionSummary = OfflineScoringEngine.calculateSessionSummary(
      sessionId,
      _completedEnds,
      totalEnds: _currentSession!.totalEnds,
    );
    await localStorageService.saveSessionSummary(sessionId, _currentSessionSummary!);

    // Check completion
    final isLastEnd = _currentEndNumber >= _currentSession!.totalEnds;
    final nextEndNumber = isLastEnd ? _currentEndNumber : _currentEndNumber + 1;
    final newStatus = isLastEnd ? 'completed' : 'in_progress';
    final completedAt = isLastEnd ? DateTime.now().toIso8601String() : null;

    _currentSession = _currentSession!.copyWith(
      currentEnd: nextEndNumber,
      status: newStatus,
      completedAt: completedAt,
    );
    await localStorageService.saveSession(_currentSession!);

    _currentEndNumber = nextEndNumber;
    if (!isLastEnd) {
      _initEndSlots(_currentSession!.arrowsPerEnd);
      await watchService.updateSessionState(currentEnd: nextEndNumber);
    } else {
      await watchService.endWatchSession();
    }
    await loadSessions();
  }

  Future<void> finishSessionNow() async {
    if (_currentSession == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await watchService.endWatchSession();
      final sessionId = _currentSession!.id;
      final isOffline = _isOfflineMode || sessionId < 0;

      if (isOffline) {
        _completedEnds = await localStorageService.getSessionEnds(sessionId);
        _currentSessionSummary = OfflineScoringEngine.calculateSessionSummary(
          sessionId,
          _completedEnds,
          totalEnds: _completedEnds.isNotEmpty ? _completedEnds.length : _currentSession!.totalEnds,
        );
        await localStorageService.saveSessionSummary(sessionId, _currentSessionSummary!);

        _currentSession = _currentSession!.copyWith(
          status: 'completed',
          completedAt: DateTime.now().toIso8601String(),
        );
        await localStorageService.saveSession(_currentSession!);
      } else {
        try {
          await apiService.completeSession(sessionId);
          await openSession(sessionId);
        } catch (e) {
          _isOfflineMode = true;
          _completedEnds = await localStorageService.getSessionEnds(sessionId);
          _currentSessionSummary = OfflineScoringEngine.calculateSessionSummary(
            sessionId,
            _completedEnds,
            totalEnds: _completedEnds.isNotEmpty ? _completedEnds.length : _currentSession!.totalEnds,
          );
          await localStorageService.saveSessionSummary(sessionId, _currentSessionSummary!);
          _currentSession = _currentSession!.copyWith(
            status: 'completed',
            completedAt: DateTime.now().toIso8601String(),
          );
          await localStorageService.saveSession(_currentSession!);
        }
      }
      await loadSessions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editPreviousEnd(int endNumber, List<ArrowScore> updatedArrows) async {
    if (_currentSession == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_isOfflineMode || _currentSession!.id < 0) {
        await _editPreviousEndOffline(endNumber, updatedArrows);
        return;
      }

      try {
        await apiService.updateEnd(
          sessionId: _currentSession!.id,
          endNumber: endNumber,
          arrows: updatedArrows,
        );
        await openSession(_currentSession!.id);
        await loadSessions();
      } catch (e) {
        _isOfflineMode = true;
        await _editPreviousEndOffline(endNumber, updatedArrows);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _editPreviousEndOffline(int endNumber, List<ArrowScore> updatedArrows) async {
    final sessionId = _currentSession!.id;
    final endCalc = OfflineScoringEngine.calculateEndScore(updatedArrows);

    final idx = _completedEnds.indexWhere((e) => e.endNumber == endNumber);
    if (idx >= 0) {
      final existing = _completedEnds[idx];
      final updatedEnd = existing.copyWith(
        totalScore: endCalc.totalScore,
        xCount: endCalc.xCount,
        arrows: updatedArrows,
      );
      await localStorageService.saveEnd(sessionId, updatedEnd);
      _completedEnds = await localStorageService.getSessionEnds(sessionId);

      _currentSessionSummary = OfflineScoringEngine.calculateSessionSummary(
        sessionId,
        _completedEnds,
        totalEnds: _currentSession!.totalEnds,
      );
      await localStorageService.saveSessionSummary(sessionId, _currentSessionSummary!);
      await loadSessions();
    }
  }

  // AI Target Scan (Runs 100% On-Device Offline, with optional server fallback)
  Future<Map<String, dynamic>> scanTargetImage(File image) async {
    if (_currentSession == null) throw Exception('No active session');

    final expectedCount = _currentSession!.arrowsPerEnd;

    // 1. If online mode is explicitly active, try server ML first
    if (!_isOfflineMode) {
      try {
        return await apiService.detectTargetImage(
          sessionId: _currentSession!.id,
          imageFile: image,
        );
      } catch (e) {
        debugPrint('Online scan failed ($e), falling back to on-device offline AI detector');
      }
    }

    // 2. On-Device Offline AI Target & Arrow Detector (Pure Dart, Zero Network)
    final result = await OfflineTargetDetector.detectFromImageFile(
      image,
      expectedArrowCount: expectedCount,
    );
    return result.toJson();
  }

  void applyAiScores(List<ArrowScore> detectedArrows) {
    for (final aiArrow in detectedArrows) {
      final idx = aiArrow.arrowNumber - 1;
      if (idx >= 0 && idx < _currentEndArrows.length) {
        _currentEndArrows[idx] = ArrowScore(
          arrowNumber: aiArrow.arrowNumber,
          score: aiArrow.score,
          isX: aiArrow.isX,
          source: 'ai',
        );
      }
    }
    notifyListeners();
  }

  // --- Apple Watch Shot Telemetry & Rematching Methods ---

  ShotEvent? getShotForArrow(int endNumber, int arrowNumber) {
    try {
      return _sessionShots.firstWhere(
        (s) => s.matchedEndNumber == endNumber && s.matchedArrowNumber == arrowNumber && !s.isIgnored,
      );
    } catch (_) {
      return null;
    }
  }

  List<ShotEvent> getShotsForEnd(int endNumber) {
    return _sessionShots.where((s) => s.matchedEndNumber == endNumber).toList();
  }

  List<ShotEvent> getUnmatchedShots() {
    return _sessionShots.where((s) => s.status == 'unmatched').toList();
  }

  Future<void> linkShotToArrow(String shotId, int endNumber, int arrowNumber) async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;

    for (int i = 0; i < _sessionShots.length; i++) {
      final s = _sessionShots[i];
      if (s.matchedEndNumber == endNumber && s.matchedArrowNumber == arrowNumber && s.id != shotId) {
        // Displace previous match
        _sessionShots[i] = s.copyWith(
          clearMatchedEnd: true,
          clearMatchedArrow: true,
          status: 'unmatched',
        );
      } else if (s.id == shotId) {
        _sessionShots[i] = s.copyWith(
          matchedEndNumber: endNumber,
          matchedArrowNumber: arrowNumber,
          status: 'matched',
        );
      }
    }
    await localStorageService.saveSessionShots(sessionId, _sessionShots);
    notifyListeners();
  }

  Future<void> unlinkShot(String shotId) async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;
    final idx = _sessionShots.indexWhere((s) => s.id == shotId);
    if (idx >= 0) {
      _sessionShots[idx] = _sessionShots[idx].copyWith(
        clearMatchedEnd: true,
        clearMatchedArrow: true,
        status: 'unmatched',
      );
      await localStorageService.saveSessionShots(sessionId, _sessionShots);
      notifyListeners();
    }
  }

  Future<void> ignoreShot(String shotId) async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;
    final idx = _sessionShots.indexWhere((s) => s.id == shotId);
    if (idx >= 0) {
      _sessionShots[idx] = _sessionShots[idx].copyWith(
        clearMatchedEnd: true,
        clearMatchedArrow: true,
        status: 'ignored',
      );
      await localStorageService.saveSessionShots(sessionId, _sessionShots);
      notifyListeners();
    }
  }

  Future<void> recordManualShotForActiveSlot() async {
    if (_currentSession == null) return;
    final shot = ShotEvent(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: _currentSession!.id,
      timestamp: DateTime.now(),
      confidence: 1.0,
      peakAcceleration: 0.0,
      drawDurationMs: 3000,
      matchedEndNumber: _currentEndNumber,
      matchedArrowNumber: _activeSlotIndex + 1,
      isManual: true,
      status: 'matched',
    );
    _sessionShots.add(shot);
    await localStorageService.addSessionShot(_currentSession!.id, shot);
    notifyListeners();
  }

  Future<void> autoAlignShotsForEnd(int endNumber) async {
    if (_currentSession == null) return;
    final sessionId = _currentSession!.id;

    // Get unassigned shots and shots already tagged for this end, sorted by timestamp
    final candidateShots = _sessionShots.where(
      (s) => !s.isIgnored && (s.matchedEndNumber == endNumber || s.status == 'unmatched'),
    ).toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final arrowLimit = _currentSession!.arrowsPerEnd;
    for (int i = 0; i < candidateShots.length; i++) {
      final shot = candidateShots[i];
      final targetIdx = _sessionShots.indexWhere((s) => s.id == shot.id);
      if (targetIdx >= 0) {
        if (i < arrowLimit) {
          _sessionShots[targetIdx] = shot.copyWith(
            matchedEndNumber: endNumber,
            matchedArrowNumber: i + 1,
            status: 'matched',
          );
        } else {
          _sessionShots[targetIdx] = shot.copyWith(
            clearMatchedEnd: true,
            clearMatchedArrow: true,
            status: 'unmatched',
          );
        }
      }
    }
    await localStorageService.saveSessionShots(sessionId, _sessionShots);
    notifyListeners();
  }

  Future<ShotEvent?> simulateShot({
    double confidence = 0.94,
    double peakAcceleration = 5.2,
    int drawDurationMs = 3400,
  }) async {
    final sessionId = _currentSession?.id ?? 1;
    return await watchService.simulateShot(
      sessionId: sessionId,
      confidence: confidence,
      peakAcceleration: peakAcceleration,
      drawDurationMs: drawDurationMs,
    );
  }
}
