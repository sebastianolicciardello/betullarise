import 'package:flutter/material.dart';
import 'widgets/app_version_widget.dart';
import 'widgets/theme_selector_widget.dart';
import 'widgets/data_management_widget.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppVersionWidget(),
            const SizedBox(height: 40),
            const ThemeSelectorWidget(),
            const SizedBox(height: 40),
            DataManagementWidget(
              exportImportService: DatabaseExportImportService(),
              dialogService: DialogService(),
            ),
          ],
        ),
      ),
    );
  }
}
