import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/features/tasks/pages/task_detail_page.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/model/point.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:betullarise/database/points_database_helper.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/services/ui/dialog_service.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

@GenerateMocks([
  TasksDatabaseHelper,
  PointsDatabaseHelper,
  PointsProvider,
  DialogService,
])
import 'task_detail_page_test.mocks.dart';

void main() {
  late MockTasksDatabaseHelper mockTasksDbHelper;
  late MockPointsDatabaseHelper mockPointsDbHelper;
  late MockPointsProvider mockPointsProvider;
  late MockDialogService mockDialogService;

  setUp(() {
    mockTasksDbHelper = MockTasksDatabaseHelper();
    mockPointsDbHelper = MockPointsDatabaseHelper();
    mockPointsProvider = MockPointsProvider();
    mockDialogService = MockDialogService();

    // Set up default dialog responses
    when(
      mockDialogService.showConfirmDialog(
        any,
        any,
        any,
        confirmText: anyNamed('confirmText'),
        cancelText: anyNamed('cancelText'),
        isDangerous: anyNamed('isDangerous'),
      ),
    ).thenAnswer((_) async => true);
  });

  Widget createWidgetUnderTest({Task? task}) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<PointsProvider>.value(
            value: mockPointsProvider,
          ),
          Provider<DialogService>.value(value: mockDialogService),
        ],
        child: TaskDetailPage(
          task: task,
          dbHelper: mockTasksDbHelper,
          pointsDbHelper: mockPointsDbHelper,
          dialogService: mockDialogService,
        ),
      ),
    );
  }

  Task createTestTask({
    int? id,
    String title = 'Test Task',
    String description = 'Test Description',
    required int deadline,
    double score = 10,
    double penalty = 5,
    int completionTime = 0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Task(
      id: id,
      title: title,
      description: description,
      deadline: deadline,
      score: score,
      penalty: penalty,
      completionTime: completionTime,
      createdTime: now,
      updatedTime: now,
    );
  }

  group('TaskDetailPage - Initial State', () {
    testWidgets('shows correct title for new task', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('New Task'), findsOneWidget);
    });

    testWidgets('shows correct title for existing task', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        deadline: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      expect(find.text('Edit Task'), findsOneWidget);
    });

    testWidgets('validates required fields', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Try to save without filling required fields
      await tester.tap(find.text('Save Task'));
      await tester.pump();

      expect(find.text('Write a title'), findsOneWidget);
      expect(find.text('Insert a score'), findsOneWidget);
      expect(find.text('Insert a penalty'), findsOneWidget);
    });
  });

  group('TaskDetailPage - Task Creation', () {
    testWidgets('creates new task successfully', (WidgetTester tester) async {
      when(mockTasksDbHelper.insertTask(any)).thenAnswer((_) async => 1);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Fill in the form
      await tester.enterText(find.byType(TextFormField).first, 'New Task');
      await tester.enterText(find.byType(TextFormField).at(2), '10');
      await tester.enterText(find.byType(TextFormField).at(3), '5');

      // Save the task
      await tester.tap(find.text('Save Task'));
      await tester.pump();

      verify(mockTasksDbHelper.insertTask(any)).called(1);
    });
  });

  group('TaskDetailPage - Task Editing', () {
    testWidgets('edits existing task successfully', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        id: 1,
        deadline: DateTime.now().millisecondsSinceEpoch,
      );

      when(mockTasksDbHelper.updateTask(any)).thenAnswer((_) async => 1);

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      // Modify the task
      await tester.enterText(find.byType(TextFormField).first, 'Updated Task');
      await tester.enterText(find.byType(TextFormField).at(2), '20');
      await tester.enterText(find.byType(TextFormField).at(3), '10');

      // Save the changes
      await tester.tap(find.text('Update Task'));
      await tester.pump();

      verify(mockTasksDbHelper.updateTask(any)).called(1);
    });
  });

  group('TaskDetailPage - Task Deletion', () {
    testWidgets('shows delete confirmation dialog', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        id: 1,
        deadline: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      // Tap delete button
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();

      verify(
        mockDialogService.showConfirmDialog(
          any,
          'Delete Task',
          'Are you sure you want to delete "Test Task"?\n\n',
          confirmText: 'Delete',
          cancelText: 'Cancel',
          isDangerous: true,
        ),
      ).called(1);
    });
  });

  group('TaskDetailPage - Task Rescheduling', () {
    testWidgets('shows reschedule confirmation for completed task', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        id: 1,
        deadline: DateTime.now().millisecondsSinceEpoch,
        completionTime: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      // Try to reschedule
      await tester.tap(find.text('Reschedule Task'));
      await tester.pump();

      verify(
        mockDialogService.showConfirmDialog(
          any,
          'Reschedule Completed Task',
          any,
          confirmText: 'Reschedule',
          cancelText: 'Cancel',
          isDangerous: true,
        ),
      ).called(1);
    });
  });

  group('TaskDetailPage - Field Validation', () {
    testWidgets('validates negative score', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await tester.enterText(find.byType(TextFormField).at(2), '-10');
      await tester.enterText(find.byType(TextFormField).at(3), '5');

      await tester.tap(find.text('Save Task'));
      await tester.pump();

      expect(find.text('Insert a valid score'), findsOneWidget);
    });

    testWidgets('validates negative penalty', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await tester.enterText(find.byType(TextFormField).at(2), '10');
      await tester.enterText(find.byType(TextFormField).at(3), '-5');

      await tester.tap(find.text('Save Task'));
      await tester.pump();

      expect(find.text('Insert a valid penalty'), findsOneWidget);
    });

    testWidgets('validates non-numeric score', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await tester.enterText(find.byType(TextFormField).at(2), 'abc');
      await tester.enterText(find.byType(TextFormField).at(3), '5');

      await tester.tap(find.text('Save Task'));
      await tester.pump();

      expect(find.text('Insert a valid score'), findsOneWidget);
    });
  });

  group('TaskDetailPage - Deadline Validation', () {
    testWidgets('validates past deadline', (WidgetTester tester) async {
      // Set deadline to yesterday
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final task = createTestTask(deadline: yesterday.millisecondsSinceEpoch);

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await tester.enterText(find.byType(TextFormField).at(2), '10');
      await tester.enterText(find.byType(TextFormField).at(3), '5');

      await tester.tap(find.text('Update Task'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // SnackBar animation

      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text(
          'The deadline must be at least today. Please select a valid date.',
        ),
        findsOneWidget,
      );
    });
  });

  group('TaskDetailPage - Points Management', () {
    testWidgets('subtracts points when rescheduling completed task', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        id: 1,
        deadline: DateTime.now().millisecondsSinceEpoch,
        completionTime: DateTime.now().millisecondsSinceEpoch,
        score: 10,
      );

      final point = Point(
        id: 1,
        referenceId: 1,
        type: 'task',
        points: 10,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );

      when(
        mockPointsDbHelper.queryPointByReferenceIdOnlyPositiveTasks(1),
      ).thenAnswer((_) async => point);

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      // Scroll to make sure the button is visible
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      await tester.tap(find.text('Reschedule Task'));
      await tester.pump();

      verify(mockPointsProvider.removePointsByEntity(point)).called(1);
    });

    testWidgets('subtracts points when canceling completed task', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        id: 1,
        deadline: DateTime.now().millisecondsSinceEpoch,
        completionTime: DateTime.now().millisecondsSinceEpoch,
        score: 10,
      );

      final point = Point(
        id: 1,
        referenceId: 1,
        type: 'task',
        points: 10,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );

      when(
        mockPointsDbHelper.queryPointByReferenceIdOnlyPositiveTasks(1),
      ).thenAnswer((_) async => point);

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      // Scroll to make sure the button is visible
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pump();

      await tester.tap(find.text('Cancel Task'));
      await tester.pump();

      verify(mockPointsProvider.removePointsByEntity(point)).called(1);
    });
  });

  group('TaskDetailPage - Error Handling', () {
    testWidgets('handles database error when saving task', (
      WidgetTester tester,
    ) async {
      when(
        mockTasksDbHelper.insertTask(any),
      ).thenThrow(Exception('Database error'));

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.enterText(find.byType(TextFormField).first, 'Test Task');
      await tester.enterText(find.byType(TextFormField).at(2), '10');
      await tester.enterText(find.byType(TextFormField).at(3), '5');

      await tester.tap(find.text('Save Task'));
      await tester.pump();

      expect(find.text('Errore: Exception: Database error'), findsOneWidget);
    });

    testWidgets('handles database error when deleting task', (
      WidgetTester tester,
    ) async {
      final task = createTestTask(
        id: 1,
        deadline: DateTime.now().millisecondsSinceEpoch,
      );

      when(
        mockTasksDbHelper.deleteTask(1),
      ).thenThrow(Exception('Database error'));

      await tester.pumpWidget(createWidgetUnderTest(task: task));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.delete));
      await tester.pump();

      expect(
        find.text('Error deleting task: Exception: Database error'),
        findsOneWidget,
      );
    });
  });

  group('TaskDetailPage - Unsaved Changes Handling', () {
    testWidgets('shows discard changes dialog when editing and pressing back', (
      WidgetTester tester,
    ) async {
      // Use the real DialogService to show the actual dialog
      final realDialogService = DialogService();
      Widget createWidgetWithRealDialogService() {
        return MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<PointsProvider>.value(
                value: mockPointsProvider,
              ),
              Provider<DialogService>.value(value: realDialogService),
            ],
            child: TaskDetailPage(
              dbHelper: mockTasksDbHelper,
              pointsDbHelper: mockPointsDbHelper,
              dialogService: realDialogService,
            ),
          ),
        );
      }

      await tester.pumpWidget(createWidgetWithRealDialogService());
      await tester.pumpAndSettle();
      // Modifica un campo
      await tester.enterText(find.byType(TextFormField).first, 'Changed title');
      await tester.pumpAndSettle();
      // Premi il tasto back nell'app bar
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      // Verifica che il dialog sia visibile
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(
        find.text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        findsOneWidget,
      );
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
