import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/database/habits_database_helper.dart'; // Assicurati che il percorso sia corretto
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

// Mock per Path Provider
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String> getApplicationDocumentsPath() async {
    return Directory.systemTemp.createTempSync('app_docs_dir').path;
  }

  @override
  Future<String> getTemporaryPath() async {
    return Directory.systemTemp.createTempSync('temp_dir').path;
  }
}

void main() {
  // Imposta il factory per sqflite_ffi
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // Path Provider Mock Setup
  late MockPathProviderPlatform mockPathProvider;

  setUpAll(() {
    // Registra il mock per PathProviderPlatform
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;
  });

  // Gruppo di test per il database helper
  group('HabitsDatabaseHelper Tests', () {
    late HabitsDatabaseHelper dbHelper;
    late Habit testHabit;

    setUp(() async {
      // Inizializza il database helper
      dbHelper = HabitsDatabaseHelper.instance;

      // Configura un habit di test
      testHabit = Habit(
        id: null, // Sarà assegnato dal database
        title: 'Test Habit',
        description: 'This is a test habit',
        score: 10.0,
        penalty: 5.0,
        type: 'single',
        createdTime: DateTime.now().millisecondsSinceEpoch,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Assicurati che il database sia pulito prima di ogni test
      await _cleanDatabase(dbHelper);
    });

    test('Database should be initialized properly', () async {
      final db = await dbHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('Insert habit should return a valid ID', () async {
      final id = await dbHelper.insertHabit(testHabit);
      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('Query all habits should return correct number of records', () async {
      // Insert a test habit
      await dbHelper.insertHabit(testHabit);

      // Query all habits
      final habits = await dbHelper.queryAllHabits();

      // Verify we have exactly one habit
      expect(habits.length, 1);
      expect(habits[0].title, equals(testHabit.title));
      expect(habits[0].description, equals(testHabit.description));
      expect(habits[0].score, equals(testHabit.score));
      expect(habits[0].penalty, equals(testHabit.penalty));
      expect(habits[0].type, equals(testHabit.type));
    });

    test('Query habit by ID should return correct habit', () async {
      // Insert a test habit and get its ID
      final id = await dbHelper.insertHabit(testHabit);

      // Query habit by ID
      final habit = await dbHelper.queryHabitById(id);

      // Verify the habit matches
      expect(habit, isNotNull);
      expect(habit!.id, equals(id));
      expect(habit.title, equals(testHabit.title));
    });

    test('Update habit should change values in database', () async {
      // Insert a test habit and get its ID
      final id = await dbHelper.insertHabit(testHabit);

      // Get the habit to update
      final habit = await dbHelper.queryHabitById(id);
      expect(habit, isNotNull);

      // Update the habit - usando il metodo copyWith per sicurezza
      final updatedHabit = habit!.copyWith(
        title: 'Updated Title',
        score: 15.0,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Perform update
      final rowsAffected = await dbHelper.updateHabit(updatedHabit);
      expect(rowsAffected, 1);

      // Verify the update
      final updatedRecord = await dbHelper.queryHabitById(id);
      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.title, equals('Updated Title'));
      expect(updatedRecord.score, equals(15.0));
    });

    test('Delete habit should remove record from database', () async {
      // Insert a test habit and get its ID
      final id = await dbHelper.insertHabit(testHabit);

      // Verify habit exists
      var habit = await dbHelper.queryHabitById(id);
      expect(habit, isNotNull);

      // Delete the habit
      final rowsAffected = await dbHelper.deleteHabit(id);
      expect(rowsAffected, 1);

      // Verify habit no longer exists
      habit = await dbHelper.queryHabitById(id);
      expect(habit, isNull);
    });

    test('Query habits by type should return correct records', () async {
      // Insert habits with different types
      final singleHabit = Habit(
        id: null,
        title: 'Single Habit',
        description: 'A single habit',
        score: 10.0,
        penalty: 5.0,
        type: 'single',
        createdTime: DateTime.now().millisecondsSinceEpoch,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      final multiplerHabit = Habit(
        id: null,
        title: 'Multipler Habit',
        description: 'A multipler habit',
        score: 20.0,
        penalty: 10.0,
        type: 'multipler',
        createdTime: DateTime.now().millisecondsSinceEpoch,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      final counterHabit = Habit(
        id: null,
        title: 'Counter Habit',
        description: 'A counter habit',
        score: 15.0,
        penalty: 7.5,
        type: 'counter',
        createdTime: DateTime.now().millisecondsSinceEpoch,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      await dbHelper.insertHabit(singleHabit);
      await dbHelper.insertHabit(multiplerHabit);
      await dbHelper.insertHabit(counterHabit);

      // Query habits by type
      final singleHabits = await dbHelper.queryHabitsByType('single');
      expect(singleHabits.length, 1);
      expect(singleHabits[0].title, equals('Single Habit'));

      final multiplerHabits = await dbHelper.queryHabitsByType('multipler');
      expect(multiplerHabits.length, 1);
      expect(multiplerHabits[0].title, equals('Multipler Habit'));

      final counterHabits = await dbHelper.queryHabitsByType('counter');
      expect(counterHabits.length, 1);
      expect(counterHabits[0].title, equals('Counter Habit'));
    });

    test('Empty database should return empty list', () async {
      // Ensure database is empty
      await _cleanDatabase(dbHelper);

      // Query all habits
      final habits = await dbHelper.queryAllHabits();

      // Verify we have no habits
      expect(habits.length, 0);
    });

    test('Creating habit with invalid type should throw assertion error', () {
      // Attempt to create a habit with an invalid type
      expect(
        () => Habit(
          id: null,
          title: 'Invalid Habit',
          description: 'This habit has an invalid type',
          score: 10.0,
          penalty: 5.0,
          type: 'invalid_type', // Tipo non valido
          createdTime: DateTime.now().millisecondsSinceEpoch,
          updatedTime: DateTime.now().millisecondsSinceEpoch,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('Creating habit with all valid types should not throw', () {
    final validTypes = [
      'single',
      'singleWithPenalty',
      'singleWithScore',
      'multipler',
      'multiplerWithScore',
      'multiplerWithPenalty',
      'counter',
    ];

    for (final type in validTypes) {
      expect(
        () => Habit(
          id: null,
          title: '$type Habit',
          description: 'This is a $type habit',
          score: 10.0,
          penalty: 5.0,
          type: type,
          createdTime: DateTime.now().millisecondsSinceEpoch,
          updatedTime: DateTime.now().millisecondsSinceEpoch,
        ),
        isNot(throwsA(anything)),
        reason: 'Type "$type" dovrebbe essere accettato',
      );
    }
  });
}

// Helper per pulire il database tra i test
Future<void> _cleanDatabase(HabitsDatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  await db.delete('habits');
}
