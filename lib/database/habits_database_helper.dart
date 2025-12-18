import 'dart:developer' as developer;
import 'dart:io';
import 'package:betullarise/model/habit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class HabitsDatabaseHelper {
  // Database name and table
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 2;
  static const tableHabits = 'habits';

  // Column definitions
  static const columnId = 'id';
  static const columnTitle = 'title';
  static const columnDescription = 'description';
  static const columnScore = 'score';
  static const columnPenalty = 'penalty';
  static const columnType = 'type';
  static const columnCreatedTime = 'created_time';
  static const columnUpdatedTime = 'updated_time';
  static const columnShowStreak = 'show_streak';

  // Habit completions table
  static const tableHabitCompletions = 'habit_completions';
  static const columnHabitId = 'habit_id';
  static const columnCompletionTime = 'completion_time';
  static const columnPoints = 'points';

  // Singleton instance
  HabitsDatabaseHelper._privateConstructor();
  static final HabitsDatabaseHelper instance =
      HabitsDatabaseHelper._privateConstructor();

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
      developer.log("get database chiamato", name: "HABITS");
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
      name: "HABITS",
    );

    if (oldVersion < 2) {
      // Add show_streak column to habits table
      await db.execute(
        'ALTER TABLE $tableHabits ADD COLUMN $columnShowStreak INTEGER NOT NULL DEFAULT 0',
      );
      developer.log("Added show_streak column to habits table", name: "HABITS");
    }
  }

  // Create table in the database
  Future _onCreate(Database db, int version) async {
    developer.log("Creating database tables", name: "HABITS");
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHabits (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnScore REAL NOT NULL,
        $columnPenalty REAL NOT NULL,
        $columnType TEXT NOT NULL,
        $columnCreatedTime INTEGER NOT NULL,
        $columnUpdatedTime INTEGER NOT NULL,
        $columnShowStreak INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableHabitCompletions (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnHabitId INTEGER NOT NULL,
        $columnCompletionTime INTEGER NOT NULL,
        $columnPoints REAL NOT NULL,
        FOREIGN KEY ($columnHabitId) REFERENCES $tableHabits ($columnId)
      )
    ''');
    developer.log("Tables created successfully", name: "HABITS");
  }

  // Make sure the habit table exists when we open the database
  Future _onOpen(Database db) async {
    // Verifica in modo corretto l'esistenza della tabella habits
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableHabits],
    );
    if (tables.isEmpty) {
      await _onCreate(db, _databaseVersion);
    }

    // Verifica in modo corretto l'esistenza della tabella habit_completions
    final completionsTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableHabitCompletions],
    );
    if (completionsTables.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableHabitCompletions (
          $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
          $columnHabitId INTEGER NOT NULL,
          $columnCompletionTime INTEGER NOT NULL,
          $columnPoints REAL NOT NULL,
          FOREIGN KEY ($columnHabitId) REFERENCES $tableHabits ($columnId)
        )
      ''');
    }
  }

  Future<bool> _doesTableExist(Database db, String tableName) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableHabits],
    );
    return tables.isNotEmpty;
  }

  // Insert a new habit
  Future<int> insertHabit(Habit habit) async {
    Database db = await instance.database;
    // Check if the table exists before inserting
    bool exists = await _doesTableExist(db, tableHabits);
    if (!exists) {
      // The table doesn't exist, create it
      await _onCreate(db, _databaseVersion);
    }
    return await db.insert(tableHabits, habit.toMap());
  }

  // Query all habits
  Future<List<Habit>> queryAllHabits() async {
    Database db = await instance.database;
    // Check if the table exists before querying
    bool exists = await _doesTableExist(db, tableHabits);
    if (!exists) {
      return [];
    }
    final List<Map<String, dynamic>> maps = await db.query(tableHabits);
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }

  // Update an existing habit
  Future<int> updateHabit(Habit habit) async {
    Database db = await instance.database;

    return await db.update(
      tableHabits,
      habit.toMap(),
      where: '$columnId = ?',
      whereArgs: [habit.id],
    );
  }

  // Check if habit has streak (completed yesterday and today)
  Future<bool> hasStreak(int habitId) async {
    Database db = await instance.database;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Convert to milliseconds since epoch for the query
    final todayStart = today.millisecondsSinceEpoch;
    final todayEnd = today.add(const Duration(days: 1)).millisecondsSinceEpoch;
    final yesterdayStart = yesterday.millisecondsSinceEpoch;
    final yesterdayEnd = todayStart;

    // Check for today's completion
    final todayResults = await db.query(
      tableHabitCompletions,
      where:
          '$columnHabitId = ? AND $columnCompletionTime >= ? AND $columnCompletionTime < ?',
      whereArgs: [habitId, todayStart, todayEnd],
      limit: 1,
    );

    // Check for yesterday's completion
    final yesterdayResults = await db.query(
      tableHabitCompletions,
      where:
          '$columnHabitId = ? AND $columnCompletionTime >= ? AND $columnCompletionTime < ?',
      whereArgs: [habitId, yesterdayStart, yesterdayEnd],
      limit: 1,
    );

    return todayResults.isNotEmpty && yesterdayResults.isNotEmpty;
  }

  // Delete a habit by id
  Future<int> deleteHabit(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableHabits,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Query a specific habit by id
  Future<Habit?> queryHabitById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableHabits,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Habit.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Query habits by type
  Future<List<Habit>> queryHabitsByType(String type) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableHabits,
      where: '$columnType = ?',
      whereArgs: [type],
    );
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }

  // Insert a new habit completion
  Future<int> insertHabitCompletion(int habitId, double points) async {
    Database db = await instance.database;
    final completionTime = DateTime.now().millisecondsSinceEpoch;

    return await db.insert(tableHabitCompletions, {
      columnHabitId: habitId,
      columnCompletionTime: completionTime,
      columnPoints: points,
    });
  }

  // Get the latest completion for a specific habit
  Future<Map<String, dynamic>?> getLatestHabitCompletion(int habitId) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableHabitCompletions,
      where: '$columnHabitId = ?',
      whereArgs: [habitId],
      orderBy: '$columnCompletionTime DESC',
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  // Get all completions for a specific habit (for history)
  Future<List<Map<String, dynamic>>> getHabitCompletionHistory(
    int habitId,
  ) async {
    Database db = await instance.database;
    return await db.query(
      tableHabitCompletions,
      where: '$columnHabitId = ?',
      whereArgs: [habitId],
      orderBy: '$columnCompletionTime DESC',
    );
  }

  // Delete a habit completion (for undo functionality)
  Future<int> deleteHabitCompletion(int completionId) async {
    Database db = await instance.database;
    return await db.delete(
      tableHabitCompletions,
      where: '$columnId = ?',
      whereArgs: [completionId],
    );
  }
}
