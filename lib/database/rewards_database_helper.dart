import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:betullarise/model/reward.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:developer' as developer;

class RewardsDatabaseHelper {
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 1;
  static const tableRewards = 'rewards';

  // Column definitions
  static const columnId = 'id';
  static const columnTitle = 'title';
  static const columnDescription = 'description';
  static const columnType = 'type';
  static const columnPoints = 'points';
  static const columnInsertTime = 'insert_time';
  static const columnUpdateTime = 'update_time';

  // Singleton instance
  RewardsDatabaseHelper._privateConstructor();
  static final RewardsDatabaseHelper instance =
      RewardsDatabaseHelper._privateConstructor();

  static Database? _database;

  // Initialize platform-specific support
  Future<void> _initPlatformSpecific() async {
    if (Platform.isMacOS) {
      // Initialize sqflite_ffi for macOS
      sqfliteFfiInit();
    }
  }

  Future<Database> get database async {
    try {
      developer.log("get database chiamato", name: "REWARDS");
      if (_database != null) return _database!;
      // If database hasn't been initialized yet, create it
      _database = await _initDatabase();
      return _database!;
    } catch (e, stackTrace) {
      developer.log(
        "Errore in get database: $e\n$stackTrace",
        name: "DATABASE_ERROR",
      );
      rethrow;
    }
  }

  // Initialize the database
  Future<Database> _initDatabase() async {
    try {
      await _initPlatformSpecific();

      String path = await getDatabasePath();

      if (Platform.isMacOS) {
        try {
          // Use databaseFactoryFfi for macOS
          return await databaseFactoryFfi.openDatabase(
            path,
            options: OpenDatabaseOptions(
              version: _databaseVersion,
              onOpen: _onOpen,
              onCreate: _onCreate,
            ),
          );
        } catch (e, stack) {
          developer.log(
            "Errore apertura DB su macOS: $e\n$stack",
            name: "DATABASE_ERROR",
          );
          rethrow;
        }
      } else {
        return await openDatabase(
          path,
          version: _databaseVersion,
          onOpen: _onOpen,
          onCreate: _onCreate,
        );
      }
    } catch (e, stack) {
      developer.log(
        "Errore in _initDatabase: $e\n$stack",
        name: "DATABASE_ERROR",
      );
      rethrow;
    }
  }

  Future<String> getDatabasePath() async {
    if (Platform.isMacOS) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return join(documentsDirectory.path, _databaseName);
    } else {
      final databasePath = await getDatabasesPath();
      return join(databasePath, _databaseName);
    }
  }

  // Create the new table schema if it doesn't exist
  Future _onCreate(Database db, int version) async {
    developer.log("Creating rewards table", name: "REWARDS");
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableRewards (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnType TEXT NOT NULL,
        $columnPoints REAL NOT NULL,
        $columnInsertTime INTEGER NOT NULL,
        $columnUpdateTime INTEGER NOT NULL
      )
    ''');
    developer.log("Rewards table created successfully", name: "REWARDS");
  }

  // Make sure the rewards table exists when we open the database
  Future _onOpen(Database db) async {
    final tablesTest = await db.rawQuery("PRAGMA table_info($tableRewards)");
    developer.log("Columns in rewards table: $tablesTest", name: "REWARDS");

    // Check if the rewards table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableRewards'",
    );

    if (tables.isEmpty) {
      // The table doesn't exist, create it
      await _onCreate(db, _databaseVersion);
    }
  }

  Future<bool> _doesTableExist(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return tables.isNotEmpty;
  }

  // Insert a new Reward
  Future<int> insertReward(Reward reward) async {
    Database db = await instance.database;
    return await db.insert(tableRewards, reward.toMap());
  }

  // Update an existing Reward
  Future<int> updateReward(Reward reward) async {
    if (reward.id == null) return 0;

    Database db = await instance.database;
    return await db.update(
      tableRewards,
      reward.toMap(),
      where: '$columnId = ?',
      whereArgs: [reward.id],
    );
  }

  // Delete a reward by ID
  Future<int> deleteReward(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableRewards,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Get a reward by ID
  Future<Reward?> getRewardById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableRewards,
      where: '$columnId = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Reward.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Get all rewards
  Future<List<Reward>> getAllRewards() async {
    Database db = await instance.database;

    // Check if table exists
    bool tableExists = await _doesTableExist(db, tableRewards);
    if (!tableExists) {
      developer.log(
        "Rewards table doesn't exist, creating it",
        name: "DATABASE",
      );
      await _onCreate(db, _databaseVersion);
      return [];
    }

    final maps = await db.query(tableRewards);
    return maps.map((map) => Reward.fromMap(map)).toList();
  }
}
