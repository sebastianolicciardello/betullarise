import 'dart:typed_data';

/// Modelli comuni per l'applicazione
class AppInfo {
  final String packageName;
  final String appName;
  final bool isSystemApp;
  final Uint8List? icon;

  AppInfo({
    required this.packageName,
    required this.appName,
    required this.isSystemApp,
    this.icon,
  });
}
