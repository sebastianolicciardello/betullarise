import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/point.dart';
import 'package:betullarise/database/points_database_helper.dart';
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

  group('PointsDatabaseHelper Tests', () {
    late PointsDatabaseHelper dbHelper;
    late Point testPoint;

    setUp(() async {
      dbHelper = PointsDatabaseHelper.instance;
      testPoint = Point(
        id: null,
        referenceId: 1,
        type: 'task',
        points: 10.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );
      await _cleanDatabase(dbHelper);
    });

    test('Database should be initialized properly', () async {
      final db = await dbHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('Insert point should return a valid ID', () async {
      final id = await dbHelper.insertPoint(testPoint);
      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('Query all points should return correct number of records', () async {
      await dbHelper.insertPoint(testPoint);
      final points = await dbHelper.getAllPoints();
      expect(points.length, 1);
      expect(points[0].referenceId, equals(testPoint.referenceId));
      expect(points[0].type, equals(testPoint.type));
      expect(points[0].points, equals(testPoint.points));
    });

    test(
      'Query point by reference and type should return correct point',
      () async {
        await dbHelper.insertPoint(testPoint);
        final point = await dbHelper.queryPointByReferenceAndType(
          testPoint.referenceId!,
          testPoint.type,
        );
        expect(point, isNotNull);
        expect(point!.referenceId, equals(testPoint.referenceId));
        expect(point.type, equals(testPoint.type));
      },
    );

    test('Update point should change values in database', () async {
      await dbHelper.insertPoint(testPoint);
      final updatedPoint = testPoint.copyWith(
        points: 20.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );
      await dbHelper.insertPoint(
        updatedPoint,
      ); // update logic is inside insertPoint for tasks
      final point = await dbHelper.queryPointByReferenceAndType(
        testPoint.referenceId!,
        testPoint.type,
      );
      expect(point, isNotNull);
      expect(point!.points, equals(20.0));
    });

    test('Delete point should remove record from database', () async {
      await dbHelper.insertPoint(testPoint);
      final rowsAffected = await dbHelper.deletePoint(
        testPoint.referenceId!,
        testPoint.type,
      );
      expect(rowsAffected, greaterThan(0));
      final point = await dbHelper.queryPointByReferenceAndType(
        testPoint.referenceId!,
        testPoint.type,
      );
      expect(point, isNull);
    });

    test('Empty database should return empty list', () async {
      await _cleanDatabase(dbHelper);
      final points = await dbHelper.getAllPoints();
      expect(points.length, 0);
    });

    test('Get total points should return correct sum', () async {
      // Insert multiple points
      await dbHelper.insertPoint(testPoint);
      await dbHelper.insertPoint(Point(
        referenceId: 2,
        type: 'task',
        points: 20.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      ));

      final total = await dbHelper.getTotalPoints();
      expect(total, equals(30.0));
    });

    test('Get total points by type should return correct sum', () async {
      // Insert points of different types
      await dbHelper.insertPoint(testPoint); // task type
      await dbHelper.insertPoint(Point(
        referenceId: 2,
        type: 'habit',
        points: 15.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      ));
      await dbHelper.insertPoint(Point(
        referenceId: 3,
        type: 'task',
        points: 25.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      ));

      final taskPoints = await dbHelper.getTotalPointsByType('task');
      final habitPoints = await dbHelper.getTotalPointsByType('habit');

      expect(taskPoints, equals(35.0)); // 10 + 25
      expect(habitPoints, equals(15.0));
    });

    test('Get points by type should return correct points', () async {
      // Insert points of different types
      await dbHelper.insertPoint(testPoint); // task type
      await dbHelper.insertPoint(Point(
        referenceId: 2,
        type: 'habit',
        points: 15.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      ));

      final taskPoints = await dbHelper.getPointsByType('task');
      final habitPoints = await dbHelper.getPointsByType('habit');

      expect(taskPoints.length, equals(1));
      expect(taskPoints[0].type, equals('task'));
      expect(taskPoints[0].points, equals(10.0));

      expect(habitPoints.length, equals(1));
      expect(habitPoints[0].type, equals('habit'));
      expect(habitPoints[0].points, equals(15.0));
    });

    test('Delete point undo should remove specific point entry', () async {
      final insertTime = DateTime.now().millisecondsSinceEpoch;
      final point = Point(
        referenceId: 1,
        type: 'habit', // Changed to habit to avoid update logic in insertPoint
        points: 10.0,
        insertTime: insertTime,
      );
      
      await dbHelper.insertPoint(point);
      
      // Add another point with same reference and type but different insert time
      await dbHelper.insertPoint(Point(
        referenceId: 1,
        type: 'habit',
        points: 15.0,
        insertTime: insertTime + 1000, // different insert time
      ));

      // Delete the first point using deletePointUndo
      final rowsAffected = await dbHelper.deletePointUndo(1, 'habit', insertTime);
      expect(rowsAffected, equals(1));

      // Verify only the specific point was deleted
      final remainingPoints = await dbHelper.getAllPoints();
      expect(remainingPoints.length, equals(1));
      expect(remainingPoints[0].insertTime, equals(insertTime + 1000));
    });

    test('Query points by reference ID only positive tasks should work correctly', () async {
      // Insert a task point first to avoid update logic
      final positivePoint = Point(
        referenceId: 1,
        type: 'task',
        points: 10.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );
      await dbHelper.insertPoint(positivePoint);

      // Insert a negative task points as a separate record
      final negativePoint = Point(
        referenceId: 1,
        type: 'task',
        points: -5.0,
        insertTime: DateTime.now().millisecondsSinceEpoch + 1000,
      );
      
      // Use raw insert to bypass the update logic in insertPoint
      final dbInstance = await dbHelper.database;
      await dbInstance.insert(PointsDatabaseHelper.tablePoints, negativePoint.toMap());

      // Query should only return the positive points
      final point = await dbHelper.queryPointByReferenceIdOnlyPositiveTasks(1);
      
      expect(point, isNotNull);
      expect(point!.points, equals(10.0));
      expect(point.type, equals('task'));
    });
  });
}

Future<void> _cleanDatabase(PointsDatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  await db.delete(PointsDatabaseHelper.tablePoints);
}
