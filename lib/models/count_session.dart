class CountSession {
  final int? id;
  final int collectionId;
  final DateTime timestamp;
  final int peopleCount;
  final int correction;
  final String imagePath;
  final double confidenceThreshold;
  final double iouThreshold;
  final String? notes;

  const CountSession({
    this.id,
    required this.collectionId,
    required this.timestamp,
    required this.peopleCount,
    this.correction = 0,
    required this.imagePath,
    required this.confidenceThreshold,
    required this.iouThreshold,
    this.notes,
  });

  int get correctedCount => peopleCount + correction;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'collection_id': collectionId,
      'timestamp': timestamp.toIso8601String(),
      'people_count': peopleCount,
      'correction': correction,
      'image_path': imagePath,
      'confidence_threshold': confidenceThreshold,
      'iou_threshold': iouThreshold,
      'notes': notes,
    };
  }

  factory CountSession.fromMap(Map<String, Object?> map) {
    return CountSession(
      id: map['id'] as int?,
      collectionId: map['collection_id'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      peopleCount: map['people_count'] as int,
      correction: (map['correction'] as int?) ?? 0,
      imagePath: map['image_path'] as String,
      confidenceThreshold: (map['confidence_threshold'] as num).toDouble(),
      iouThreshold: (map['iou_threshold'] as num).toDouble(),
      notes: map['notes'] as String?,
    );
  }
}
