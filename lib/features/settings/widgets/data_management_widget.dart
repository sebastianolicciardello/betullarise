import 'package:flutter/material.dart';
import 'package:betullarise/services/database_export_import_service.dart';

class DataManagementWidget extends StatelessWidget {
  const DataManagementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final exportImportService = DatabaseExportImportService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data Management:', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Export Data'),
          onPressed: () async {
            _showLoadingDialog(context, 'Exporting data...');

            final exportPath = await exportImportService.exportData(context);

            if (context.mounted) {
              Navigator.of(context).pop();

              if (exportPath != null) {
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
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Import Data'),
          onPressed: () async {
            final confirmResult = await _showConfirmDialog(
              context,
              'Import Data',
              'This will overwrite your current data. Make sure you have a backup. Continue?',
            );

            if (confirmResult == true && context.mounted) {
              _showLoadingDialog(context, 'Importing data...');

              final success = await exportImportService.importData(context);

              if (context.mounted) {
                Navigator.of(context).pop();

                if (success) {
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
    );
  }

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