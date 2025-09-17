import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';
import 'app_version_widget.dart';

class InfoSupportSectionWidget extends StatelessWidget {
  const InfoSupportSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Info & Support',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            const AppVersionWidget(),
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              icon: Icon(Icons.bug_report, size: 20.sp),
              label: const Text('Report a Bug'),
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
                  borderRadius: BorderRadius.circular(8.r),
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
                  await Clipboard.setData(
                    const ClipboardData(text: 's.licciardello.dev@proton.me'),
                  );
                  if (context.mounted) {
                    SnackbarService.showSnackbar(
                      context,
                      'Email address copied to clipboard. Please paste it in your email client.',
                    );
                  }
                }
              },
            ),
            SizedBox(height: 12.h),
            OutlinedButton.icon(
              icon: Icon(Icons.code, size: 20.sp),
              label: const Text('Source Code'),
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
              onPressed: () async {
                final Uri githubUrl = Uri.parse(
                  'https://github.com/sebastianolicciardello/betullarise',
                );
                try {
                  final launched = await launchUrl(
                    githubUrl,
                    mode: LaunchMode.platformDefault,
                  );
                  if (!launched && context.mounted) {
                    SnackbarService.showErrorSnackbar(
                      context,
                      'Unable to open GitHub page.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    SnackbarService.showErrorSnackbar(
                      context,
                      'Unable to open GitHub page.',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}