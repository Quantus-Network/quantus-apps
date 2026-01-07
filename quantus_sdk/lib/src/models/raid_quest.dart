class RaidQuest {
  final int id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime updatedAt;
  final DateTime createdAt;

  RaidQuest({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    required this.updatedAt,
    required this.createdAt,
  });

  factory RaidQuest.fromJson(Map<String, dynamic> json) {
    return RaidQuest(
      id: json['id'] as int,
      name: json['name'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
