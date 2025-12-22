import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../model/screen_time_rule.dart';
import '../model/daily_screen_usage.dart';
import '../database/screen_time_rules_database_helper.dart';
import '../database/daily_screen_usage_database_helper.dart';
import '../provider/points_provider.dart';
import '../model/point.dart';

/// Service to manage screen time penalty calculations
class ScreenTimeCalculationService {
  static const String _tag = 'ScreenTimeCalculationService';

  /// Calculate unconfirmed days that have penalties to apply
  /// Returns a list ordered from oldest to most recent
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

  /// Calculate the penalty for a specific rule on a specific date
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

      // Create or update the daily usage record
      final usage = DailyScreenUsage(
        ruleId: rule.id!,
        date: dateStr,
        totalUsageMinutes: actualUsageMinutes,
      );

      // Calculate exceeded minutes and penalty
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

  /// Apply the penalty to the points system
  Future<bool> applyPenaltyToPoints(
    PointsProvider pointsProvider,
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

      // Create a Point for the penalty
      final penaltyPoint = Point(
        points: usage.calculatedPenalty,
        type: 'screen_time',
        referenceId: usage.id,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Add the points (will be negative if it's a penalty)
      await pointsProvider.savePoints(penaltyPoint);

      // Mark the penalty as confirmed
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      await dbHelper.confirmPenalty(usage);

      debugPrint('$_tag: Penalty applied successfully');
      return true;
    } catch (e) {
      debugPrint('$_tag: Error applying penalty: $e');
      return false;
    }
  }

  /// Check and calculate penalties for all active rules
  /// for a specific day
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
        // Check if penalty is already confirmed for today
        final dbHelper = DailyScreenUsageDatabaseHelper.instance;
        final dateStr = _formatDate(date);
        final existingUsage = await dbHelper.queryDailyUsageByRuleAndDate(
          rule.id!,
          dateStr,
        );

        if (existingUsage != null && existingUsage.penaltyConfirmed) {
          // Penalty already accepted, skip calculation
          continue;
        }

        // Calculate total usage for the packages in this rule
        int totalUsage = 0;
        for (final package in rule.appPackages) {
          totalUsage += appsUsage[package] ?? 0;
        }

        // Calculate the penalty for this rule
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

  /// Save a daily usage record in the database
  Future<bool> saveDailyUsage(DailyScreenUsage usage) async {
    try {
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;

      // Use the insertOrUpdate method that handles both insert and update
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

  /// Delete old data (more than 1 month)
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

  /// Format a date as YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if there are penalties to confirm for a specific date
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

  /// Get a summary of penalties from the last month
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

      // Calculate days with penalties (requires custom query)
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

      // Calculate total days checked
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
        'totalPenalties': totalPenalty.abs(), // Absolute value for penalties
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

  /// Get statistics for a specific rule
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
