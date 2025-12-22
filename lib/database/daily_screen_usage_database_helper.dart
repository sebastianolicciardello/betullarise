import 'dart:developer' as developer;
import 'dart:io';
import 'package:betullarise/model/daily_screen_usage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class DailyScreenUsageDatabaseHelper {
  // Database name and table
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 2; // Update version for migration
  static const tableDailyScreenUsage = 'daily_screen_usage';

  // Column definitions
  static const columnId = 'id';
  static const columnRuleId = 'rule_id';
  static const columnDate = 'date';
  static const columnTotalUsageMinutes = 'total_usage_minutes';
  static const columnExceededMinutes = 'exceeded_minutes';
  static const columnCalculatedPenalty = 'calculated_penalty';
  static const columnPenaltyConfirmed = 'penalty_confirmed';
  static const columnPenaltyConfirmedAt = 'penalty_confirmed_at';

  // Singleton instance
  DailyScreenUsageDatabaseHelper._privateConstructor();
  static final DailyScreenUsageDatabaseHelper instance =
      DailyScreenUsageDatabaseHelper._privateConstructor();

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
      developer.log("get database chiamato", name: "DAILY_SCREEN_USAGE");
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
      name: "DAILY_SCREEN_USAGE",
    );

    if (oldVersion < 2) {
      // Create daily screen usage table for the first time
      await _onCreate(db, newVersion);
      developer.log(
        "Created daily screen usage table in upgrade",
        name: "DAILY_SCREEN_USAGE",
      );
    }
  }

  // Create table in the database
  Future _onCreate(Database db, int version) async {
    developer.log(
      "Creating daily screen usage table",
      name: "DAILY_SCREEN_USAGE",
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableDailyScreenUsage (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnRuleId INTEGER NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnTotalUsageMinutes INTEGER NOT NULL DEFAULT 0,
        $columnExceededMinutes INTEGER NOT NULL DEFAULT 0,
        $columnCalculatedPenalty REAL NOT NULL DEFAULT 0.0,
        $columnPenaltyConfirmed INTEGER NOT NULL DEFAULT 0,
        $columnPenaltyConfirmedAt INTEGER,
        UNIQUE($columnRuleId, $columnDate)
      )
    ''');
    developer.log(
      "Daily screen usage table created successfully",
      name: "DAILY_SCREEN_USAGE",
    );
  }

  // Make sure the table exists when we open the database
  Future _onOpen(Database db) async {
    // Verifica l'esistenza della tabella daily_screen_usage
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableDailyScreenUsage],
    );
    if (tables.isEmpty) {
      await _onCreate(db, _databaseVersion);
    }
  }

  Future<bool> _doesTableExist(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableDailyScreenUsage],
    );
    return tables.isNotEmpty;
  }

  // Insert or update daily screen usage (UPSERT)
  Future<int> insertOrUpdateDailyScreenUsage(DailyScreenUsage usage) async {
    Database db = await instance.database;
    // Check if the table exists before inserting
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      // The table doesn't exist, create it
      await _onCreate(db, _databaseVersion);
    }

    // Try to update first, if no rows affected then insert
    final existingUsage = await queryDailyUsageByRuleAndDate(
      usage.ruleId,
      usage.date,
    );
    if (existingUsage != null) {
      usage.id = existingUsage.id;
      return await updateDailyScreenUsage(usage);
    } else {
      return await insertDailyScreenUsage(usage);
    }
  }

  // Insert a new daily screen usage
  Future<int> insertDailyScreenUsage(DailyScreenUsage usage) async {
    Database db = await instance.database;
    return await db.insert(tableDailyScreenUsage, usage.toMap());
  }

  // Update an existing daily screen usage
  Future<int> updateDailyScreenUsage(DailyScreenUsage usage) async {
    Database db = await instance.database;
    return await db.update(
      tableDailyScreenUsage,
      usage.toMap(),
      where: '$columnId = ?',
      whereArgs: [usage.id],
    );
  }

  // Query daily usage by rule and date
  Future<DailyScreenUsage?> queryDailyUsageByRuleAndDate(
    int ruleId,
    String date,
  ) async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return null;
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyScreenUsage,
      where: '$columnRuleId = ? AND $columnDate = ?',
      whereArgs: [ruleId, date],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return DailyScreenUsage.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Query all daily usage for a specific rule
  Future<List<DailyScreenUsage>> queryDailyUsageByRule(
    int ruleId, {
    int limitDays = 30,
  }) async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyScreenUsage,
      where: '$columnRuleId = ?',
      whereArgs: [ruleId],
      orderBy: '$columnDate DESC',
      limit: limitDays,
    );

    return List.generate(maps.length, (i) => DailyScreenUsage.fromMap(maps[i]));
  }

  // Query confirmed daily usage for a specific rule
  Future<List<DailyScreenUsage>> queryConfirmedDailyUsageByRule(
    int ruleId,
  ) async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyScreenUsage,
      where: '$columnRuleId = ? AND $columnPenaltyConfirmed = ?',
      whereArgs: [ruleId, 1],
      orderBy: '$columnDate DESC',
    );

    return List.generate(maps.length, (i) => DailyScreenUsage.fromMap(maps[i]));
  }

  // Query all unconfirmed daily usage (chronological order)
  Future<List<DailyScreenUsage>> queryUnconfirmedDailyUsage() async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyScreenUsage,
      where: '$columnPenaltyConfirmed = ? AND $columnCalculatedPenalty < ?',
      whereArgs: [0, 0], // Not confirmed and has penalty
      orderBy: '$columnDate ASC', // Oldest first
    );

    return List.generate(maps.length, (i) => DailyScreenUsage.fromMap(maps[i]));
  }

  // Query all daily usage for a specific date range
  Future<List<DailyScreenUsage>> queryDailyUsageByDateRange(
    String startDate,
    String endDate,
  ) async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return [];
    }

    final List<Map<String, dynamic>> maps = await db.query(
      tableDailyScreenUsage,
      where: '$columnDate >= ? AND $columnDate <= ?',
      whereArgs: [startDate, endDate],
      orderBy: '$columnDate DESC',
    );

    return List.generate(maps.length, (i) => DailyScreenUsage.fromMap(maps[i]));
  }

  // Confirm penalty for a specific daily usage
  Future<int> confirmPenalty(DailyScreenUsage usage) async {
    Database db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.update(
      tableDailyScreenUsage,
      {columnPenaltyConfirmed: 1, columnPenaltyConfirmedAt: now},
      where: '$columnId = ?',
      whereArgs: [usage.id],
    );
  }

  // Delete daily usage older than specified days (cleanup)
  Future<int> deleteOldDailyUsage({int daysToKeep = 30}) async {
    Database db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    final cutoffDateString = _formatDate(cutoffDate);

    return await db.delete(
      tableDailyScreenUsage,
      where: '$columnDate < ?',
      whereArgs: [cutoffDateString],
    );
  }

  // Get total penalty for a specific period
  Future<double> getTotalPenaltyForPeriod(
    String startDate,
    String endDate,
  ) async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return 0.0;
    }

    final result = await db.rawQuery(
      '''
      SELECT SUM($columnCalculatedPenalty) as total_penalty
      FROM $tableDailyScreenUsage
      WHERE $columnDate >= ? AND $columnDate <= ? AND $columnPenaltyConfirmed = 1
    ''',
      [startDate, endDate],
    );

    if (result.isNotEmpty && result.first['total_penalty'] != null) {
      return (result.first['total_penalty'] as double)
          .abs(); // Return absolute value
    }
    return 0.0;
  }

  // Format date as YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Get statistics for a rule in the last N days
  Future<Map<String, dynamic>> getRuleStatistics(
    int ruleId, {
    int days = 30,
  }) async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableDailyScreenUsage);
    if (!exists) {
      return {
        'totalDays': 0,
        'totalUsageMinutes': 0,
        'totalExceededMinutes': 0,
        'totalPenalty': 0.0,
        'daysWithPenalty': 0,
        'averageDailyUsage': 0.0,
      };
    }

    final startDate = _formatDate(
      DateTime.now().subtract(Duration(days: days)),
    );
    final endDate = _formatDate(DateTime.now());

    final result = await db.rawQuery(
      '''
      SELECT
        COUNT(*) as total_days,
        SUM($columnTotalUsageMinutes) as total_usage_minutes,
        SUM($columnExceededMinutes) as total_exceeded_minutes,
        SUM($columnCalculatedPenalty) as total_penalty,
        COUNT(CASE WHEN $columnCalculatedPenalty < 0 AND $columnPenaltyConfirmed = 1 THEN 1 END) as days_with_penalty
      FROM $tableDailyScreenUsage
      WHERE $columnRuleId = ? AND $columnDate >= ? AND $columnDate <= ? AND $columnPenaltyConfirmed = 1
    ''',
      [ruleId, startDate, endDate],
    );

    if (result.isNotEmpty) {
      final data = result.first;
      final totalDays = data['total_days'] as int? ?? 0;

      return {
        'totalDays': totalDays,
        'totalUsageMinutes': data['total_usage_minutes'] as int? ?? 0,
        'totalExceededMinutes': data['total_exceeded_minutes'] as int? ?? 0,
        'totalPenalty': (data['total_penalty'] as double? ?? 0.0).abs(),
        'daysWithPenalty': data['days_with_penalty'] as int? ?? 0,
        'averageDailyUsage':
            totalDays > 0
                ? (data['total_usage_minutes'] as int? ?? 0) / totalDays
                : 0.0,
      };
    }

    return {
      'totalDays': 0,
      'totalUsageMinutes': 0,
      'totalExceededMinutes': 0,
      'totalPenalty': 0.0,
      'daysWithPenalty': 0,
      'averageDailyUsage': 0.0,
    };
  }
}
