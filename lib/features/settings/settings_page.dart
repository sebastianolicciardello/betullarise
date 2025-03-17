import 'package:betullarise/provider/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<PackageInfo> _getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<PackageInfo>(
              future: _getPackageInfo(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return const Text('Error loading package info');
                } else if (snapshot.hasData) {
                  final packageInfo = snapshot.data!;
                  return Text(
                    'Version ${packageInfo.version} (Build ${packageInfo.buildNumber})',
                    style: const TextStyle(fontSize: 16),
                  );
                } else {
                  return const Text('No data');
                }
              },
            ),
            const SizedBox(height: 40),
            // Sezione per il cambio del tema
            const Text("Select theme:", style: TextStyle(fontSize: 18)),
            RadioListTile<ThemeMode>(
              title: const Text("Automatic"),
              value: ThemeMode.system,
              groupValue: themeNotifier.themeMode,
              onChanged: (ThemeMode? mode) {
                if (mode != null) {
                  themeNotifier.setThemeMode(mode);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text("Light"),
              value: ThemeMode.light,
              groupValue: themeNotifier.themeMode,
              onChanged: (ThemeMode? mode) {
                if (mode != null) {
                  themeNotifier.setThemeMode(mode);
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text("Dark"),
              value: ThemeMode.dark,
              groupValue: themeNotifier.themeMode,
              onChanged: (ThemeMode? mode) {
                if (mode != null) {
                  themeNotifier.setThemeMode(mode);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
