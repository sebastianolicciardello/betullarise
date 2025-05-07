import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:betullarise/features/settings/widgets/app_version_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppVersionWidget', () {
    late PackageInfo mockPackageInfo;

    setUp(() {
      mockPackageInfo = PackageInfo(
        appName: 'Betullarise',
        packageName: 'com.example.betullarise',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    testWidgets('shows loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppVersionWidget(
              getPackageInfoOverride: () async => mockPackageInfo,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows version info when loaded', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppVersionWidget(
              getPackageInfoOverride: () async => mockPackageInfo,
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Version 1.0.0 (1)'), findsOneWidget);
    });

    testWidgets('shows error message on error', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppVersionWidget(
              getPackageInfoOverride: () async => throw Exception('Test error'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester
          .pump(); // Un pump aggiuntivo per permettere al FutureBuilder di gestire l'errore

      expect(find.text('Error loading package info'), findsOneWidget);
    });
  });
}
