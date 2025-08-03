import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'widgets/app_version_widget.dart';
import 'widgets/theme_selector_widget.dart';
import 'widgets/data_management_widget.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:betullarise/services/ui/dialog_service.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor:
            Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
      ),
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
            const SizedBox(height: 40),
            OutlinedButton.icon(
              icon: const Icon(Icons.bug_report),
              label: const Text('Report a Bug'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                minimumSize: const Size(double.infinity, 0),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1.5,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                final Uri emailLaunchUri = Uri(
                  scheme: 'mailto',
                  path: 's.licciardello.dev@proton.me',
                  query: Uri.encodeFull(
                    'subject=Bug Report&body=Describe the bug you encountered:',
                  ),
                );
                if (await canLaunchUrl(emailLaunchUri)) {
                  await launchUrl(emailLaunchUri);
                } else {
                  // Fallback: copy the email address to clipboard and show a message
                  await Clipboard.setData(
                    const ClipboardData(text: 's.licciardello.dev@proton.me'),
                  );
                  SnackbarService.showSnackbar(
                    // ignore: use_build_context_synchronously
                    context,
                    'Email address copied to clipboard. Please paste it in your email client.',
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.code),
              label: const Text('Source Code'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 20,
                ),
                minimumSize: const Size(double.infinity, 0),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () async {
                final Uri githubUrl = Uri.parse(
                  'https://github.com/sebastianolicciardello/betullarise',
                );
                // Try directly launchUrl with try/catch for Android 15 compatibility
                try {
                  final launched = await launchUrl(
                    githubUrl,
                    mode: LaunchMode.platformDefault,
                  );
                  if (!launched) {
                    SnackbarService.showErrorSnackbar(
                      // ignore: use_build_context_synchronously
                      context,
                      'Impossibile aprire la pagina GitHub.',
                    );
                  }
                } catch (e) {
                  SnackbarService.showErrorSnackbar(
                    // ignore: use_build_context_synchronously
                    context,
                    'Impossibile aprire la pagina GitHub.',
                  );
                }
              },
            ),
          ], // chiude Column children
        ),
      ),
    );
  }
}
