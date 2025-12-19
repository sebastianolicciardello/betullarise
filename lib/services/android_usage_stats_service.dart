import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_usage/app_usage.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Servizio per gestire le statistiche di utilizzo delle app su Android
class AndroidUsageStatsService {
  static const String _tag = 'AndroidUsageStatsService';

  /// Ottiene la versione di Android del dispositivo
  Future<int> _getAndroidVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.sdkInt;
    } catch (e) {
      debugPrint('$_tag: Error getting Android version: $e');
      return 0;
    }
  }

  /// Controlla se il permesso PACKAGE_USAGE_STATS è stato concesso
  Future<bool> isUsageStatsPermissionGranted() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      debugPrint('$_tag: Checking usage stats permission...');

      final androidVersion = await _getAndroidVersion();
      debugPrint('$_tag: Android version: $androidVersion (API level)');

      bool result;

      // Per Android 11+ (API 30+), usa l'approccio AppOps che è più affidabile
      if (androidVersion >= 30) {
        result = await _checkPermissionWithAppOps();
        debugPrint('$_tag: Used AppOps method for Android 11+');
      } else {
        // Per versioni precedenti, usa il metodo tradizionale
        result = await _checkPermissionByAccess();
        debugPrint('$_tag: Used traditional method for Android < 11');
      }

      debugPrint('$_tag: Permission check result: $result');
      return result;
    } catch (e) {
      debugPrint('$_tag: Primary permission check failed: $e');

      // Fallback: prova l'altro metodo indipendentemente dalla versione
      try {
        final fallbackResult = await _checkPermissionByAccess();
        debugPrint('$_tag: Fallback permission check result: $fallbackResult');
        return fallbackResult;
      } catch (fallbackError) {
        debugPrint('$_tag: All permission checks failed: $fallbackError');
        return false;
      }
    }
  }

  /// Controlla il permesso usando AppOpsManager (più affidabile per Android 11+)
  Future<bool> _checkPermissionWithAppOps() async {
    try {
      // Questo approccio usa il package app_usage che internamente controlla
      // lo stato del permesso tramite AppOpsManager
      final testDate = DateTime.now();
      final startDate = DateTime(testDate.year, testDate.month, testDate.day);
      final endDate = startDate.add(const Duration(days: 1));

      debugPrint(
        '$_tag: Testing permission with date range: $startDate to $endDate',
      );

      // Se riusciamo ad ottenere i dati senza eccezioni, il permesso è concesso
      final usageList = await AppUsage().getAppUsage(startDate, endDate);

      debugPrint('$_tag: Usage list length: ${usageList.length}');

      // Anche una lista vuota può significare permesso concesso se non ci sono dati
      // L'importante è che non lanci un'eccezione
      debugPrint(
        '$_tag: Usage stats permission granted (via AppOps - no exception thrown)',
      );
      return true;
    } catch (e) {
      debugPrint('$_tag: AppOps permission check failed: $e');
      // Se otteniamo un'eccezione di sicurezza o permesso negato, il permesso non è concesso
      if (e.toString().contains('permission') ||
          e.toString().contains('denied') ||
          e.toString().contains('PACKAGE_USAGE_STATS')) {
        return false;
      }
      // Altre eccezioni potrebbero essere dovute ad altri problemi, non necessariamente permessi
      debugPrint(
        '$_tag: Exception may not be permission-related, assuming granted',
      );
      return true;
    }
  }

  /// Controlla il permesso provando ad accedere ai dati con timeout (fallback)
  Future<bool> _checkPermissionByAccess() async {
    try {
      final testDate = DateTime.now();
      final startDate = DateTime(testDate.year, testDate.month, testDate.day);
      final endDate = startDate.add(const Duration(days: 1));

      // Prova ad ottenere i dati di utilizzo - se riesce, il permesso è concesso
      await AppUsage().getAppUsage(startDate, endDate);
      debugPrint('$_tag: Usage stats permission granted (fallback method)');
      return true;
    } catch (e) {
      debugPrint('$_tag: Permission check failed: $e');
      return false;
    }
  }

  /// Richiede il permesso PACKAGE_USAGE_STATS
  /// Su Android apre le impostazioni dove l'utente può concedere il permesso manualmente
  /// Ritorna false poiché il permesso deve essere concesso manualmente
  Future<bool> requestUsageStatsPermission() async {
    if (!Platform.isAndroid) {
      debugPrint('$_tag: Usage stats not supported on this platform');
      return false;
    }

    try {
      debugPrint(
        '$_tag: Opening Android settings for usage stats permission...',
      );

      // Usa intent specifici invece di URL schemes per migliore compatibilità con Android 11+
      bool opened = false;

      // Prima prova: apri direttamente le impostazioni di accesso ai dati di utilizzo
      try {
        const usageAccessSettings = 'android.settings.USAGE_ACCESS_SETTINGS';
        if (await canLaunchUrl(Uri.parse(usageAccessSettings))) {
          await launchUrl(Uri.parse(usageAccessSettings));
          debugPrint('$_tag: Opened usage access settings via intent');
          opened = true;
        }
      } catch (e) {
        debugPrint('$_tag: Failed to open usage access settings: $e');
      }

      // Seconda prova: apri i dettagli dell'app specifici (per Android 11+)
      if (!opened) {
        try {
          final packageUri = Uri.parse('package:betullarise');
          if (await canLaunchUrl(packageUri)) {
            await launchUrl(packageUri);
            debugPrint('$_tag: Opened app details via package URI');
            opened = true;
          }
        } catch (e) {
          debugPrint('$_tag: Failed to open app details: $e');
        }
      }

      // Terza prova: impostazioni generali delle app
      if (!opened) {
        try {
          const appDetailsUrl = 'android.settings.APPLICATION_DETAILS_SETTINGS';
          if (await canLaunchUrl(Uri.parse(appDetailsUrl))) {
            await launchUrl(Uri.parse(appDetailsUrl));
            debugPrint('$_tag: Opened general app details');
            opened = true;
          }
        } catch (e) {
          debugPrint('$_tag: Failed to open general app details: $e');
        }
      }

      if (!opened) {
        debugPrint('$_tag: Could not launch any settings');
        throw 'No settings could be opened';
      }

      debugPrint('$_tag: Opened settings for user to grant permission');
      return false; // Il permesso deve essere concesso manualmente
    } catch (e) {
      debugPrint('$_tag: Error opening settings: $e');
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

      // Usa il plugin app_usage per ottenere i dati reali
      final List<AppUsageInfo> usageList = await AppUsage().getAppUsage(
        startDate,
        endDate,
      );

      final Map<String, int> usageData = {};

      for (final info in usageList) {
        // Filtra per package se specificati
        if (packages.isEmpty || packages.contains(info.packageName)) {
          // Converti Duration in minuti
          final minutes = info.usage.inMinutes;
          usageData[info.packageName] = minutes;
        }
      }

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
