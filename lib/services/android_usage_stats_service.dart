import 'dart:io';
import 'package:flutter/foundation.dart';

/// Servizio per gestire le statistiche di utilizzo delle app su Android
class AndroidUsageStatsService {
  static const String _tag = 'AndroidUsageStatsService';

  /// Controlla se il permesso PACKAGE_USAGE_STATS è stato concesso
  Future<bool> isUsageStatsPermissionGranted() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Per ora implementazione semplificata, si integrerà con le API reali
      debugPrint('$_tag: Checking usage stats permission...');
      return true; // Placeholder
    } catch (e) {
      debugPrint('$_tag: Error checking usage stats permission: $e');
      return false;
    }
  }

  /// Richiede il permesso PACKAGE_USAGE_STATS
  /// Ritorna true se il permesso è concesso, false altrimenti
  Future<bool> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) {
      debugPrint('$_tag: Usage stats not supported on this platform');
      return false;
    }

    try {
      debugPrint('$_tag: Requesting usage stats permission...');
      // Placeholder - implementazione reale aprirà le impostazioni
      return true;
    } catch (e) {
      debugPrint('$_tag: Error requesting usage stats permission: $e');
      return false;
    }
  }

  /// Ottiene l'uso delle app per un giorno specifico
  /// [date] Data per cui ottenere le statistiche (solo giorno, ignorando l'ora)
  /// [packages] Lista di package names da filtrare (vuio = tutte le app)
  /// Ritorna una mappa {packageName: usageInMinutes}
  Future<Map<String, int>> getAppsUsageForDay(
    DateTime date,
    List<String> packages,
  ) async {
    if (!Platform.isAndroid) {
      return {};
    }

    if (!await isUsageStatsPermissionGranted()) {
      debugPrint('$_tag: Usage stats permission not granted');
      return {};
    }

    try {
      // Normalizza la data per iniziare a mezzanotte
      final startDate = DateTime(date.year, date.month, date.day);
      final endDate = startDate.add(const Duration(days: 1));

      debugPrint('$_tag: Getting usage from $startDate to $endDate');

      // Placeholder - implementazione reale userà le API di UsageStats
      final Map<String, int> mockData = {};

      // Dati mock per test
      for (final package in packages) {
        // Simula dati di utilizzo per le app più comuni
        if (package.contains('whatsapp')) {
          mockData[package] = 45; // 45 minuti
        } else if (package.contains('telegram')) {
          mockData[package] = 30; // 30 minuti
        } else if (package.contains('instagram')) {
          mockData[package] = 60; // 60 minuti
        } else if (package.contains('facebook')) {
          mockData[package] = 25; // 25 minuti
        } else {
          mockData[package] = 15; // 15 minuti default
        }
      }

      debugPrint('$_tag: Found usage for ${mockData.length} apps');
      return mockData;
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

  /// Ottiene la lista delle app installate sul dispositivo
  Future<List<AppInfo>> getInstalledApps() async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      debugPrint('$_tag: Getting installed apps...');

      // Placeholder - implementazione reale userà DeviceApps o PackageManager
      final List<AppInfo> mockApps = [
        AppInfo(
          packageName: 'com.whatsapp',
          appName: 'WhatsApp',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'org.telegram.messenger',
          appName: 'Telegram',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.facebook.katana',
          appName: 'Facebook',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.google.android.youtube',
          appName: 'YouTube',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.spotify.music',
          appName: 'Spotify',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.twitter.android',
          appName: 'Twitter',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.tinder',
          appName: 'Tinder',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.netflix.mediaclient',
          appName: 'Netflix',
          isSystemApp: false,
        ),
        AppInfo(
          packageName: 'com.google.android.gm',
          appName: 'Gmail',
          isSystemApp: false,
        ),
      ];

      debugPrint('$_tag: Found ${mockApps.length} installed apps');
      return mockApps;
    } catch (e) {
      debugPrint('$_tag: Error getting installed apps: $e');
      return [];
    }
  }

  /// Cerca app per nome o package name
  Future<List<AppInfo>> searchApps(String query) async {
    if (query.isEmpty) return [];

    final allApps = await getInstalledApps();

    return allApps.where((app) {
      final searchQuery = query.toLowerCase();
      return app.appName.toLowerCase().contains(searchQuery) ||
          app.packageName.toLowerCase().contains(searchQuery);
    }).toList();
  }

  /// Verifica se il dispositivo supporta le statistiche di utilizzo
  Future<bool> isUsageStatsSupported() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Try to get usage for today to check if the feature works
      final today = DateTime.now();
      await getAppsUsageForDay(today, []);
      return true; // If we get here without exceptions, it's supported
    } catch (e) {
      debugPrint('$_tag: Usage stats not supported: $e');
      return false;
    }
  }
}

/// Informazioni base su un'app installata
class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
  });

  @override
  String toString() {
    return 'AppInfo(packageName: $packageName, appName: $appName, isSystemApp: $isSystemApp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppInfo &&
        other.packageName == packageName &&
        other.appName == appName &&
        other.isSystemApp == isSystemApp;
  }

  @override
  int get hashCode {
    return Object.hash(packageName, appName, isSystemApp);
  }
}
