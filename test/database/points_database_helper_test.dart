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
  });
}

Future<void> _cleanDatabase(PointsDatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  await db.delete(PointsDatabaseHelper.tablePoints);
}
