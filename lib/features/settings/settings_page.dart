import 'package:betullarise/provider/theme_notifier.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/services/database_export_import_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<PackageInfo> _getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    final exportImportService = DatabaseExportImportService();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<PackageInfo>(
              future: _getPackageInfo(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snap.hasError) {
                  return const Text('Error loading package info');
                } else if (snap.hasData) {
                  final info = snap.data!;
                  return Text(
                    'Version ${info.version} (${info.buildNumber})',
                    style: const TextStyle(fontSize: 16),
                  );
                }
                return const Text('No data');
              },
            ),
            const SizedBox(height: 40),
            const Text('Select theme:', style: TextStyle(fontSize: 18)),
            RadioListTile<ThemeMode>(
              title: const Text('Automatic'),
              value: ThemeMode.system,
              groupValue: themeNotifier.themeMode,
              onChanged:
                  (m) => m != null ? themeNotifier.setThemeMode(m) : null,
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Light'),
              value: ThemeMode.light,
              groupValue: themeNotifier.themeMode,
              onChanged:
                  (m) => m != null ? themeNotifier.setThemeMode(m) : null,
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Dark'),
              value: ThemeMode.dark,
              groupValue: themeNotifier.themeMode,
              onChanged:
                  (m) => m != null ? themeNotifier.setThemeMode(m) : null,
            ),
            const SizedBox(height: 40),
            const Text('Data Management:', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),

            // Export data button
            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Export Data'),
              onPressed: () async {
                // Show loading indicator
                _showLoadingDialog(context, 'Exporting data...');

                // Export data
                final exportPath = await exportImportService.exportData(
                  context,
                );

                if (context.mounted) {
                  // Hide loading indicator
                  Navigator.of(context).pop();

                  if (exportPath != null) {
                    // Show success dialog with export path
                    _showResultDialog(
                      context,
                      'Data Exported',
                      'Your data has been exported to:\n$exportPath',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),

            const SizedBox(height: 16),

            // Import data button
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Import Data'),
              onPressed: () async {
                // Confirm import
                final confirmResult = await _showConfirmDialog(
                  context,
                  'Import Data',
                  'This will overwrite your current data. Make sure you have a backup. Continue?',
                );

                if (confirmResult == true && context.mounted) {
                  // Show loading indicator
                  _showLoadingDialog(context, 'Importing data...');

                  // Import data
                  final success = await exportImportService.importData(context);

                  if (context.mounted) {
                    // Hide loading indicator
                    Navigator.of(context).pop();

                    if (success) {
                      // Show restart recommendation
                      _showResultDialog(
                        context,
                        'Data Imported',
                        'Your data has been imported successfully. Please restart the app for changes to take effect.',
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                minimumSize: const Size(double.infinity, 0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show a loading dialog
  DialogRoute _showLoadingDialog(BuildContext context, String message) {
    return DialogRoute(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        );
      },
    );
  }

  // Show a confirmation dialog
  Future<bool?> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Continue'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
  }

  // Show a result dialog
  Future<void> _showResultDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}
