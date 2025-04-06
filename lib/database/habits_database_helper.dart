import 'dart:io';
import 'package:betullarise/model/habit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class HabitsDatabaseHelper {
  // Nome del database e tabella
  static const _databaseName = 'betullarise.db';
  static const _databaseVersion = 1;
  static const tableHabits = 'habits';

  // Definizione dei campi
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

  // Assicuriamo che la tabella habits esista quando apriamo il database
  Future _onOpen(Database db) async {
    // Verifichiamo se la tabella habits esiste
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableHabits'",
    );

    if (tables.isEmpty) {
      // La tabella non esiste, la creiamo
      await db.execute('''
        CREATE TABLE $tableHabits (
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
    }
  }

  // Inserimento di un nuovo Habit
  Future<int> insertHabit(Habit habit) async {
    Database db = await instance.database;
    return await db.insert(tableHabits, habit.toMap());
  }

  // Query per ottenere tutti gli Habits
  Future<List<Habit>> queryAllHabits() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableHabits);
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }

  // Aggiornamento di un Habit esistente
  Future<int> updateHabit(Habit habit) async {
    Database db = await instance.database;
    return await db.update(
      tableHabits,
      habit.toMap(),
      where: '$columnId = ?',
      whereArgs: [habit.id],
    );
  }

  // Eliminazione di un Habit per id
  Future<int> deleteHabit(int id) async {
    Database db = await instance.database;
    return await db.delete(
      tableHabits,
      where: '$columnId = ?',
      whereArgs: [id],
    );
  }

  // Query per ottenere un Habit specifico tramite id
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

  // Query per ottenere Habits filtrati per tipo
  Future<List<Habit>> queryHabitsByType(String type) async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableHabits,
      where: '$columnType = ?',
      whereArgs: [type],
    );
    return List.generate(maps.length, (i) => Habit.fromMap(maps[i]));
  }
}
