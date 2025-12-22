import 'package:flutter/foundation.dart';
import '../model/screen_time_rule.dart';
import '../model/daily_screen_usage.dart';
import '../database/screen_time_rules_database_helper.dart';
import '../services/android_usage_stats_service.dart';
import '../services/screen_time_calculation_service.dart';
import '../provider/points_provider.dart';

/// Provider to manage screen time state
class ScreenTimeProvider with ChangeNotifier {
  final AndroidUsageStatsService _usageStatsService;
  final ScreenTimeCalculationService _calculationService;

  ScreenTimeProvider({
    AndroidUsageStatsService? usageStatsService,
    ScreenTimeCalculationService? calculationService,
  }) : _usageStatsService = usageStatsService ?? AndroidUsageStatsService(),
       _calculationService =
           calculationService ?? ScreenTimeCalculationService();

  // States
  List<ScreenTimeRule> _rules = [];
  List<DailyScreenUsage> _unconfirmedDays = [];
  bool _isLoading = false;
  bool _hasPermission = false; // Default to false, check immediately
  String? _errorMessage;

  // Getters
  List<ScreenTimeRule> get rules => _rules;
  List<DailyScreenUsage> get unconfirmedDays => _unconfirmedDays;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  String? get errorMessage => _errorMessage;

  /// Set the loading state
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Force the permission state (when user confirms they granted it)
  void setHasPermission(bool value) {
    if (_hasPermission != value) {
      _hasPermission = value;
      notifyListeners();
    }
  }

  /// Set an error message
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Clear the error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Load all active rules
  Future<void> loadRules() async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      _rules = await dbHelper.queryAllScreenTimeRules();

      debugPrint('ScreenTimeProvider: Loaded ${_rules.length} rules');
      notifyListeners();
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error loading rules: $e');
      setErrorMessage('Error loading rules: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Load only active rules
  Future<void> loadActiveRules() async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      _rules = await dbHelper.queryActiveScreenTimeRules();

      debugPrint('ScreenTimeProvider: Loaded ${_rules.length} active rules');
      notifyListeners();
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error loading active rules: $e');
      setErrorMessage('Error loading active rules: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Check if there are unconfirmed days with penalties
  Future<void> checkForUnconfirmedDays() async {
    try {
      setLoading(true);
      clearError();

      _unconfirmedDays = await _calculationService.getUnconfirmedDays();

      debugPrint(
        'ScreenTimeProvider: Found ${_unconfirmedDays.length} unconfirmed days',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error checking unconfirmed days: $e');
      setErrorMessage('Error checking unconfirmed days: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Add a new rule
  Future<bool> addRule(ScreenTimeRule rule) async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      final id = await dbHelper.insertScreenTimeRule(rule);
      rule.id = id;

      // Reload rules
      await loadRules();

      // Immediately calculate penalties for today with the new rule
      try {
        final today = DateTime.now();
        final todayPenalties = await calculatePenaltiesForDate(today);

        // Save the calculated penalties
        for (final usage in todayPenalties) {
          if (usage.calculatedPenalty < 0) {
            // Only save if there's a penalty to apply
            await saveDailyUsage(usage);
          }
        }

        // Reload unconfirmed days to include new penalties
        await checkForUnconfirmedDays();

        debugPrint(
          'ScreenTimeProvider: Recalculated penalties for today after adding rule',
        );
      } catch (e) {
        debugPrint(
          'ScreenTimeProvider: Error recalculating penalties after adding rule: $e',
        );
        // Don't fail the rule addition if recalculation fails
      }

      debugPrint('ScreenTimeProvider: Added rule ${rule.name}');
      return true;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error adding rule: $e');
      setErrorMessage('Errore nell\'aggiunta della regola: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Update an existing rule
  Future<bool> updateRule(
    ScreenTimeRule rule,
    PointsProvider pointsProvider,
  ) async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.updateScreenTimeRule(rule);

      // Recalculate penalties for past usages with the updated rule
      await _calculationService.recalculatePenaltiesForRule(
        rule,
        pointsProvider,
      );

      // Reload rules
      await loadRules();

      debugPrint('ScreenTimeProvider: Updated rule ${rule.name}');
      return true;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error updating rule: $e');
      setErrorMessage('Errore nell\'aggiornamento della regola: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Delete a rule
  Future<bool> deleteRule(int ruleId) async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.deleteScreenTimeRule(ruleId);

      // Remove from local list
      _rules.removeWhere((rule) => rule.id == ruleId);

      debugPrint('ScreenTimeProvider: Deleted rule with ID $ruleId');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error deleting rule: $e');
      setErrorMessage('Errore nell\'eliminazione della regola: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Activate/deactivate a rule
  Future<bool> toggleRuleActive(int ruleId, bool isActive) async {
    try {
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.toggleScreenTimeRuleActive(ruleId, isActive);

      // Update local rule
      final ruleIndex = _rules.indexWhere((rule) => rule.id == ruleId);
      if (ruleIndex != -1) {
        _rules[ruleIndex] = _rules[ruleIndex].copyWith(isActive: isActive);
        notifyListeners();
      }

      debugPrint('ScreenTimeProvider: Toggled rule $ruleId active: $isActive');
      return true;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error toggling rule: $e');
      setErrorMessage('Errore nell\'attivazione della regola: $e');
      return false;
    }
  }

  /// Check if usage stats permission is granted
  Future<bool> checkUsageStatsPermission() async {
    const int maxRetries = 3;
    const Duration delay = Duration(milliseconds: 1000);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Add a delay to allow the system to update permissions
        await Future.delayed(delay);

        final result = await _usageStatsService.isUsageStatsPermissionGranted();
        debugPrint(
          'ScreenTimeProvider: Permission check attempt $attempt/$maxRetries: $result',
        );

        if (result) {
          _hasPermission = true;
          notifyListeners();
          return true;
        }

        if (attempt < maxRetries) {
          debugPrint('ScreenTimeProvider: Permission not granted, retrying...');
        }
      } catch (e) {
        debugPrint(
          'ScreenTimeProvider: Error checking permission on attempt $attempt: $e',
        );
        if (attempt == maxRetries) {
          setErrorMessage('Error checking permissions: $e');
        }
      }
    }

    _hasPermission = false;
    notifyListeners();
    return false;
  }

  /// Request usage stats permission
  Future<bool> requestUsageStatsPermission() async {
    try {
      _hasPermission = await _usageStatsService.requestUsageStatsPermission();
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error requesting permission: $e');
      setErrorMessage('Error requesting permissions: $e');
      return false;
    }
  }

  /// Perform a complete check when opening the screen time section
  Future<void> performInitialCheck() async {
    try {
      setLoading(true);
      clearError();

      // 0. Check permissions only if not already granted
      if (!_hasPermission) {
        await checkUsageStatsPermission();
      }

      // If we don't have permission, don't load anything else
      if (!_hasPermission) {
        debugPrint('ScreenTimeProvider: No permission, skipping other checks');
        return;
      }

      // 1. Load active rules
      await loadActiveRules();

      // 2. Check unconfirmed days
      await checkForUnconfirmedDays();

      debugPrint('ScreenTimeProvider: Initial check completed');
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error in initial check: $e');
      setErrorMessage('Error in initial check: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Calculate penalties for all rules for a specific date
  Future<List<DailyScreenUsage>> calculatePenaltiesForDate(
    DateTime date,
  ) async {
    try {
      // Get app usage for the specified day
      final appsUsage = await _usageStatsService.getAppsUsageForDay(date, []);

      // Calculate penalties for all rules
      return await _calculationService.checkAllRulesForDate(date, appsUsage);
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error calculating penalties: $e');
      setErrorMessage('Error calculating penalties: $e');
      return [];
    }
  }

  /// Save daily usage
  Future<bool> saveDailyUsage(DailyScreenUsage usage) async {
    try {
      return await _calculationService.saveDailyUsage(usage);
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error saving daily usage: $e');
      setErrorMessage('Errore nel salvataggio dell\'utilizzo giornaliero: $e');
      return false;
    }
  }

  /// Clean up old data
  Future<bool> cleanupOldData() async {
    try {
      setLoading(true);
      clearError();

      final result = await _calculationService.cleanupOldData();

      // Reload unconfirmed days after cleanup
      await checkForUnconfirmedDays();

      return result;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error cleaning up old data: $e');
      setErrorMessage('Error cleaning up old data: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Get monthly penalty summary
  Future<Map<String, dynamic>> getMonthlySummary() async {
    try {
      return await _calculationService.getMonthlyPenaltySummary();
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error getting monthly summary: $e');
      setErrorMessage('Error retrieving monthly summary: $e');
      return {
        'totalPenalties': 0.0,
        'daysWithPenalties': 0,
        'totalDaysChecked': 0,
        'averagePenaltyPerDay': 0.0,
      };
    }
  }

  /// Get a specific rule by ID
  ScreenTimeRule? getRuleById(int ruleId) {
    try {
      return _rules.firstWhere((rule) => rule.id == ruleId);
    } catch (e) {
      return null;
    }
  }

  /// Reset provider state
  void reset() {
    _rules = [];
    _unconfirmedDays = [];
    _isLoading = false;
    _hasPermission = false;
    _errorMessage = null;
    notifyListeners();
  }
}
