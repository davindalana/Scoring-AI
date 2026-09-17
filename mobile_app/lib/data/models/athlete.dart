class Athlete {
  final int id;
  final String name;
  final String? athleteCode;
  final String? createdAt;

  Athlete({
    required this.id,
    required this.name,
    this.athleteCode,
    this.createdAt,
  });

  factory Athlete.fromJson(Map<String, dynamic> json) {
    return Athlete(
      id: json['id'] as int,
      name: json['name'] as String,
      athleteCode: json['athlete_code'] as String?,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (athleteCode != null) 'athlete_code': athleteCode,
  };
}
