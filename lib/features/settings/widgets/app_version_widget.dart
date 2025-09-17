import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionWidget extends StatelessWidget {
  final Future<PackageInfo> Function()? getPackageInfoOverride;

  const AppVersionWidget({super.key, this.getPackageInfoOverride});

  Future<PackageInfo> _getPackageInfo() async {
    if (getPackageInfoOverride != null) {
      return getPackageInfoOverride!();
    }
    return await PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
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
            style: TextStyle(fontSize: 16.sp),
          );
        }
        return const Text('No data');
      },
    );
  }
}
