import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionWidget extends StatelessWidget {
  const AppVersionWidget({super.key});

  Future<PackageInfo> _getPackageInfo() async {
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
            style: const TextStyle(fontSize: 16),
          );
        }
        return const Text('No data');
      },
    );
  }
}
