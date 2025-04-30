import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betullarise/provider/theme_notifier.dart';

// Generiamo il mock per SharedPreferences
@GenerateMocks([SharedPreferences])
import 'theme_notifier_test.mocks.dart';

void main() {
  late ThemeNotifier themeNotifier;
  late MockSharedPreferences mockPrefs;

  setUpAll(() {
    // Inizializziamo il binding di Flutter per i test
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    // Inizializziamo il mock di SharedPreferences
    mockPrefs = MockSharedPreferences();
    // Configuriamo il mock per restituire un set vuoto di chiavi di default
    when(mockPrefs.getKeys()).thenReturn({});
    // Mockiamo SharedPreferences.getInstance() per restituire il nostro mock
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeNotifier', () {
    testWidgets('initializes with system theme by default', (tester) async {
      // Configuriamo il mock per restituire null come tema salvato
      SharedPreferences.setMockInitialValues({});

      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Verifichiamo che il tema iniziale sia system
      expect(themeNotifier.themeMode, equals(ThemeMode.system));
    });

    testWidgets('loads light theme from preferences', (tester) async {
      // Configuriamo il mock per restituire 'light' come tema salvato
      SharedPreferences.setMockInitialValues({'themeMode': 'light'});

      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Verifichiamo che il tema sia light
      expect(themeNotifier.themeMode, equals(ThemeMode.light));
    });

    testWidgets('loads dark theme from preferences', (tester) async {
      // Configuriamo il mock per restituire 'dark' come tema salvato
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});

      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Verifichiamo che il tema sia dark
      expect(themeNotifier.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('saves light theme to preferences', (tester) async {
      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Cambiamo il tema in light
      await themeNotifier.setThemeMode(ThemeMode.light);

      // Verifichiamo che il tema sia stato salvato correttamente
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), equals('light'));
      expect(themeNotifier.themeMode, equals(ThemeMode.light));
    });

    testWidgets('saves dark theme to preferences', (tester) async {
      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Cambiamo il tema in dark
      await themeNotifier.setThemeMode(ThemeMode.dark);

      // Verifichiamo che il tema sia stato salvato correttamente
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), equals('dark'));
      expect(themeNotifier.themeMode, equals(ThemeMode.dark));
    });

    testWidgets('saves system theme to preferences', (tester) async {
      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Cambiamo il tema in system
      await themeNotifier.setThemeMode(ThemeMode.system);

      // Verifichiamo che il tema sia stato salvato correttamente
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('themeMode'), equals('system'));
      expect(themeNotifier.themeMode, equals(ThemeMode.system));
    });

    testWidgets('notifies listeners when theme changes', (tester) async {
      // Creiamo il notifier con il mock
      themeNotifier = ThemeNotifier();

      // Attendiamo che il tema venga caricato
      await tester.pumpAndSettle();

      // Creiamo un flag per verificare se i listener sono stati notificati
      var notified = false;
      themeNotifier.addListener(() => notified = true);

      // Cambiamo il tema
      await themeNotifier.setThemeMode(ThemeMode.light);

      // Verifichiamo che i listener siano stati notificati
      expect(notified, isTrue);
    });
  });
}
