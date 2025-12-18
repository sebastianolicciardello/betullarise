class Habit {
  int? id;
  String title;
  String description;
  double score;
  double penalty;
  String type; // single, multipler, badMultipler, counter
  bool showStreak; // Mostra visualizzazione streak per habit singolo
  bool
  showStreakMultiplier; // Mostra visualizzazione streak per habit multipler
  int? goal; // Numero da raggiungere per habit multipler
  int createdTime;
  int updatedTime;

  Habit({
    this.id,
    required this.title,
    required this.description,
    required this.score,
    required this.penalty,
    required this.type,
    this.showStreak = false,
    this.showStreakMultiplier = false,
    this.goal,
    required this.createdTime,
    required this.updatedTime,
  }) {
    // Validazione del tipo
    assert(
      type == 'single' ||
          type == 'singleWithPenalty' ||
          type == 'singleWithScore' ||
          type == 'multipler' ||
          type == 'multiplerWithScore' ||
          type == 'multiplerWithPenalty' ||
          type == 'counter',
      'Type must be one of: single, singleWithPenalty, singleWithScore, multipler, multiplerWithScore, multiplerWithPenalty, counter',
    );
  }

  Habit copyWith({
    int? id,
    String? title,
    String? description,
    double? score,
    double? penalty,
    String? type,
    bool? showStreak,
    bool? showStreakMultiplier,
    int? goal,
    int? createdTime,
    int? updatedTime,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      score: score ?? this.score,
      penalty: penalty ?? this.penalty,
      type: type ?? this.type,
      showStreak: showStreak ?? this.showStreak,
      showStreakMultiplier: showStreakMultiplier ?? this.showStreakMultiplier,
      goal: goal ?? this.goal,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }

  // Converte un oggetto Habit in una mappa per SQLite.
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'title': title,
      'description': description,
      'score': score,
      'penalty': penalty,
      'type': type,
      'show_streak': showStreak ? 1 : 0,
      'show_streak_multiplier': showStreakMultiplier ? 1 : 0,
      'goal': goal,
      'created_time': createdTime,
      'updated_time': updatedTime,
    };

    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Costruisce un oggetto Habit a partire da una mappa.
  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      score: map['score'],
      penalty: map['penalty'],
      type: map['type'],
      showStreak: (map['show_streak'] ?? 0) == 1,
      showStreakMultiplier: (map['show_streak_multiplier'] ?? 0) == 1,
      goal: map['goal'],
      createdTime: map['created_time'],
      updatedTime: map['updated_time'],
    );
  }

  @override
  String toString() {
    return 'Habit(id: $id, title: $title, description: $description, score: $score, penalty: $penalty, type: $type, showStreak: $showStreak, showStreakMultiplier: $showStreakMultiplier, goal: $goal, createdTime: $createdTime, updatedTime: $updatedTime)';
  }
}
