import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/features/habits/habits_page.dart';
import 'package:betullarise/features/habits/habit_detail_page.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/database/habits_database_helper.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Generate mocks
@GenerateMocks([HabitsDatabaseHelper, PointsProvider])
import 'habits_page_test.mocks.dart';

void main() {
  late MockHabitsDatabaseHelper mockDbHelper;
  late MockPointsProvider mockPointsProvider;

  setUp(() {
    mockDbHelper = MockHabitsDatabaseHelper();
    mockPointsProvider = MockPointsProvider();
    // Set up default behavior for mockDbHelper
    when(mockDbHelper.queryAllHabits()).thenAnswer((_) async => []);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<PointsProvider>(
            create: (_) => mockPointsProvider,
          ),
        ],
        child: HabitsPage(dbHelper: mockDbHelper),
      ),
    );
  }

  group('HabitsPage Widget Tests', () {
    testWidgets('shows loading indicator initially', (
      WidgetTester tester,
    ) async {
      // Act
      await tester.pumpWidget(createWidgetUnderTest());

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no habits exist', (
      WidgetTester tester,
    ) async {
      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('No habits created'), findsOneWidget);
      expect(find.byIcon(Icons.loop_rounded), findsOneWidget);
    });

    testWidgets('shows list of habits when habits exist', (
      WidgetTester tester,
    ) async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch;
      final habits = [
        Habit(
          id: 1,
          title: 'Test Habit 1',
          description: 'Description 1',
          type: 'single',
          score: 10.0,
          penalty: 5.0,
          createdTime: now,
          updatedTime: now,
        ),
        Habit(
          id: 2,
          title: 'Test Habit 2',
          description: 'Description 2',
          type: 'multipler',
          score: 20.0,
          penalty: 10.0,
          createdTime: now,
          updatedTime: now,
        ),
      ];
      when(mockDbHelper.queryAllHabits()).thenAnswer((_) async => habits);

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('Test Habit 1'), findsOneWidget);
      expect(find.text('Test Habit 2'), findsOneWidget);
      expect(find.text('Description 1'), findsOneWidget);
      expect(find.text('Description 2'), findsOneWidget);
    });

    testWidgets('search functionality filters habits', (
      WidgetTester tester,
    ) async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch;
      final habits = [
        Habit(
          id: 1,
          title: 'Running',
          description: 'Daily run',
          type: 'single',
          score: 10.0,
          penalty: 5.0,
          createdTime: now,
          updatedTime: now,
        ),
        Habit(
          id: 2,
          title: 'Reading',
          description: 'Read books',
          type: 'single',
          score: 20.0,
          penalty: 10.0,
          createdTime: now,
          updatedTime: now,
        ),
      ];
      when(mockDbHelper.queryAllHabits()).thenAnswer((_) async => habits);

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Search for "Running"
      await tester.enterText(find.byType(TextField), 'Running');
      await tester.pump(const Duration(milliseconds: 500));

      // Assert: trova solo il Text "Running" che non è nel campo di input
      final runningTexts = find.descendant(
        of: find.byType(Card),
        matching: find.text('Running'),
      );
      expect(runningTexts, findsOneWidget);
      expect(find.text('Reading'), findsNothing);
    });

    testWidgets('floating action button is present', (
      WidgetTester tester,
    ) async {
      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('habit completion shows snackbar', (WidgetTester tester) async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch;
      final habit = Habit(
        id: 1,
        title: 'Test Habit',
        description: 'Test Description',
        type: 'single',
        score: 10.0,
        penalty: 0.0,
        createdTime: now,
        updatedTime: now,
      );
      when(mockDbHelper.queryAllHabits()).thenAnswer((_) async => [habit]);

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the completion button
      await tester.tap(find.byIcon(Icons.circle_outlined));
      await tester.pump(const Duration(milliseconds: 500));

      // Assert
      expect(find.text('Good job! +10.0 points'), findsOneWidget);
      expect(find.text('UNDO'), findsOneWidget);
    });

    testWidgets('habit card tap navigates to detail page', (
      WidgetTester tester,
    ) async {
      // Arrange
      final now = DateTime.now().millisecondsSinceEpoch;
      final habit = Habit(
        id: 1,
        title: 'Test Habit',
        description: 'Test Description',
        type: 'single',
        score: 10.0,
        penalty: 0.0,
        createdTime: now,
        updatedTime: now,
      );
      when(mockDbHelper.queryAllHabits()).thenAnswer((_) async => [habit]);

      // Act
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(const Duration(milliseconds: 500));

      // Tap the habit card (usa il Card)
      await tester.tap(find.widgetWithText(Card, 'Test Habit'));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Assert
      expect(find.byType(HabitDetailPage), findsOneWidget);
    });
  });
}
