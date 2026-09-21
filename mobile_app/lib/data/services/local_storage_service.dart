import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/athlete.dart';
import '../models/session.dart';
import '../models/end_score.dart';
import '../models/session_summary.dart';

class LocalStorageService {
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) {
      throw StateError('LocalStorageService must be initialized with init() first.');
    }
    return _prefs!;
  }

  // --- Offline Mode Preference ---
  static const String _keyOfflineForced = 'offline_mode_forced';

  bool get isOfflineForced => prefs.getBool(_keyOfflineForced) ?? false;

  Future<void> setOfflineForced(bool forced) async {
    await prefs.setBool(_keyOfflineForced, forced);
  }

  // --- Athletes Storage ---
  static const String _keyAthletes = 'offline_athletes_list';

  Future<List<Athlete>> getAthletes() async {
    final raw = prefs.getString(_keyAthletes);
    if (raw == null || raw.isEmpty) {
      // Provide a default local athlete if none exist
      final defaultAthlete = Athlete(
        id: -1,
        name: 'Local Athlete',
        athleteCode: 'OFFLINE-01',
        createdAt: DateTime.now().toIso8601String(),
      );
      await saveAthletes([defaultAthlete]);
      return [defaultAthlete];
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => Athlete.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAthletes(List<Athlete> athletes) async {
    final raw = jsonEncode(athletes.map((a) => {
      'id': a.id,
      'name': a.name,
      'athlete_code': a.athleteCode,
      'created_at': a.createdAt,
    }).toList());
    await prefs.setString(_keyAthletes, raw);
  }

  Future<Athlete> addAthlete(String name, String? code) async {
    final current = await getAthletes();
    // Negative ID for local athletes to prevent collision with server IDs
    final localId = -1 * (DateTime.now().millisecondsSinceEpoch % 1000000);
    final newAthlete = Athlete(
      id: localId,
      name: name,
      athleteCode: code,
      createdAt: DateTime.now().toIso8601String(),
    );
    current.insert(0, newAthlete);
    await saveAthletes(current);
    return newAthlete;
  }

  // --- Sessions Storage ---
  static const String _keySessions = 'offline_sessions_list';

  Future<List<ScoringSession>> getSessions() async {
    final raw = prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => ScoringSession.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessions(List<ScoringSession> sessions) async {
    final raw = jsonEncode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_keySessions, raw);
  }

  Future<ScoringSession> saveSession(ScoringSession session) async {
    final sessions = await getSessions();
    final idx = sessions.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      sessions[idx] = session;
    } else {
      sessions.insert(0, session);
    }
    await saveSessions(sessions);
    return session;
  }

  Future<ScoringSession?> getSessionById(int sessionId) async {
    final sessions = await getSessions();
    try {
      return sessions.firstWhere((s) => s.id == sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateSessionStatus(
    int sessionId,
    String status, {
    int? currentEnd,
    String? completedAt,
  }) async {
    final sessions = await getSessions();
    final idx = sessions.indexWhere((s) => s.id == sessionId);
    if (idx >= 0) {
      final updated = sessions[idx].copyWith(
        status: status,
        currentEnd: currentEnd,
        completedAt: completedAt,
      );
      sessions[idx] = updated;
      await saveSessions(sessions);
    }
  }

  // --- Ends Storage per Session ---
  String _endsKey(int sessionId) => 'offline_session_ends_$sessionId';

  Future<List<ScoringEnd>> getSessionEnds(int sessionId) async {
    final raw = prefs.getString(_endsKey(sessionId));
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((item) => ScoringEnd.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessionEnds(int sessionId, List<ScoringEnd> ends) async {
    final raw = jsonEncode(ends.map((e) => e.toJson()).toList());
    await prefs.setString(_endsKey(sessionId), raw);
  }

  Future<void> saveEnd(int sessionId, ScoringEnd end) async {
    final currentEnds = await getSessionEnds(sessionId);
    final idx = currentEnds.indexWhere((e) => e.endNumber == end.endNumber);
    if (idx >= 0) {
      currentEnds[idx] = end;
    } else {
      currentEnds.add(end);
    }
    currentEnds.sort((a, b) => a.endNumber.compareTo(b.endNumber));
    await saveSessionEnds(sessionId, currentEnds);
  }

  // --- Session Summary Storage ---
  String _summaryKey(int sessionId) => 'offline_session_summary_$sessionId';

  Future<SessionSummary?> getSessionSummary(int sessionId) async {
    final raw = prefs.getString(_summaryKey(sessionId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return SessionSummary.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSessionSummary(int sessionId, SessionSummary summary) async {
    final raw = jsonEncode(summary.toJson());
    await prefs.setString(_summaryKey(sessionId), raw);
  }
}
