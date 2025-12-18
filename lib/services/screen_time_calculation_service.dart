import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import '../model/screen_time_rule.dart';
import '../model/daily_screen_usage.dart';
import '../database/screen_time_rules_database_helper.dart';
import '../database/daily_screen_usage_database_helper.dart';
import '../provider/points_provider.dart';
import '../model/point.dart';

/// Servizio per gestire i calcoli delle penalità dello screen time
class ScreenTimeCalculationService {
  static const String _tag = 'ScreenTimeCalculationService';

  /// Calcola i giorni non confermati che hanno penalità da applicare
  /// Ritorna una lista ordinata dal più vecchio al più recente
  Future<List<DailyScreenUsage>> getUnconfirmedDays() async {
    try {
      debugPrint('$_tag: Getting unconfirmed days...');

      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      final unconfirmedDays = await dbHelper.queryUnconfirmedDailyUsage();

      debugPrint('$_tag: Found ${unconfirmedDays.length} unconfirmed days');
      return unconfirmedDays;
    } catch (e) {
      debugPrint('$_tag: Error getting unconfirmed days: $e');
      return [];
    }
  }

  /// Calcola la penalità per una regola specifica in una data specifica
  Future<DailyScreenUsage> calculatePenaltyForRule(
    ScreenTimeRule rule,
    DateTime date,
    int actualUsageMinutes,
  ) async {
    try {
      final dateStr = _formatDate(date);

      debugPrint(
        '$_tag: Calculating penalty for rule ${rule.name} on $dateStr',
      );
      debugPrint(
        '$_tag: Usage: ${actualUsageMinutes}min, Limit: ${rule.dailyTimeLimitMinutes}min',
      );

      // Crea o aggiorna il record di utilizzo giornaliero
      final usage = DailyScreenUsage(
        ruleId: rule.id!,
        date: dateStr,
        totalUsageMinutes: actualUsageMinutes,
      );

      // Calcola i minuti superati e la penalità
      usage.calculateExceededMinutesAndPenalty(
        rule.dailyTimeLimitMinutes,
        rule.penaltyPerMinuteExtra,
      );

      debugPrint(
        '$_tag: Exceeded minutes: ${usage.exceededMinutes}, Penalty: ${usage.calculatedPenalty}',
      );

      return usage;
    } catch (e) {
      debugPrint('$_tag: Error calculating penalty: $e');
      rethrow;
    }
  }

  /// Applica la penalità al sistema punti
  Future<bool> applyPenaltyToPoints(
    BuildContext context,
    DailyScreenUsage usage,
  ) async {
    try {
      if (usage.calculatedPenalty == 0.0) {
        debugPrint('$_tag: No penalty to apply');
        return true;
      }

      debugPrint(
        '$_tag: Applying penalty of ${usage.calculatedPenalty} points',
      );

      // Ottieni il PointsProvider dal context
      final pointsProvider = Provider.of<PointsProvider>(
        context,
        listen: false,
      );

      // Crea un Point per la penalità
      final penaltyPoint = Point(
        points: usage.calculatedPenalty,
        type: 'screen_time',
        referenceId: usage.id,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Aggiungi i punti (saranno negativi se è una penalità)
      await pointsProvider.savePoints(penaltyPoint);

      // Marca la penalità come confermata
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      await dbHelper.confirmPenalty(usage);

      debugPrint('$_tag: Penalty applied successfully');
      return true;
    } catch (e) {
      debugPrint('$_tag: Error applying penalty: $e');
      return false;
    }
  }

  /// Controlla e calcola le penalità per tutte le regole attive
  /// per una giornata specifica
  Future<List<DailyScreenUsage>> checkAllRulesForDate(
    DateTime date,
    Map<String, int> appsUsage, // packageName -> usageMinutes
  ) async {
    try {
      debugPrint('$_tag: Checking all rules for date ${_formatDate(date)}');

      final rulesDbHelper = ScreenTimeRulesDatabaseHelper.instance;
      final activeRules = await rulesDbHelper.queryActiveScreenTimeRules();

      final List<DailyScreenUsage> results = [];

      for (final rule in activeRules) {
        // Calcola l'uso totale per i package di questa regola
        int totalUsage = 0;
        for (final package in rule.appPackages) {
          totalUsage += appsUsage[package] ?? 0;
        }

        // Calcola la penalità per questa regola
        final usage = await calculatePenaltyForRule(rule, date, totalUsage);
        results.add(usage);
      }

      debugPrint(
        '$_tag: Checked ${results.length} rules for date ${_formatDate(date)}',
      );
      return results;
    } catch (e) {
      debugPrint('$_tag: Error checking all rules: $e');
      return [];
    }
  }

  /// Salva un record di utilizzo giornaliero nel database
  Future<bool> saveDailyUsage(DailyScreenUsage usage) async {
    try {
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;

      // Usa il metodo insertOrUpdate che gestisce sia insert che update
      await dbHelper.insertOrUpdateDailyScreenUsage(usage);

      debugPrint(
        '$_tag: Saved usage for rule ${usage.ruleId} on ${usage.date}',
      );
      return true;
    } catch (e) {
      debugPrint('$_tag: Error saving daily usage: $e');
      return false;
    }
  }

  /// Elimina i dati vecchi (più di 1 mese)
  Future<bool> cleanupOldData() async {
    try {
      debugPrint('$_tag: Cleaning up old data...');

      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      final deletedCount = await dbHelper.deleteOldDailyUsage(daysToKeep: 30);

      debugPrint('$_tag: Deleted $deletedCount old usage records');
      return true;
    } catch (e) {
      debugPrint('$_tag: Error cleaning up old data: $e');
      return false;
    }
  }

  /// Formatta una data in stringa YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Controlla se ci sono penalità da confermare per una data specifica
  Future<bool> hasUnconfirmedPenaltiesForDate(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      final unconfirmedUsages = await dbHelper.queryUnconfirmedDailyUsage();

      return unconfirmedUsages.any(
        (usage) => usage.date == dateStr && usage.calculatedPenalty != 0.0,
      );
    } catch (e) {
      debugPrint('$_tag: Error checking unconfirmed penalties: $e');
      return false;
    }
  }

  /// Ottieni un riepilogo delle penalità dell'ultimo mese
  Future<Map<String, dynamic>> getMonthlyPenaltySummary() async {
    try {
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      final startDate = _formatDate(oneMonthAgo);
      final endDate = _formatDate(DateTime.now());

      final totalPenalty = await dbHelper.getTotalPenaltyForPeriod(
        startDate,
        endDate,
      );

      // Calcola giorni con penalità (necessita di query personalizzata)
      final Database db = await dbHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT COUNT(*) as days_with_penalty
        FROM ${DailyScreenUsageDatabaseHelper.tableDailyScreenUsage}
        WHERE date >= ? AND date <= ? AND penalty_confirmed = 1 AND calculated_penalty < 0
      ''',
        [startDate, endDate],
      );

      final daysWithPenalties = result.first['days_with_penalty'] as int? ?? 0;

      // Calcola giorni totali controllati
      final totalDaysResult = await db.rawQuery(
        '''
        SELECT COUNT(DISTINCT date) as total_days_checked
        FROM ${DailyScreenUsageDatabaseHelper.tableDailyScreenUsage}
        WHERE date >= ? AND date <= ?
      ''',
        [startDate, endDate],
      );

      final totalDaysChecked =
          totalDaysResult.first['total_days_checked'] as int? ?? 0;

      return {
        'totalPenalties': totalPenalty.abs(), // Valore assoluto per penalità
        'daysWithPenalties': daysWithPenalties,
        'totalDaysChecked': totalDaysChecked,
        'averagePenaltyPerDay':
            totalDaysChecked > 0 ? totalPenalty.abs() / totalDaysChecked : 0.0,
      };
    } catch (e) {
      debugPrint('$_tag: Error getting monthly penalty summary: $e');
      return {
        'totalPenalties': 0.0,
        'daysWithPenalties': 0,
        'totalDaysChecked': 0,
        'averagePenaltyPerDay': 0.0,
      };
    }
  }

  /// Ottieni le statistiche per una regola specifica
  Future<Map<String, dynamic>> getRuleStatistics(int ruleId) async {
    try {
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      return await dbHelper.getRuleStatistics(ruleId);
    } catch (e) {
      debugPrint('$_tag: Error getting rule statistics: $e');
      return {
        'totalDays': 0,
        'totalUsageMinutes': 0,
        'totalExceededMinutes': 0,
        'totalPenalty': 0.0,
        'daysWithPenalty': 0,
        'averageDailyUsage': 0.0,
      };
    }
  }
}
