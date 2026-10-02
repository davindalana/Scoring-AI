import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/athlete.dart';
import '../data/models/session.dart';
import '../data/models/end_score.dart';
import '../data/models/session_summary.dart';
import '../data/services/api_service.dart';
import '../data/services/local_storage_service.dart';
import '../data/services/offline_scoring_engine.dart';

class ScoringProvider extends ChangeNotifier {
  final ApiService apiService;
  final LocalStorageService localStorageService;

  ScoringProvider({
    required this.apiService,
    LocalStorageService? localStorageService,
  }) : localStorageService = localStorageService ?? LocalStorageService();

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
    _isOfflineMode = localStorageService.isOfflineForced;

    await loadAthletes();
    await loadSessions();
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

  Future<Athlete> addAthlete(String name, String? code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      if (_isOfflineMode) {
        final athlete = await localStorageService.addAthlete(name, code);
        await loadAthletes();
        _selectedAthlete = athlete;
        return athlete;
      }

      try {
        final athlete = await apiService.createAthlete(name, code);
        await loadAthletes();
        _selectedAthlete = athlete;
        return athlete;
      } catch (e) {
        // Fallback to local storage
        _isOfflineMode = true;
        final athlete = await localStorageService.addAthlete(name, code);
        await loadAthletes();
        _selectedAthlete = athlete;
        return athlete;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    }
    await loadSessions();
  }

  Future<void> finishSessionNow() async {
    if (_currentSession == null) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
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

  // AI Target Scan
  Future<Map<String, dynamic>> scanTargetImage(File image) async {
    if (_currentSession == null) throw Exception('No active session');
    if (_isOfflineMode) {
      throw Exception('AI Target Scan requires server connectivity. Please use manual scoring or switch online.');
    }
    return await apiService.detectTargetImage(
      sessionId: _currentSession!.id,
      imageFile: image,
    );
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
}
