import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class PointsDatabaseHelper {
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 1;
  static const tablePoints = 'points';

  // Definizione dei campi
  static const columnTaskId = 'task_id';
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
    if (_database != null) return _database!;
    // Se il database non è stato ancora inizializzato, crealo
    _database = await _initDatabase();
    return _database!;
  }

  // Inizializza il database
  Future<Database> _initDatabase() async {
    await _initPlatformSpecific();

    String path;

    if (Platform.isMacOS) {
      // Su macOS, utilizziamo il percorso dei documenti
      final documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, _databaseName);

      // Utilizza databaseFactoryFfi per macOS
      return await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _databaseVersion,
          onOpen: _onOpen,
        ),
      );
    } else {
      final databasePath = await getDatabasesPath();
      path = join(databasePath, _databaseName);
      return await openDatabase(
        path,
        version: _databaseVersion,
        onOpen: _onOpen,
      );
    }
  }

  // Assicuriamo che la tabella points esista quando apriamo il database
  Future _onOpen(Database db) async {
    // Verifichiamo se la tabella points esiste
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tablePoints'",
    );

    if (tables.isEmpty) {
      // La tabella non esiste, la creiamo
      await db.execute('''
        CREATE TABLE $tablePoints (
          $columnTaskId INTEGER PRIMARY KEY,
          $columnPoints REAL NOT NULL,
          $columnInsertTime INTEGER NOT NULL
        )
      ''');
    }
  }

  // Inserimento di un nuovo Point
  Future<int> insertPoint(Point point) async {
    Database db = await instance.database;
    return await db.insert(tablePoints, point.toMap());
  }

  // Eliminazione di punti per id
  Future<int> deletePoint(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tablePoints,
      where: '$columnTaskId = ?',
      whereArgs: [id],
    );
  }

  // Calcolo del totale dei punti
  Future<double> getTotalPoints() async {
    Database db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM($columnPoints) as total FROM $tablePoints',
    );

    // Gestione del caso in cui non ci sono punti nel database
    final total = result.first['total'];
    return total == null ? 0.0 : double.parse(total.toString());
  }

  // Query per ottenere un Point specifico tramite id
  Future<Point?> queryPointById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tablePoints,
      where: '$columnTaskId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Point.fromMap(maps.first);
    } else {
      return null;
    }
  }
}
