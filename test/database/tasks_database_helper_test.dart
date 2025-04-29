import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
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
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late MockPathProviderPlatform mockPathProvider;

  setUpAll(() {
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;
  });

  group('TasksDatabaseHelper Tests', () {
    late TasksDatabaseHelper dbHelper;
    late Task testTask;

    setUp(() async {
      dbHelper = TasksDatabaseHelper.instance;
      testTask = Task(
        id: null,
        title: 'Test Task',
        description: 'This is a test task',
        deadline: DateTime.now().add(Duration(days: 1)).millisecondsSinceEpoch,
        completionTime: 0,
        score: 10.0,
        penalty: 5.0,
        createdTime: DateTime.now().millisecondsSinceEpoch,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );
      await _cleanDatabase(dbHelper);
    });

    test('Database should be initialized properly', () async {
      final db = await dbHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('Insert task should return a valid ID', () async {
      final id = await dbHelper.insertTask(testTask);
      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('Query all tasks should return correct number of records', () async {
      await dbHelper.insertTask(testTask);
      final tasks = await dbHelper.queryAllTasks();
      expect(tasks.length, 1);
      expect(tasks[0].title, equals(testTask.title));
      expect(tasks[0].description, equals(testTask.description));
      expect(tasks[0].score, equals(testTask.score));
      expect(tasks[0].penalty, equals(testTask.penalty));
    });

    test('Query task by ID should return correct task', () async {
      final id = await dbHelper.insertTask(testTask);
      final task = await dbHelper.queryTaskById(id);
      expect(task, isNotNull);
      expect(task!.id, equals(id));
      expect(task.title, equals(testTask.title));
    });

    test('Update task should change values in database', () async {
      final id = await dbHelper.insertTask(testTask);
      final task = await dbHelper.queryTaskById(id);
      expect(task, isNotNull);
      final updatedTask = task!.copyWith(
        title: 'Updated Title',
        score: 15.0,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );
      final rowsAffected = await dbHelper.updateTask(updatedTask);
      expect(rowsAffected, 1);
      final updatedRecord = await dbHelper.queryTaskById(id);
      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.title, equals('Updated Title'));
      expect(updatedRecord.score, equals(15.0));
    });

    test('Delete task should remove record from database', () async {
      final id = await dbHelper.insertTask(testTask);
      var task = await dbHelper.queryTaskById(id);
      expect(task, isNotNull);
      final rowsAffected = await dbHelper.deleteTask(id);
      expect(rowsAffected, 1);
      task = await dbHelper.queryTaskById(id);
      expect(task, isNull);
    });

    test('Empty database should return empty list', () async {
      await _cleanDatabase(dbHelper);
      final tasks = await dbHelper.queryAllTasks();
      expect(tasks.length, 0);
    });
  });
}

Future<void> _cleanDatabase(TasksDatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  await db.delete(TasksDatabaseHelper.tableTasks);
}
