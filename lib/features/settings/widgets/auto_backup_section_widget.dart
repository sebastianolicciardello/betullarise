import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:betullarise/provider/auto_backup_provider.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

class AutoBackupSectionWidget extends StatelessWidget {
  final DialogService dialogService;

  const AutoBackupSectionWidget({
    super.key,
    required this.dialogService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AutoBackupProvider>(
      builder: (context, autoBackupProvider, child) {
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Automatic Backups',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Automatically backup your data daily',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                SizedBox(height: 16.h),

                // Enable/Disable Switch
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Enable Auto-Backup',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Backup on first launch each day',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  value: autoBackupProvider.isEnabled,
                  activeColor: Theme.of(context).colorScheme.primary,
                  onChanged: (value) {
                    autoBackupProvider.setEnabled(value);
                  },
                ),

                SizedBox(height: 12.h),

                // Backup Folder Selection
                OutlinedButton.icon(
                  icon: Icon(Icons.folder_open, size: 20.sp),
                  label: Text(
                    autoBackupProvider.backupFolderPath == null
                        ? 'Select Backup Folder'
                        : 'Change Backup Folder',
                  ),
                  onPressed: () async {
                    final selectedDirectory =
                        await FilePicker.platform.getDirectoryPath();

                    if (selectedDirectory != null) {
                      await autoBackupProvider.setBackupFolderPath(selectedDirectory);

                      if (context.mounted) {
                        dialogService.showResultDialog(
                          context,
                          'Folder Selected',
                          'Backups will be saved to:\n$selectedDirectory',
                        );
                      }
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 20.w,
                    ),
                    minimumSize: const Size(double.infinity, 0),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                  ),
                ),

                if (autoBackupProvider.backupFolderPath != null) ...[
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      'Folder: ${autoBackupProvider.backupFolderPath}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],

                if (autoBackupProvider.lastBackupDate != null) ...[
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16.sp,
                          color: Colors.green,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Last backup: ${_formatDate(autoBackupProvider.lastBackupDate!)}',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: 12.h),

                // Manual Backup Button
                OutlinedButton.icon(
                  icon: Icon(Icons.backup, size: 20.sp),
                  label: const Text('Backup Now'),
                  onPressed: autoBackupProvider.backupFolderPath == null
                      ? null
                      : () async {
                          dialogService.showLoadingDialog(
                            context,
                            'Creating backup...',
                          );

                          try {
                            final success = await autoBackupProvider.performBackup();

                            if (context.mounted) {
                              Navigator.of(context).pop();

                              if (success) {
                                final backupFiles = await autoBackupProvider.getBackupFiles();
                                dialogService.showResultDialog(
                                  context,
                                  'Backup Complete',
                                  'Your data has been backed up successfully.\n\nBackup location:\n${autoBackupProvider.backupFolderPath}\n\nTotal backups: ${backupFiles.length}',
                                );
                              } else {
                                final errorMessage = autoBackupProvider.lastError ??
                                    'Failed to create backup. Please check:\n- Folder path is valid\n- You have write permissions\n- Enough disk space available';
                                dialogService.showResultDialog(
                                  context,
                                  'Backup Failed',
                                  errorMessage,
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              dialogService.showResultDialog(
                                context,
                                'Backup Error',
                                'An error occurred: ${e.toString()}',
                              );
                            }
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(
                      vertical: 14.h,
                      horizontal: 20.w,
                    ),
                    minimumSize: const Size(double.infinity, 0),
                    side: BorderSide(
                      color: autoBackupProvider.backupFolderPath == null
                          ? Theme.of(context).colorScheme.outline
                          : Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                    textStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    foregroundColor: autoBackupProvider.backupFolderPath == null
                        ? Theme.of(context).colorScheme.outline
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),

                if (autoBackupProvider.backupFolderPath != null) ...[
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      'Keeps last 7 daily backups',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (dateToCheck == today.subtract(const Duration(days: 1))) {
      return 'Yesterday at ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(date);
    }
  }
}
