import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'widgets/interface_section_widget.dart';
import 'widgets/data_management_section_widget.dart';
import 'widgets/auto_backup_section_widget.dart';
import 'widgets/info_support_section_widget.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(fontSize: 20.sp)),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const InterfaceSectionWidget(),
            SizedBox(height: 24.h),
            DataManagementSectionWidget(
              exportImportService: DatabaseExportImportService(),
              dialogService: DialogService(),
            ),
            SizedBox(height: 24.h),
            AutoBackupSectionWidget(
              dialogService: DialogService(),
            ),
            SizedBox(height: 24.h),
            const InfoSupportSectionWidget(),
          ],
        ),
      ),
    );
  }
}
