import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
    final borderColor =
        Theme.of(context).brightness == Brightness.dark
            ? Colors.white54
            : Colors.black26;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Management:', style: TextStyle(fontSize: 18.sp)),
        SizedBox(height: 16.h),
        OutlinedButton.icon(
          icon: const Icon(Icons.upload),
          label: const Text('Export Data'),
          onPressed: () async {
            dialogService.showLoadingDialog(context, 'Exporting data...');

            final exportPath = await exportImportService.exportData();

            if (context.mounted) {
              Navigator.of(context).pop();

              if (exportPath != null) {
                dialogService.showResultDialog(
                  context,
                  'Data Exported',
                  'Your data has been exported to:\n$exportPath',
                );
              } else {
                dialogService.showResultDialog(
                  context,
                  'Export Failed',
                  'Failed to export data. Please try again.',
                );
              }
            }
          },
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 24.w),
            minimumSize: const Size(double.infinity, 0),
            side: BorderSide(color: borderColor, width: 1.5.w),
            textStyle: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.r),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        OutlinedButton.icon(
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

              try {
                final success = await exportImportService.importData();

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
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop();

                  String errorMessage = 'Failed to import data.';
                  if (e is InvalidBackupException) {
                    errorMessage = 'Invalid backup file: ${e.message}';
                  } else if (e is PermissionException) {
                    errorMessage = 'Permission error: ${e.message}';
                  } else {
                    errorMessage = 'Import failed: ${e.toString()}';
                  }

                  dialogService.showResultDialog(
                    context,
                    'Import Failed',
                    errorMessage,
                  );
                }
              }
            }
          },
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 24.w),
            minimumSize: const Size(double.infinity, 0),
            side: BorderSide(color: borderColor, width: 1.5.w),
            textStyle: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30.r),
            ),
          ),
        ),
      ],
    );
  }
}
