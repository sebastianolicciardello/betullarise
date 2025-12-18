class DailyScreenUsage {
  int? id;
  int ruleId;
  String date; // YYYY-MM-DD format
  int totalUsageMinutes; // Tempo effettivo usato
  int exceededMinutes; // Minuti oltre limite
  double calculatedPenalty; // Penalità calcolata
  bool penaltyConfirmed; // Se confermata dall'utente
  DateTime? penaltyConfirmedAt; // Quando confermata

  DailyScreenUsage({
    this.id,
    required this.ruleId,
    required this.date,
    this.totalUsageMinutes = 0,
    this.exceededMinutes = 0,
    this.calculatedPenalty = 0.0,
    this.penaltyConfirmed = false,
    this.penaltyConfirmedAt,
  });

  DailyScreenUsage copyWith({
    int? id,
    int? ruleId,
    String? date,
    int? totalUsageMinutes,
    int? exceededMinutes,
    double? calculatedPenalty,
    bool? penaltyConfirmed,
    DateTime? penaltyConfirmedAt,
  }) {
    return DailyScreenUsage(
      id: id ?? this.id,
      ruleId: ruleId ?? this.ruleId,
      date: date ?? this.date,
      totalUsageMinutes: totalUsageMinutes ?? this.totalUsageMinutes,
      exceededMinutes: exceededMinutes ?? this.exceededMinutes,
      calculatedPenalty: calculatedPenalty ?? this.calculatedPenalty,
      penaltyConfirmed: penaltyConfirmed ?? this.penaltyConfirmed,
      penaltyConfirmedAt: penaltyConfirmedAt ?? this.penaltyConfirmedAt,
    );
  }

  // Calcola i minuti superati e la penalità basata sul limite
  void calculateExceededMinutesAndPenalty(
    int dailyTimeLimitMinutes,
    double penaltyPerMinuteExtra,
  ) {
    if (totalUsageMinutes > dailyTimeLimitMinutes) {
      exceededMinutes = totalUsageMinutes - dailyTimeLimitMinutes;
      calculatedPenalty = exceededMinutes * penaltyPerMinuteExtra;
    } else {
      exceededMinutes = 0;
      calculatedPenalty = 0.0;
    }
  }

  // Converte un oggetto DailyScreenUsage in una mappa per SQLite.
  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'rule_id': ruleId,
      'date': date,
      'total_usage_minutes': totalUsageMinutes,
      'exceeded_minutes': exceededMinutes,
      'calculated_penalty': calculatedPenalty,
      'penalty_confirmed': penaltyConfirmed ? 1 : 0,
      'penalty_confirmed_at': penaltyConfirmedAt?.millisecondsSinceEpoch,
    };

    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  // Costruisce un oggetto DailyScreenUsage a partire da una mappa.
  factory DailyScreenUsage.fromMap(Map<String, dynamic> map) {
    return DailyScreenUsage(
      id: map['id'],
      ruleId: map['rule_id'],
      date: map['date'],
      totalUsageMinutes: map['total_usage_minutes'] ?? 0,
      exceededMinutes: map['exceeded_minutes'] ?? 0,
      calculatedPenalty: map['calculated_penalty']?.toDouble() ?? 0.0,
      penaltyConfirmed: (map['penalty_confirmed'] ?? 0) == 1,
      penaltyConfirmedAt:
          map['penalty_confirmed_at'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['penalty_confirmed_at'])
              : null,
    );
  }

  @override
  String toString() {
    return 'DailyScreenUsage(id: $id, ruleId: $ruleId, date: $date, totalUsageMinutes: $totalUsageMinutes, exceededMinutes: $exceededMinutes, calculatedPenalty: $calculatedPenalty, penaltyConfirmed: $penaltyConfirmed, penaltyConfirmedAt: $penaltyConfirmedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyScreenUsage &&
        other.id == id &&
        other.ruleId == ruleId &&
        other.date == date &&
        other.totalUsageMinutes == totalUsageMinutes &&
        other.exceededMinutes == exceededMinutes &&
        other.calculatedPenalty == calculatedPenalty &&
        other.penaltyConfirmed == penaltyConfirmed;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      ruleId,
      date,
      totalUsageMinutes,
      exceededMinutes,
      calculatedPenalty,
      penaltyConfirmed,
    );
  }
}
