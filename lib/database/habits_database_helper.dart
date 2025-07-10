import 'dart:developer' as developer;
import 'dart:io';
import 'package:betullarise/model/habit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class HabitsDatabaseHelper {
  // Database name and table
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 1;
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
        $columnUpdatedTime INTEGER NOT NULL
      )
    ''');
    developer.log("Table created successfully", name: "HABITS");
  }

  // Make sure the habit table exists when we open the database
  Future _onOpen(Database db) async {
    // Verifica in modo corretto l'esistenza della tabella
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableHabits],
    );
    if (tables.isEmpty) {
      await _onCreate(db, _databaseVersion);
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
}
