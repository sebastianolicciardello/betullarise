import 'dart:io';
import 'package:betullarise/model/task.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';

class TasksDatabaseHelper {
  // Nome del database e tabella
  static const _databaseName = 'tasks.db';
  static const _databaseVersion = 1;
  static const tableTasks = 'tasks';

  // Definizione dei campi
  static const columnId = 'id';
  static const columnTitle = 'title';
  static const columnDescription = 'description';
  static const columnDeadline = 'deadline';
  static const columnCompletionTime = 'completion_time';
  static const columnScore = 'score';
  static const columnPenalty = 'penalty';
  static const columnCreatedTime = 'created_time';
  static const columnUpdatedTime = 'updated_time';

  // Singleton instance
  TasksDatabaseHelper._privateConstructor();
  static final TasksDatabaseHelper instance =
      TasksDatabaseHelper._privateConstructor();

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
          onCreate: _onCreate,
        ),
      );
    } else {
      final databasePath = await getDatabasesPath();
      path = join(databasePath, _databaseName);
      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
      );
    }
  }

  // Crea la tabella nel database
  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableTasks (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnTitle TEXT NOT NULL,
        $columnDescription TEXT NOT NULL,
        $columnDeadline INTEGER NOT NULL,
        $columnCompletionTime INTEGER NOT NULL,
        $columnScore REAL NOT NULL,
        $columnPenalty REAL NOT NULL,
        $columnCreatedTime INTEGER NOT NULL,
        $columnUpdatedTime INTEGER NOT NULL
      )
    ''');
  }

  // Inserimento di un nuovo Task
  Future<int> insertTask(Task task) async {
    Database db = await instance.database;
    return await db.insert(tableTasks, task.toMap());
  }

  // Query per ottenere tutti i Task
  Future<List<Task>> queryAllTasks() async {
    Database db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(tableTasks);
    return List.generate(maps.length, (i) => Task.fromMap(maps[i]));
  }

  // Aggiornamento di un Task esistente
  Future<int> updateTask(Task task) async {
    Database db = await instance.database;
    return await db.update(
      tableTasks,
      task.toMap(),
      where: '$columnId = ?',
      whereArgs: [task.id],
    );
  }

  // Eliminazione di un Task per id
  Future<int> deleteTask(int id) async {
    Database db = await instance.database;
    return await db.delete(tableTasks, where: '$columnId = ?', whereArgs: [id]);
  }

  // Query per ottenere un Task specifico tramite id
  Future<Task?> queryTaskById(int id) async {
    Database db = await instance.database;
    List<Map<String, dynamic>> maps = await db.query(
      tableTasks,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Task.fromMap(maps.first);
    } else {
      return null;
    }
  }
}
