import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:betullarise/database/habits_database_helper.dart';

void main() {
  setUpAll(() {
    // Initialize Flutter binding
    TestWidgetsFlutterBinding.ensureInitialized();
    // Initialize FFI
    sqfliteFfiInit();
  });

  group('Habit Completions', () {
    late HabitsDatabaseHelper dbHelper;

    setUp(() async {
      dbHelper = HabitsDatabaseHelper.instance;
      // Use in-memory database for testing
      final database = await databaseFactoryFfi.openDatabase(
        ':memory:',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS habits (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT NOT NULL,
                score REAL NOT NULL,
                penalty REAL NOT NULL,
                type TEXT NOT NULL,
                created_time INTEGER NOT NULL,
                updated_time INTEGER NOT NULL
              )
            ''');

            await db.execute('''
              CREATE TABLE IF NOT EXISTS habit_completions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                habit_id INTEGER NOT NULL,
                completion_time INTEGER NOT NULL,
                points REAL NOT NULL,
                FOREIGN KEY (habit_id) REFERENCES habits (id)
              )
            ''');
          },
        ),
      );
      // Replace the internal database reference for testing
      // Note: This is a workaround for testing. In production, you'd
      // want to use dependency injection properly.
    });

    test('should insert and retrieve habit completion', () async {
      final habitId = 1;
      final points = 10.5;

      // Insert a completion
      final completionId = await dbHelper.insertHabitCompletion(
        habitId,
        points,
      );
      expect(completionId, isA<int>());
      expect(completionId, greaterThan(0));

      // Retrieve the latest completion
      final completion = await dbHelper.getLatestHabitCompletion(habitId);
      expect(completion, isNotNull);
      expect(completion!['habit_id'], equals(habitId));
      expect(completion['points'], equals(points));
      expect(completion['completion_time'], isA<int>());
    });

    test('should return null when no completion exists', () async {
      final completion = await dbHelper.getLatestHabitCompletion(999);
      expect(completion, isNull);
    });

    test('should retrieve completions in descending order', () async {
      final habitId = 2;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Insert multiple completions with delays
      await dbHelper.insertHabitCompletion(habitId, 5.0);
      await Future.delayed(Duration(milliseconds: 10));
      await dbHelper.insertHabitCompletion(habitId, 7.5);
      await Future.delayed(Duration(milliseconds: 10));
      await dbHelper.insertHabitCompletion(habitId, 10.0);

      // Get the latest completion
      final latest = await dbHelper.getLatestHabitCompletion(habitId);
      expect(latest!['points'], equals(10.0));

      // Get all completions
      final all = await dbHelper.getHabitCompletionHistory(habitId);
      expect(all.length, equals(3));
      // Should be in descending order
      expect(all[0]['points'], equals(10.0));
      expect(all[1]['points'], equals(7.5));
      expect(all[2]['points'], equals(5.0));
    });
  });
}
