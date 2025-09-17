import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            const AppVersionWidget(),
            SizedBox(height: 24.h),
            const ThemeSelectorWidget(),
            SizedBox(height: 24.h),
            DataManagementWidget(
              exportImportService: DatabaseExportImportService(),
              dialogService: DialogService(),
            ),
            SizedBox(height: 24.h),
            OutlinedButton.icon(
              icon: Icon(Icons.bug_report, size: 20.sp),
              label: Text('Report a Bug'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: 14.h,
                  horizontal: 20.w,
                ),
                minimumSize: const Size(double.infinity, 0),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 1.5,
                ),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.r),
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
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              icon: Icon(Icons.code, size: 20.sp),
              label: Text('Source Code'),
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
                  borderRadius: BorderRadius.circular(30.r),
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
