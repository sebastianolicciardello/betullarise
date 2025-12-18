import 'dart:developer' as developer;
import 'dart:io';
import 'package:betullarise/model/screen_time_rule.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class ScreenTimeRulesDatabaseHelper {
  // Database name and table
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 2; // Update version for migration
  static const tableScreenTimeRules = 'screen_time_rules';

  // Column definitions
  static const columnId = 'id';
  static const columnName = 'name';
  static const columnAppPackages = 'app_packages';
  static const columnDailyTimeLimitMinutes = 'daily_time_limit_minutes';
  static const columnPenaltyPerMinuteExtra = 'penalty_per_minute_extra';
  static const columnIsActive = 'is_active';
  static const columnCreatedTime = 'created_time';
  static const columnUpdatedTime = 'updated_time';

  // Singleton instance
  ScreenTimeRulesDatabaseHelper._privateConstructor();
  static final ScreenTimeRulesDatabaseHelper instance =
      ScreenTimeRulesDatabaseHelper._privateConstructor();

  static Database? _database;

  // Initialize platform-specific settings
  Future<void> _initPlatformSpecific() async {
    if (Platform.isMacOS) {
      // Initialize sqflite_ffi for macOS
      sqfliteFfiInit();
    }
  }

  Future<Database> get database async {
    try {
      developer.log("get database chiamato", name: "SCREEN_TIME_RULES");
      if (_database != null) return _database!;
      // If the database has not been initialized yet, create it
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
              onUpgrade: _onUpgrade,
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
        final databasePath = await getDatabasesPath();
        path = join(databasePath, _databaseName);
        return await openDatabase(
          path,
          version: _databaseVersion,
          onOpen: _onOpen,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
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

  // Database upgrade method
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    developer.log(
      "Upgrading database from version $oldVersion to $newVersion",
      name: "SCREEN_TIME_RULES",
    );

    if (oldVersion < 2) {
      // Create screen time rules table for the first time
      await _onCreate(db, newVersion);
      developer.log(
        "Created screen time rules table in upgrade",
        name: "SCREEN_TIME_RULES",
      );
    }
  }

  // Create table in the database
  Future _onCreate(Database db, int version) async {
    developer.log(
      "Creating screen time rules table",
      name: "SCREEN_TIME_RULES",
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableScreenTimeRules (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnName TEXT NOT NULL,
        $columnAppPackages TEXT NOT NULL,
        $columnDailyTimeLimitMinutes INTEGER NOT NULL,
        $columnPenaltyPerMinuteExtra REAL NOT NULL,
        $columnIsActive INTEGER NOT NULL DEFAULT 1,
        $columnCreatedTime INTEGER NOT NULL,
        $columnUpdatedTime INTEGER NOT NULL
      )
    ''');
    developer.log(
      "Screen time rules table created successfully",
      name: "SCREEN_TIME_RULES",
    );
  }

  // Make sure the table exists when we open the database
  Future _onOpen(Database db) async {
    // Verifica l'esistenza della tabella screen_time_rules
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableScreenTimeRules],
    );
    if (tables.isEmpty) {
      await _onCreate(db, _databaseVersion);
    }
  }

  Future<bool> _doesTableExist(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableScreenTimeRules],
    );
    return tables.isNotEmpty;
  }

  // Insert a new screen time rule
  Future<int> insertScreenTimeRule(ScreenTimeRule rule) async {
    Database db = await instance.database;
    // Check if the table exists before inserting
    bool exists = await _doesTableExist(db, tableScreenTimeRules);
    if (!exists) {
      // The table doesn't exist, create it
      await _onCreate(db, _databaseVersion);
    }
    return await db.insert(tableScreenTimeRules, rule.toMap());
  }

  // Query all screen time rules
  Future<List<ScreenTimeRule>> queryAllScreenTimeRules() async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableScreenTimeRules);
    if (!exists) {
      return [];
    }
    final List<Map<String, dynamic>> maps = await db.query(
      tableScreenTimeRules,
      orderBy: '$columnName ASC',
    );
    return List.generate(maps.length, (i) => ScreenTimeRule.fromMap(maps[i]));
  }

  // Query only active screen time rules
  Future<List<ScreenTimeRule>> queryActiveScreenTimeRules() async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableScreenTimeRules);
    if (!exists) {
      return [];
    }
    final List<Map<String, dynamic>> maps = await db.query(
      tableScreenTimeRules,
      where: '$columnIsActive = ?',
      whereArgs: [1],
      orderBy: '$columnName ASC',
    );
    return List.generate(maps.length, (i) => ScreenTimeRule.fromMap(maps[i]));
  }

  // Query a specific screen time rule by id
  Future<ScreenTimeRule?> queryScreenTimeRuleById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableScreenTimeRules,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ScreenTimeRule.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Update an existing screen time rule
  Future<int> updateScreenTimeRule(ScreenTimeRule rule) async {
    Database db = await instance.database;

    return await db.update(
      tableScreenTimeRules,
      rule.toMap(),
      where: '$columnId = ?',
      whereArgs: [rule.id],
    );
  }

  // Delete a screen time rule by id
  Future<int> deleteScreenTimeRule(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableScreenTimeRules,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Toggle active status of a screen time rule
  Future<int> toggleScreenTimeRuleActive(int id, bool isActive) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      tableScreenTimeRules,
      {columnIsActive: isActive ? 1 : 0, columnUpdatedTime: now},
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Check if a rule name already exists (excluding the current rule if updating)
  Future<bool> ruleNameExists(String name, {int? excludeId}) async {
    Database db = await instance.database;

    String whereClause = '$columnName = ?';
    List<dynamic> whereArgs = [name];

    if (excludeId != null) {
      whereClause += ' AND $columnId != ?';
      whereArgs.add(excludeId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableScreenTimeRules,
      where: whereClause,
      whereArgs: whereArgs,
      limit: 1,
    );

    return maps.isNotEmpty;
  }
}
