import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:developer' as developer;

class PointsDatabaseHelper {
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 2;
  static const tablePoints = 'points';

  // Definizione dei campi
  static const columnId = 'id';
  static const columnReferenceId = 'reference_id';
  static const columnType = 'type';
  static const columnPoints = 'points';
  static const columnInsertTime = 'insert_time';

  // Singleton instance
  PointsDatabaseHelper._privateConstructor();
  static final PointsDatabaseHelper instance =
      PointsDatabaseHelper._privateConstructor();

  static Database? _database;

  // Inizializza il supporto per sqflite su macOS
  Future<void> _initPlatformSpecific() async {
    if (Platform.isMacOS) {
      // Inizializza sqflite_ffi per macOS
      sqfliteFfiInit();
    }
  }

  Future<Database> get database async {
    try {
      developer.log("get database chiamato", name: "POINTS");
      if (_database != null) return _database!;
      // Se il database non è stato ancora inizializzato, crealo
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

  // Inizializza il database
  Future<Database> _initDatabase() async {
    try {
      await _initPlatformSpecific();

      String path = await getDatabasePath();

      if (Platform.isMacOS) {
        try {
          // Utilizza databaseFactoryFfi per macOS
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
    developer.log("Creating database tables", name: "POINTS");
    await db.execute('''
      CREATE TABLE $tablePoints (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnReferenceId INTEGER NOT NULL,
        $columnType TEXT NOT NULL,
        $columnPoints REAL NOT NULL,
        $columnInsertTime INTEGER NOT NULL
      )
    ''');
    developer.log("Table created successfully", name: "POINTS");
  }

  // Make sure the points table exists when we open the database
  Future _onOpen(Database db) async {
    final tablesTest = await db.rawQuery("PRAGMA table_info($tablePoints)");
    developer.log("Columns in table: $tablesTest");

    // Check if the points table exists
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tablePoints'",
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

  // Insert a new Point
  Future<int> insertPoint(Point point) async {
    Database db = await instance.database;

    if (point.referenceId == null) return 0;

    // Per gli habits e i rewards, aggiungi sempre un nuovo record
    if (point.type == 'habit' || point.type == 'reward') {
      return await db.insert(tablePoints, point.toMap());
    } else {
      // Check if a point already exists for this reference and type
      final existing = await queryPointByReferenceAndType(
        point.referenceId!,
        point.type,
      );

      if (existing != null) {
        // Update the existing record
        return await db.update(
          tablePoints,
          {columnPoints: point.points, columnInsertTime: point.insertTime},
          where: '$columnReferenceId = ? AND $columnType = ?',
          whereArgs: [point.referenceId, point.type],
        );
      } else {
        // Insert a new record
        return await db.insert(tablePoints, point.toMap());
      }
    }
  }

  // Delete points by reference ID and type
  Future<int> deletePoint(int referenceId, String type) async {
    Database db = await instance.database;
    return await db.delete(
      tablePoints,
      where: '$columnReferenceId = ? AND $columnType = ?',
      whereArgs: [referenceId, type],
    );
  }

  // Calculate total points
  Future<double> getTotalPoints() async {
    Database db = await instance.database;

    // Check if table exists
    bool tableExists = await _doesTableExist(db, tablePoints);
    if (!tableExists) {
      developer.log("Table doesn't exist, creating it", name: "DATABASE");
      await _onCreate(db, _databaseVersion);
      return 0.0;
    }

    final result = await db.rawQuery(
      'SELECT SUM($columnPoints) as total FROM $tablePoints',
    );

    // Handle the case where there are no points in the database
    final total = result.first['total'];
    return total == null ? 0.0 : double.parse(total.toString());
  }

  // Query to get points by reference ID and type
  Future<Point?> queryPointByReferenceAndType(
    int referenceId,
    String type,
  ) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tablePoints,
      where: '$columnReferenceId = ? AND $columnType = ?',
      whereArgs: [referenceId, type],
    );
    if (maps.isNotEmpty) {
      return Point.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Query to get points by reference ID, only positive points tasks
  Future<Point?> queryPointByReferenceIdOnlyPositiveTasks(
    int referenceId,
  ) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tablePoints,
      where: '$columnReferenceId = ? AND $columnType = ? AND $columnPoints > 0',
      whereArgs: [referenceId, 'task'],
    );
    if (maps.isNotEmpty) {
      return Point.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Get total points by type
  Future<double> getTotalPointsByType(String type) async {
    Database db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM($columnPoints) as total FROM $tablePoints WHERE $columnType = ?',
      [type],
    );

    final total = result.first['total'];
    return total == null ? 0.0 : double.parse(total.toString());
  }

  // Get all points
  Future<List<Point>> getAllPoints() async {
    Database db = await instance.database;
    final maps = await db.query(tablePoints);
    return maps.map((map) => Point.fromMap(map)).toList();
  }

  // Get all points by type
  Future<List<Point>> getPointsByType(String type) async {
    Database db = await instance.database;
    final maps = await db.query(
      tablePoints,
      where: '$columnType = ?',
      whereArgs: [type],
    );
    return maps.map((map) => Point.fromMap(map)).toList();
  }
}
