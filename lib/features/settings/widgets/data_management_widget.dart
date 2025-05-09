import 'package:flutter/material.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

class DataManagementWidget extends StatelessWidget {
  final DatabaseExportImportService exportImportService;
  final DialogService dialogService;

  const DataManagementWidget({
    super.key,
    required this.exportImportService,
    required this.dialogService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data Management:', style: TextStyle(fontSize: 18)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Export Data'),
          onPressed: () async {
            dialogService.showLoadingDialog(context, 'Exporting data...');

            final exportPath = await exportImportService.exportData(context);

            if (context.mounted) {
              Navigator.of(context).pop();

              if (exportPath != null) {
                dialogService.showResultDialog(
                  context,
                  'Data Exported',
                  'Your data has been exported to:\n$exportPath',
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.download),
          label: const Text('Import Data'),
          onPressed: () async {
            final confirmResult = await dialogService.showConfirmDialog(
              context,
              'Import Data',
              'This will overwrite your current data. Make sure you have a backup. Continue?',
            );

            if (confirmResult == true && context.mounted) {
              dialogService.showLoadingDialog(context, 'Importing data...');

              final success = await exportImportService.importData(context);

              if (context.mounted) {
                Navigator.of(context).pop();

                if (success) {
                  dialogService.showResultDialog(
                    context,
                    'Data Imported',
                    'Your data has been imported successfully. Please restart the app for changes to take effect.',
                  );
                }
              }
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            minimumSize: const Size(double.infinity, 0),
          ),
        ),
      ],
    );
  }
}
