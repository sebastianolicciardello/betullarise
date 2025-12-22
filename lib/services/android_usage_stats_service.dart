import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servizio per gestire le statistiche di utilizzo delle app su Android usando native API
class AndroidUsageStatsService {
  static const String _tag = 'AndroidUsageStatsService';
  static const platform = MethodChannel('com.example.betullarise/usage_stats');

  /// Controlla se il permesso PACKAGE_USAGE_STATS è stato concesso
  Future<bool> isUsageStatsPermissionGranted() async {
    if (!Platform.isAndroid) {
      debugPrint('$_tag: Usage stats not supported on this platform');
      return false;
    }

    try {
      debugPrint('$_tag: Checking usage stats permission...');
      final bool granted = await platform.invokeMethod('checkUsagePermission');
      debugPrint('$_tag: Permission check result: $granted');
      return granted;
    } catch (e) {
      debugPrint('$_tag: Permission check failed: $e');
      return false;
    }
  }

  /// Richiede il permesso PACKAGE_USAGE_STATS
  Future<bool> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) {
      debugPrint('$_tag: Usage stats not supported on this platform');
      return false;
    }

    try {
      debugPrint('$_tag: Requesting usage stats permission...');
      await platform.invokeMethod('requestUsagePermission');
      debugPrint('$_tag: Requested permission');
      return false; // Il permesso deve essere concesso manualmente
    } catch (e) {
      debugPrint('$_tag: Error requesting permission: $e');
      return false;
    }
  }

  /// Ottiene l'uso delle app per un giorno specifico
  Future<Map<String, int>> getAppsUsageForDay(
    DateTime date,
    List<String> packages,
  ) async {
    if (!Platform.isAndroid) {
      debugPrint('$_tag: Usage stats not supported on this platform');
      return {};
    }

    try {
      // Controlla il permesso prima di procedere
      final hasPermission = await isUsageStatsPermissionGranted();
      if (!hasPermission) {
        debugPrint('$_tag: Usage stats permission not granted');
        return {};
      }

      final startDate = DateTime.utc(date.year, date.month, date.day);
      final endDate = startDate.add(const Duration(days: 1));
      final startTime = startDate.millisecondsSinceEpoch;
      final endTime = endDate.millisecondsSinceEpoch;

      debugPrint('$_tag: Getting usage from $startDate to $endDate');

      final Map<dynamic, dynamic> rawUsageData = await platform.invokeMethod(
        'getUsageStats',
        {'startTime': startTime, 'endTime': endTime},
      );

      final Map<String, int> usageData = {};
      rawUsageData.forEach((key, value) {
        final packageName = key as String;
        // Filtra per package se specificati
        if (packages.isEmpty || packages.contains(packageName)) {
          final minutes = value as int;
          usageData[packageName] = minutes;
        }
      });

      debugPrint('$_tag: Found usage for ${usageData.length} apps');
      return usageData;
    } catch (e) {
      debugPrint('$_tag: Error getting app usage for day: $e');
      return {};
    }
  }

  /// Ottiene l'uso totale in minuti per una lista di package in un giorno specifico
  Future<int> getTotalUsageForPackages(
    DateTime date,
    List<String> packages,
  ) async {
    if (packages.isEmpty) return 0;

    final usageMap = await getAppsUsageForDay(date, packages);

    int totalMinutes = 0;
    for (final packageName in packages) {
      totalMinutes += usageMap[packageName] ?? 0;
    }

    return totalMinutes;
  }

  /// Ottiene la lista delle app installate sul dispositivo (placeholder)
  Future<List<String>> getInstalledApps() async {
    // Placeholder - non implementato con native API
    return [];
  }
}
