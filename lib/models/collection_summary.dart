class CollectionSummary {
  final int id;
  final String name;
  final DateTime createdAt;
  final int sessionCount;
  final int totalPeople;

  const CollectionSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.sessionCount,
    required this.totalPeople,
  });

  factory CollectionSummary.fromMap(Map<String, Object?> map) {
    return CollectionSummary(
      id: map['id'] as int,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      sessionCount: map['session_count'] as int? ?? 0,
      totalPeople: map['total_people'] as int? ?? 0,
    );
  }
}
