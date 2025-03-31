class Task {
  int? id;
  String title;
  String description;
  int deadline;
  int completionTime;
  double score;
  double penalty;
  int createdTime;
  int updatedTime;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.completionTime,
    required this.score,
    required this.penalty,
    required this.createdTime,
    required this.updatedTime,
  });

  Task copyWith({
    int? id,
    String? title,
    String? description,
    int? deadline,
    int? completionTime,
    double? score,
    double? penalty,
    int? createdTime,
    int? updatedTime,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      deadline: deadline ?? this.deadline,
      completionTime: completionTime ?? this.completionTime,
      score: score ?? this.score,
      penalty: penalty ?? this.penalty,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }

  // Converte un oggetto Task in una mappa per SQLite.
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'title': title,
      'description': description,
      'deadline': deadline,
      'completion_time': completionTime,
      'score': score,
      'penalty': penalty,
      'created_time': createdTime,
      'updated_time': updatedTime,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Costruisce un oggetto Task a partire da una mappa.
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      deadline: map['deadline'],
      completionTime: map['completion_time'],
      score: map['score'],
      penalty: map['penalty'],
      createdTime: map['created_time'],
      updatedTime: map['updated_time'],
    );
  }
}
