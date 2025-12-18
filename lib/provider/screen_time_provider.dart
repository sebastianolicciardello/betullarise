import 'package:flutter/foundation.dart';
import '../model/screen_time_rule.dart';
import '../model/daily_screen_usage.dart';
import '../database/screen_time_rules_database_helper.dart';
import '../services/android_usage_stats_service.dart';
import '../services/screen_time_calculation_service.dart';

/// Provider per gestire lo stato dello screen time
class ScreenTimeProvider with ChangeNotifier {
  final AndroidUsageStatsService _usageStatsService;
  final ScreenTimeCalculationService _calculationService;

  ScreenTimeProvider({
    AndroidUsageStatsService? usageStatsService,
    ScreenTimeCalculationService? calculationService,
  }) : _usageStatsService = usageStatsService ?? AndroidUsageStatsService(),
       _calculationService =
           calculationService ?? ScreenTimeCalculationService();

  // Stati
  List<ScreenTimeRule> _rules = [];
  List<DailyScreenUsage> _unconfirmedDays = [];
  bool _isLoading = false;
  bool _hasPermission = true; // Default a true, controlla dopo
  String? _errorMessage;

  // Getters
  List<ScreenTimeRule> get rules => _rules;
  List<DailyScreenUsage> get unconfirmedDays => _unconfirmedDays;
  bool get isLoading => _isLoading;
  bool get hasPermission => _hasPermission;
  String? get errorMessage => _errorMessage;

  /// Imposta il loading state
  void setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Imposta un messaggio di errore
  void setErrorMessage(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Pulisce il messaggio di errore
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Carica tutte le regole attive
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
      setErrorMessage('Errore nel caricamento delle regole: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Carica solo le regole attive
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
      setErrorMessage('Errore nel caricamento delle regole attive: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Controlla se ci sono giorni non confermati con penalità
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
      setErrorMessage('Errore nel controllo dei giorni non confermati: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Aggiunge una nuova regola
  Future<bool> addRule(ScreenTimeRule rule) async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.insertScreenTimeRule(rule);

      // Ricarica le regole
      await loadRules();

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

  /// Aggiorna una regola esistente
  Future<bool> updateRule(ScreenTimeRule rule) async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.updateScreenTimeRule(rule);

      // Ricarica le regole
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

  /// Elimina una regola
  Future<bool> deleteRule(int ruleId) async {
    try {
      setLoading(true);
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.deleteScreenTimeRule(ruleId);

      // Rimuovi dalla lista locale
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

  /// Attiva/disattiva una regola
  Future<bool> toggleRuleActive(int ruleId, bool isActive) async {
    try {
      clearError();

      final dbHelper = ScreenTimeRulesDatabaseHelper.instance;
      await dbHelper.toggleScreenTimeRuleActive(ruleId, isActive);

      // Aggiorna la regola locale
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

  /// Verifica se il permesso per le statistiche di utilizzo è concesso
  Future<bool> checkUsageStatsPermission() async {
    try {
      _hasPermission = await _usageStatsService.isUsageStatsPermissionGranted();
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error checking permission: $e');
      setErrorMessage('Errore nel controllo dei permessi: $e');
      return false;
    }
  }

  /// Richiede il permesso per le statistiche di utilizzo
  Future<bool> requestUsageStatsPermission() async {
    try {
      _hasPermission = await _usageStatsService.requestUsageStatsPermission();
      notifyListeners();
      return _hasPermission;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error requesting permission: $e');
      setErrorMessage('Errore nella richiesta dei permessi: $e');
      return false;
    }
  }

  /// Esegue un check completo quando si apre la sezione screen time
  Future<void> performInitialCheck() async {
    try {
      setLoading(true);
      clearError();

      // 1. Carica le regole attive
      await loadActiveRules();

      // 2. Controlla i giorni non confermati
      await checkForUnconfirmedDays();

      debugPrint('ScreenTimeProvider: Initial check completed');
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error in initial check: $e');
      setErrorMessage('Errore nel controllo iniziale: $e');
    } finally {
      setLoading(false);
    }
  }

  /// Calcola le penalità per tutte le regole per una data specifica
  Future<List<DailyScreenUsage>> calculatePenaltiesForDate(
    DateTime date,
  ) async {
    try {
      // Ottieni l'uso delle app per il giorno specificato
      final appsUsage = await _usageStatsService.getAppsUsageForDay(date, []);

      // Calcola le penalità per tutte le regole
      return await _calculationService.checkAllRulesForDate(date, appsUsage);
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error calculating penalties: $e');
      setErrorMessage('Errore nel calcolo delle penalità: $e');
      return [];
    }
  }

  /// Salva un utilizzo giornaliero
  Future<bool> saveDailyUsage(DailyScreenUsage usage) async {
    try {
      return await _calculationService.saveDailyUsage(usage);
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error saving daily usage: $e');
      setErrorMessage('Errore nel salvataggio dell\'utilizzo giornaliero: $e');
      return false;
    }
  }

  /// Pulisce i dati vecchi
  Future<bool> cleanupOldData() async {
    try {
      setLoading(true);
      clearError();

      final result = await _calculationService.cleanupOldData();

      // Ricarica i giorni non confermati dopo la pulizia
      await checkForUnconfirmedDays();

      return result;
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error cleaning up old data: $e');
      setErrorMessage('Errore nella pulizia dei dati vecchi: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  /// Ottiene un riepilogo mensile delle penalità
  Future<Map<String, dynamic>> getMonthlySummary() async {
    try {
      return await _calculationService.getMonthlyPenaltySummary();
    } catch (e) {
      debugPrint('ScreenTimeProvider: Error getting monthly summary: $e');
      setErrorMessage('Errore nel recupero del riepilogo mensile: $e');
      return {
        'totalPenalties': 0.0,
        'daysWithPenalties': 0,
        'totalDaysChecked': 0,
        'averagePenaltyPerDay': 0.0,
      };
    }
  }

  /// Ottieni una regola specifica per ID
  ScreenTimeRule? getRuleById(int ruleId) {
    try {
      return _rules.firstWhere((rule) => rule.id == ruleId);
    } catch (e) {
      return null;
    }
  }

  /// Resetta lo stato del provider
  void reset() {
    _rules = [];
    _unconfirmedDays = [];
    _isLoading = false;
    _hasPermission = false;
    _errorMessage = null;
    notifyListeners();
  }
}
