import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/theme_notifier.dart';
import 'package:betullarise/features/settings/widgets/theme_selector_widget.dart';
import '../../../widget_test_setup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeSelectorWidget', () {
    late ThemeNotifier themeNotifier;

    setUp(() async {
      await setUpWidgetTest();
      themeNotifier = ThemeNotifier();
    });

    testWidgets('shows all theme options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeNotifier>.value(
            value: themeNotifier,
            child: const Material(child: ThemeSelectorWidget()),
          ),
        ),
      );

      // Verify all options are present
      expect(find.text('Select theme:'), findsOneWidget);
      expect(find.text('Automatic'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('updates theme when option is selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<ThemeNotifier>.value(
            value: themeNotifier,
            child: const Material(child: ThemeSelectorWidget()),
          ),
        ),
      );

      // Default should be system theme
      expect(themeNotifier.themeMode, equals(ThemeMode.system));

      // Tap light theme option
      await tester.tap(find.text('Light'));
      await tester.pump();
      expect(themeNotifier.themeMode, equals(ThemeMode.light));

      // Tap dark theme option
      await tester.tap(find.text('Dark'));
      await tester.pump();
      expect(themeNotifier.themeMode, equals(ThemeMode.dark));

      // Tap automatic theme option
      await tester.tap(find.text('Automatic'));
      await tester.pump();
      expect(themeNotifier.themeMode, equals(ThemeMode.system));
    });
  });
}
