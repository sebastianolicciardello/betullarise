class Point {
  int? id; // Unique identifier for the point
  int? referenceId; // Reference to task or habit ID
  String type; // Type: "task" or "habit"
  double points;
  int insertTime;

  Point({
    this.id,
    this.referenceId,
    required this.type,
    required this.points,
    required this.insertTime,
  });

  Point copyWith({
    int? id,
    int? referenceId,
    String? type,
    double? points,
    int? insertTime,
  }) {
    return Point(
      id: id ?? this.id,
      referenceId: referenceId ?? this.referenceId,
      type: type ?? this.type,
      points: points ?? this.points,
      insertTime: insertTime ?? this.insertTime,
    );
  }

  // Converts a Point object to a map for SQLite
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'reference_id': referenceId,
      'type': type,
      'points': points,
      'insert_time': insertTime,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Builds a Point object from a map
  factory Point.fromMap(Map<String, dynamic> map) {
    return Point(
      id: map['id'],
      referenceId: map['reference_id'],
      type: map['type'],
      points: map['points'],
      insertTime: map['insert_time'],
    );
  }

  @override
  String toString() {
    return 'Point(id: $id, referenceId: $referenceId, type: $type, points: $points, insertTime: $insertTime)';
  }
}
