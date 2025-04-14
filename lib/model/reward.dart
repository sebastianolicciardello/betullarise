class Reward {
  int? id; // Unique identifier for the reward
  String title; // Title of the reward
  String description; // Description of the reward
  String type; // Type: "single" or "multiple"
  double points; // Points consumed by the user
  int insertTime; // When the reward was created
  int updateTime; // When the reward was last updated

  Reward({
    this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.points,
    required this.insertTime,
    required this.updateTime,
  });

  Reward copyWith({
    int? id,
    String? title,
    String? description,
    String? type,
    double? points,
    int? insertTime,
    int? updateTime,
  }) {
    return Reward(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      points: points ?? this.points,
      insertTime: insertTime ?? this.insertTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  // Converts a Reward object to a map for SQLite
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'title': title,
      'description': description,
      'type': type,
      'points': points,
      'insert_time': insertTime,
      'update_time': updateTime,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Builds a Reward object from a map
  factory Reward.fromMap(Map<String, dynamic> map) {
    return Reward(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      type: map['type'],
      points: map['points'],
      insertTime: map['insert_time'],
      updateTime: map['update_time'],
    );
  }

  @override
  String toString() {
    return 'Reward(id: $id, title: $title, description: $description, type: $type, points: $points, insertTime: $insertTime, updateTime: $updateTime)';
  }
}
