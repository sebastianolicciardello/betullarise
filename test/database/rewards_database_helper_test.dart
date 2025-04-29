import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/reward.dart';
import 'package:betullarise/database/rewards_database_helper.dart';
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

  group('RewardsDatabaseHelper Tests', () {
    late RewardsDatabaseHelper dbHelper;
    late Reward testReward;

    setUp(() async {
      dbHelper = RewardsDatabaseHelper.instance;
      testReward = Reward(
        id: null,
        title: 'Test Reward',
        description: 'This is a test reward',
        type: 'single',
        points: 10.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
        updateTime: DateTime.now().millisecondsSinceEpoch,
      );
      await _cleanDatabase(dbHelper);
    });

    test('Database should be initialized properly', () async {
      final db = await dbHelper.database;
      expect(db, isNotNull);
      expect(db.isOpen, isTrue);
    });

    test('Insert reward should return a valid ID', () async {
      final id = await dbHelper.insertReward(testReward);
      expect(id, isNotNull);
      expect(id, greaterThan(0));
    });

    test('Query all rewards should return correct number of records', () async {
      await dbHelper.insertReward(testReward);
      final rewards = await dbHelper.getAllRewards();
      expect(rewards.length, 1);
      expect(rewards[0].title, equals(testReward.title));
      expect(rewards[0].description, equals(testReward.description));
      expect(rewards[0].points, equals(testReward.points));
      expect(rewards[0].type, equals(testReward.type));
    });

    test('Query reward by ID should return correct reward', () async {
      final id = await dbHelper.insertReward(testReward);
      final reward = await dbHelper.getRewardById(id);
      expect(reward, isNotNull);
      expect(reward!.id, equals(id));
      expect(reward.title, equals(testReward.title));
    });

    test('Update reward should change values in database', () async {
      final id = await dbHelper.insertReward(testReward);
      final reward = await dbHelper.getRewardById(id);
      expect(reward, isNotNull);
      final updatedReward = reward!.copyWith(
        title: 'Updated Title',
        points: 15.0,
        updateTime: DateTime.now().millisecondsSinceEpoch,
      );
      final rowsAffected = await dbHelper.updateReward(updatedReward);
      expect(rowsAffected, 1);
      final updatedRecord = await dbHelper.getRewardById(id);
      expect(updatedRecord, isNotNull);
      expect(updatedRecord!.title, equals('Updated Title'));
      expect(updatedRecord.points, equals(15.0));
    });

    test('Delete reward should remove record from database', () async {
      final id = await dbHelper.insertReward(testReward);
      var reward = await dbHelper.getRewardById(id);
      expect(reward, isNotNull);
      final rowsAffected = await dbHelper.deleteReward(id);
      expect(rowsAffected, 1);
      reward = await dbHelper.getRewardById(id);
      expect(reward, isNull);
    });

    test('Empty database should return empty list', () async {
      await _cleanDatabase(dbHelper);
      final rewards = await dbHelper.getAllRewards();
      expect(rewards.length, 0);
    });
  });
}

Future<void> _cleanDatabase(RewardsDatabaseHelper dbHelper) async {
  final db = await dbHelper.database;
  await db.delete(RewardsDatabaseHelper.tableRewards);
}
