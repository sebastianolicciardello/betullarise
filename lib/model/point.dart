class Point {
  int? taskId;
  double points;
  int insertTime;

  Point({this.taskId, required this.points, required this.insertTime});

  Point copyWith({int? taskId, double? points, int? insertTime}) {
    return Point(
      taskId: taskId ?? this.taskId,
      points: points ?? this.points,
      insertTime: insertTime ?? this.insertTime,
    );
  }

  // Converte un oggetto Point in una mappa per SQLite.
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{'points': points, 'insert_time': insertTime};
    if (taskId != null) {
      map['task_id'] = taskId;
    }
    return map;
  }

  // Costruisce un oggetto Point a partire da una mappa.
  factory Point.fromMap(Map<String, dynamic> map) {
    return Point(
      taskId: map['task_id'],
      points: map['points'],
      insertTime: map['insert_time'],
    );
  }

  @override
  String toString() {
    return 'Point(taskId: $taskId, points: $points, insertTime: $insertTime)';
  }
}
