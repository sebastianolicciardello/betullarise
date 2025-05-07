import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/features/settings/settings_page.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/theme_notifier.dart';

void main() {
  testWidgets('SettingsPage should build correctly', (WidgetTester tester) async {
    // Build the widget with required providers
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeNotifier(),
        child: const MaterialApp(
          home: SettingsPage(),
        ),
      ),
    );

    // Verify basic structure
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}