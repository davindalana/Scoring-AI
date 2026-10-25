class ShotEvent {
  final String id;
  final int sessionId;
  final DateTime timestamp;
  final double confidence;
  final double peakAcceleration;
  final int drawDurationMs;
  final int? matchedEndNumber;
  final int? matchedArrowNumber;
  final bool isManual;
  final String status; // 'matched', 'unmatched', 'ignored'

  ShotEvent({
    required this.id,
    required this.sessionId,
    required this.timestamp,
    required this.confidence,
    required this.peakAcceleration,
    required this.drawDurationMs,
    this.matchedEndNumber,
    this.matchedArrowNumber,
    this.isManual = false,
    this.status = 'unmatched',
  });

  bool get isMatched => status == 'matched' && matchedArrowNumber != null;
  bool get isIgnored => status == 'ignored';

  factory ShotEvent.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    if (json['timestamp'] is String) {
      parsedTime = DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now();
    } else if (json['timestamp'] is int) {
      parsedTime = DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int);
    } else {
      parsedTime = DateTime.now();
    }

    return ShotEvent(
      id: (json['id'] ?? '').toString(),
      sessionId: (json['session_id'] ?? 0) as int,
      timestamp: parsedTime,
      confidence: ((json['confidence'] ?? 0.0) as num).toDouble(),
      peakAcceleration: ((json['peak_acceleration'] ?? 0.0) as num).toDouble(),
      drawDurationMs: ((json['draw_duration_ms'] ?? 0) as num).toInt(),
      matchedEndNumber: json['matched_end'] as int?,
      matchedArrowNumber: json['matched_arrow'] as int?,
      isManual: json['is_manual'] == true || json['is_manual'] == 1,
      status: (json['status'] ?? (json['matched_arrow'] != null ? 'matched' : 'unmatched')) as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'session_id': sessionId,
    'timestamp': timestamp.toIso8601String(),
    'confidence': confidence,
    'peak_acceleration': peakAcceleration,
    'draw_duration_ms': drawDurationMs,
    if (matchedEndNumber != null) 'matched_end': matchedEndNumber,
    if (matchedArrowNumber != null) 'matched_arrow': matchedArrowNumber,
    'is_manual': isManual,
    'status': status,
  };

  ShotEvent copyWith({
    String? id,
    int? sessionId,
    DateTime? timestamp,
    double? confidence,
    double? peakAcceleration,
    int? drawDurationMs,
    int? matchedEndNumber,
    bool clearMatchedEnd = false,
    int? matchedArrowNumber,
    bool clearMatchedArrow = false,
    bool? isManual,
    String? status,
  }) {
    return ShotEvent(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      peakAcceleration: peakAcceleration ?? this.peakAcceleration,
      drawDurationMs: drawDurationMs ?? this.drawDurationMs,
      matchedEndNumber: clearMatchedEnd ? null : (matchedEndNumber ?? this.matchedEndNumber),
      matchedArrowNumber: clearMatchedArrow ? null : (matchedArrowNumber ?? this.matchedArrowNumber),
      isManual: isManual ?? this.isManual,
      status: status ?? this.status,
    );
  }
}
