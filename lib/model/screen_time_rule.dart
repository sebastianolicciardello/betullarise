class ScreenTimeRule {
  int? id;
  String name; // "CHAT", "SOCIAL", custom
  List<String> appPackages; // Package names Android
  int dailyTimeLimitMinutes; // 60, 120, etc.
  double penaltyPerMinuteExtra; // negative value for penalty deduction
  bool isActive;
  int createdTime;
  int updatedTime;

  ScreenTimeRule({
    this.id,
    required this.name,
    required this.appPackages,
    required this.dailyTimeLimitMinutes,
    required this.penaltyPerMinuteExtra,
    this.isActive = true,
    required this.createdTime,
    required this.updatedTime,
  });

  ScreenTimeRule copyWith({
    int? id,
    String? name,
    List<String>? appPackages,
    int? dailyTimeLimitMinutes,
    double? penaltyPerMinuteExtra,
    bool? isActive,
    int? createdTime,
    int? updatedTime,
  }) {
    return ScreenTimeRule(
      id: id ?? this.id,
      name: name ?? this.name,
      appPackages: appPackages ?? this.appPackages,
      dailyTimeLimitMinutes:
          dailyTimeLimitMinutes ?? this.dailyTimeLimitMinutes,
      penaltyPerMinuteExtra:
          penaltyPerMinuteExtra ?? this.penaltyPerMinuteExtra,
      isActive: isActive ?? this.isActive,
      createdTime: createdTime ?? this.createdTime,
      updatedTime: updatedTime ?? this.updatedTime,
    );
  }

  // Converts a ScreenTimeRule object to a map for SQLite.
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'name': name,
      'app_packages': appPackages.join(
        ',',
      ), // Convert list to comma-separated string
      'daily_time_limit_minutes': dailyTimeLimitMinutes,
      'penalty_per_minute_extra': penaltyPerMinuteExtra,
      'is_active': isActive ? 1 : 0,
      'created_time': createdTime,
      'updated_time': updatedTime,
    };

    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Builds a ScreenTimeRule object from a map.
  factory ScreenTimeRule.fromMap(Map<String, dynamic> map) {
    return ScreenTimeRule(
      id: map['id'],
      name: map['name'],
      appPackages: (map['app_packages'] as String? ?? '').split(','),
      dailyTimeLimitMinutes: map['daily_time_limit_minutes'],
      penaltyPerMinuteExtra: map['penalty_per_minute_extra'],
      isActive: (map['is_active'] ?? 1) == 1,
      createdTime: map['created_time'],
      updatedTime: map['updated_time'],
    );
  }

  @override
  String toString() {
    return 'ScreenTimeRule(id: $id, name: $name, appPackages: $appPackages, dailyTimeLimitMinutes: $dailyTimeLimitMinutes, penaltyPerMinuteExtra: $penaltyPerMinuteExtra, isActive: $isActive, createdTime: $createdTime, updatedTime: $updatedTime)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScreenTimeRule &&
        other.id == id &&
        other.name == name &&
        other.dailyTimeLimitMinutes == dailyTimeLimitMinutes &&
        other.penaltyPerMinuteExtra == penaltyPerMinuteExtra &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      dailyTimeLimitMinutes,
      penaltyPerMinuteExtra,
      isActive,
    );
  }
}
