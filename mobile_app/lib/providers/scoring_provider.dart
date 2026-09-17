import 'dart:io';
import 'package:flutter/material.dart';
import '../data/models/athlete.dart';
import '../data/models/session.dart';
import '../data/models/end_score.dart';
import '../data/models/session_summary.dart';
import '../data/services/api_service.dart';

class ScoringProvider extends ChangeNotifier {
  final ApiService apiService;

  ScoringProvider({required this.apiService});

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

  // Load Initial Data
  Future<void> init() async {
    await apiService.init();
    await loadAthletes();
    await loadSessions();
  }

  Future<void> loadAthletes() async {
    try {
      _athletes = await apiService.getAthletes();
      if (_athletes.isNotEmpty && _selectedAthlete == null) {
        _selectedAthlete = _athletes.first;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<Athlete> addAthlete(String name, String? code) async {
    _isLoading = true;
    notifyListeners();
    try {
      final athlete = await apiService.createAthlete(name, code);
      await loadAthletes();
      _selectedAthlete = athlete;
      return athlete;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _sessions = await apiService.getSessions();
    } catch (e) {
      _errorMessage = e.toString();
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
    notifyListeners();
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openSession(int sessionId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final details = await apiService.getSessionDetails(sessionId);
      _currentSession = details['session'] as ScoringSession;
      _currentSessionAthlete = details['athlete'] as Athlete?;
      _currentSessionSummary = details['summary'] as SessionSummary;
      _completedEnds = details['ends'] as List<ScoringEnd>;

      _currentEndNumber = _currentSession!.currentEnd;
      _initEndSlots(_currentSession!.arrowsPerEnd);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    notifyListeners();
    try {
      await apiService.recordEnd(
        sessionId: _currentSession!.id,
        endNumber: _currentEndNumber,
        arrows: _currentEndArrows,
      );
      // Reload session details
      await openSession(_currentSession!.id);
      await loadSessions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> editPreviousEnd(int endNumber, List<ArrowScore> updatedArrows) async {
    if (_currentSession == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await apiService.updateEnd(
        sessionId: _currentSession!.id,
        endNumber: endNumber,
        arrows: updatedArrows,
      );
      await openSession(_currentSession!.id);
      await loadSessions();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // AI Target Scan
  Future<Map<String, dynamic>> scanTargetImage(File image) async {
    if (_currentSession == null) throw Exception('No active session');
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
