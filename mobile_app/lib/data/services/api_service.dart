import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/athlete.dart';
import '../models/session.dart';
import '../models/end_score.dart';
import '../models/session_summary.dart';

class ApiService {
  static const String defaultBaseUrl = 'http://10.0.2.2:8000';
  static const String _baseUrlPrefKey = 'archery_api_base_url';

  String _baseUrl = defaultBaseUrl;

  String get baseUrl => _baseUrl;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString(_baseUrlPrefKey) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    String cleanUrl = url.trim();
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    _baseUrl = cleanUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlPrefKey, _baseUrl);
  }

  Uri _uri(String path, [Map<String, dynamic>? queryParams]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final urlStr = '$_baseUrl$cleanPath';
    return Uri.parse(urlStr).replace(queryParameters: queryParams);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Athlete APIs
  Future<List<Athlete>> getAthletes() async {
    final response = await http.get(_uri('/api/athletes'), headers: _headers);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Athlete.fromJson(json)).toList();
    }
    throw Exception('Failed to load athletes: ${response.body}');
  }

  Future<Athlete> createAthlete(String name, String? athleteCode) async {
    final payload = {
      'name': name,
      if (athleteCode != null && athleteCode.trim().isNotEmpty)
        'athlete_code': athleteCode.trim(),
    };
    final response = await http.post(
      _uri('/api/athletes'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201) {
      return Athlete.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to create athlete');
  }

  // Session APIs
  Future<List<ScoringSession>> getSessions({int limit = 30}) async {
    final response = await http.get(
      _uri('/api/sessions', {'limit': limit.toString()}),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ScoringSession.fromJson(json)).toList();
    }
    throw Exception('Failed to load sessions: ${response.body}');
  }

  Future<ScoringSession> createSession({
    required int athleteId,
    required String bowCategory,
    required String sessionType,
    required String distance,
    required int arrowsPerEnd,
    required int totalEnds,
  }) async {
    final payload = {
      'athlete_id': athleteId,
      'bow_category': bowCategory,
      'session_type': sessionType,
      'distance': distance,
      'arrows_per_end': arrowsPerEnd,
      'total_ends': totalEnds,
    };
    final response = await http.post(
      _uri('/api/sessions'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201) {
      return ScoringSession.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to create session');
  }

  Future<Map<String, dynamic>> getSessionDetails(int sessionId) async {
    final response = await http.get(
      _uri('/api/sessions/$sessionId'),
      headers: _headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final session = ScoringSession.fromJson(data['session']);
      final athlete = data['athlete'] != null
          ? Athlete.fromJson(data['athlete'])
          : null;
      final summary = SessionSummary.fromJson(data['summary']);
      final endsList = (data['ends'] as List<dynamic>? ?? [])
          .map((e) => ScoringEnd.fromJson(e))
          .toList();

      return {
        'session': session,
        'athlete': athlete,
        'summary': summary,
        'ends': endsList,
      };
    }
    throw Exception('Failed to fetch session details: ${response.body}');
  }

  Future<void> completeSession(int sessionId) async {
    final response = await http.patch(
      _uri('/api/sessions/$sessionId/complete'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to complete session');
    }
  }

  // End & Score APIs
  Future<ScoringEnd> recordEnd({
    required int sessionId,
    required int endNumber,
    required List<ArrowScore> arrows,
  }) async {
    final payload = {
      'end_number': endNumber,
      'arrows': arrows.map((a) => a.toJson()).toList(),
    };
    final response = await http.post(
      _uri('/api/sessions/$sessionId/ends'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 201) {
      return ScoringEnd.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to record end');
  }

  Future<ScoringEnd> updateEnd({
    required int sessionId,
    required int endNumber,
    required List<ArrowScore> arrows,
  }) async {
    final payload = {
      'arrows': arrows.map((a) => a.toJson()).toList(),
    };
    final response = await http.put(
      _uri('/api/sessions/$sessionId/ends/$endNumber'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return ScoringEnd.fromJson(jsonDecode(response.body));
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'Failed to update end');
  }

  // AI Target Image Detection
  Future<Map<String, dynamic>> detectTargetImage({
    required int sessionId,
    required File imageFile,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/sessions/$sessionId/detect'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    final err = jsonDecode(response.body);
    throw Exception(err['detail'] ?? 'AI Detection failed');
  }
}
