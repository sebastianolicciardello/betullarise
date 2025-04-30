import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:archive/archive.dart';
import 'database_export_import_service_test.mocks.dart';

// Classe di test che estende DatabaseExportImportUtils
class TestDatabaseExportImportUtils extends DatabaseExportImportUtils {
  final FileSystem fileSystem;

  TestDatabaseExportImportUtils(this.fileSystem);

  Future<Archive> createArchive(
    String databaseName,
    String prefsFilename,
    String dbPath,
    Map<String, dynamic> prefsMap,
  ) async {
    final archive = Archive();

    // Add database file to archive
    final dbFile = fileSystem.file(dbPath);
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      final archiveFile = ArchiveFile(databaseName, 420, dbBytes);
      archive.addFile(archiveFile);
    }

    // Add shared preferences to archive
    final prefsJson = DatabaseExportImportUtils.prefsMapToJson(prefsMap);
    final prefsBytes = utf8.encode(prefsJson);
    final prefsFile = ArchiveFile(prefsFilename, 420, prefsBytes);
    archive.addFile(prefsFile);

    return archive;
  }
}

// Generiamo i mock per le dipendenze esterne
@GenerateMocks([SharedPreferences, FilePicker, Permission, Database])
void main() {
  // Inizializziamo i mock prima di ogni test
  late MockSharedPreferences mockPrefs;

  setUp(() {
    mockPrefs = MockSharedPreferences();
  });

  group('DatabaseExportImportUtils', () {
    test('prefsToMap converts SharedPreferences to Map correctly', () {
      // Configuriamo il mock per restituire alcune chiavi
      when(mockPrefs.getKeys()).thenReturn({'key1', 'key2', 'key3'});

      // Configuriamo i valori per ogni chiave
      when(mockPrefs.get('key1')).thenReturn('value1');
      when(mockPrefs.get('key2')).thenReturn(42);
      when(mockPrefs.get('key3')).thenReturn(true);

      // Eseguiamo la funzione da testare
      final result = DatabaseExportImportUtils.prefsToMap(mockPrefs);

      // Verifichiamo il risultato
      expect(result, isA<Map<String, dynamic>>());
      expect(result.length, equals(3));
      expect(result['key1'], equals('value1'));
      expect(result['key2'], equals(42));
      expect(result['key3'], equals(true));

      // Verifichiamo che i metodi siano stati chiamati
      verify(mockPrefs.getKeys()).called(1);
      verify(mockPrefs.get('key1')).called(1);
      verify(mockPrefs.get('key2')).called(1);
      verify(mockPrefs.get('key3')).called(1);
    });

    test('prefsMapToJson converts Map to JSON string correctly', () {
      // Creiamo una Map di esempio con diversi tipi di dati
      final testMap = {
        'string': 'test',
        'int': 42,
        'double': 3.14,
        'bool': true,
        'list': ['item1', 'item2'],
        'null': null,
      };

      // Eseguiamo la funzione da testare
      final result = DatabaseExportImportUtils.prefsMapToJson(testMap);

      // Verifichiamo che il risultato sia una stringa JSON valida
      expect(result, isA<String>());

      // Verifichiamo che la stringa JSON contenga tutti i valori corretti
      expect(result, contains('"string":"test"'));
      expect(result, contains('"int":42'));
      expect(result, contains('"double":3.14'));
      expect(result, contains('"bool":true'));
      expect(result, contains('"list":["item1","item2"]'));
      expect(result, contains('"null":null'));

      // Verifichiamo che la stringa JSON possa essere decodificata
      final decodedMap = jsonDecode(result);
      expect(decodedMap, equals(testMap));
    });

    test('prefsJsonToMap converts JSON string to Map correctly', () {
      // Creiamo una stringa JSON di test con diversi tipi di dati
      final jsonString = '''
      {
        "string": "test",
        "int": 42,
        "double": 3.14,
        "bool": true,
        "list": ["item1", "item2"],
        "null": null,
        "nested": {
          "key": "value",
          "number": 123
        }
      }
      ''';

      // Eseguiamo la funzione da testare
      final result = DatabaseExportImportUtils.prefsJsonToMap(jsonString);

      // Verifichiamo che il risultato sia una Map
      expect(result, isA<Map<String, dynamic>>());

      // Verifichiamo che tutti i valori siano stati convertiti correttamente
      expect(result['string'], equals('test'));
      expect(result['int'], equals(42));
      expect(result['double'], equals(3.14));
      expect(result['bool'], equals(true));
      expect(result['list'], equals(['item1', 'item2']));
      expect(result['null'], isNull);

      // Verifichiamo che gli oggetti annidati siano stati convertiti correttamente
      expect(result['nested'], isA<Map<String, dynamic>>());
      expect(result['nested']['key'], equals('value'));
      expect(result['nested']['number'], equals(123));

      // Verifichiamo che i tipi di dati siano corretti
      expect(result['string'], isA<String>());
      expect(result['int'], isA<int>());
      expect(result['double'], isA<double>());
      expect(result['bool'], isA<bool>());
      expect(result['list'], isA<List>());
      expect(result['nested'], isA<Map>());
    });

    test(
      'createArchive creates a valid archive with database and preferences',
      () async {
        // Creiamo un file system in memoria
        final fs = MemoryFileSystem();
        final utils = TestDatabaseExportImportUtils(fs);

        // Creiamo un file di database fittizio
        final dbPath = '/path/to/database.db';
        final dbContent = Uint8List.fromList([
          1,
          2,
          3,
          4,
          5,
        ]); // Contenuto fittizio del database

        // Creiamo la directory e il file
        final dbDir = fs.directory('/path/to');
        await dbDir.create(recursive: true);
        final dbFile = fs.file(dbPath);
        await dbFile.writeAsBytes(dbContent);

        // Prepariamo i dati delle preferenze
        final prefsMap = {
          'setting1': 'value1',
          'setting2': 42,
          'setting3': true,
        };

        // Nomi dei file nell'archivio
        const dbName = 'test.db';
        const prefsName = 'prefs.json';

        // Creiamo l'archivio
        final archive = await utils.createArchive(
          dbName,
          prefsName,
          dbPath,
          prefsMap,
        );

        // Verifichiamo che l'archivio sia stato creato
        expect(archive, isNotNull);
        expect(archive, isA<Archive>());

        // Troviamo i file nell'archivio
        final dbArchiveFile = archive.findFile(dbName);
        final prefsArchiveFile = archive.findFile(prefsName);

        // Verifichiamo che entrambi i file esistano nell'archivio
        expect(dbArchiveFile, isNotNull);
        expect(prefsArchiveFile, isNotNull);

        // Verifichiamo il contenuto del file di database
        expect(
          dbArchiveFile!.content,
          equals(dbContent),
          reason:
              'Il contenuto del database nell\'archivio deve corrispondere al file originale',
        );

        // Verifichiamo il contenuto del file delle preferenze
        final prefsContent = utf8.decode(
          prefsArchiveFile!.content as List<int>,
        );
        final decodedPrefs = jsonDecode(prefsContent);
        expect(
          decodedPrefs,
          equals(prefsMap),
          reason:
              'Le preferenze nell\'archivio devono corrispondere alla Map originale',
        );

        // Verifichiamo i permessi dei file (420 = 0644)
        expect(dbArchiveFile.mode, equals(420));
        expect(prefsArchiveFile.mode, equals(420));
      },
    );

    test('createArchive handles missing database file correctly', () async {
      // Creiamo un file system in memoria
      final fs = MemoryFileSystem();
      final utils = TestDatabaseExportImportUtils(fs);

      // Usiamo un percorso per un file che non esiste
      final dbPath = '/path/to/nonexistent.db';

      // Prepariamo i dati delle preferenze
      final prefsMap = {'setting1': 'value1', 'setting2': 42, 'setting3': true};

      // Nomi dei file nell'archivio
      const dbName = 'test.db';
      const prefsName = 'prefs.json';

      // Creiamo l'archivio
      final archive = await utils.createArchive(
        dbName,
        prefsName,
        dbPath,
        prefsMap,
      );

      // Verifichiamo che l'archivio sia stato creato
      expect(archive, isNotNull);
      expect(archive, isA<Archive>());

      // Troviamo i file nell'archivio
      final dbArchiveFile = archive.findFile(dbName);
      final prefsArchiveFile = archive.findFile(prefsName);

      // Verifichiamo che il file del database non esista nell'archivio
      expect(dbArchiveFile, isNull);

      // Verifichiamo che il file delle preferenze esista nell'archivio
      expect(prefsArchiveFile, isNotNull);

      // Verifichiamo il contenuto del file delle preferenze
      final prefsContent = utf8.decode(prefsArchiveFile!.content as List<int>);
      final decodedPrefs = jsonDecode(prefsContent);
      expect(
        decodedPrefs,
        equals(prefsMap),
        reason:
            'Le preferenze nell\'archivio devono corrispondere alla Map originale',
      );

      // Verifichiamo i permessi del file delle preferenze (420 = 0644)
      expect(prefsArchiveFile.mode, equals(420));
    });

    test('createArchive handles empty database file correctly', () async {
      // Creiamo un file system in memoria
      final fs = MemoryFileSystem();
      final utils = TestDatabaseExportImportUtils(fs);

      // Creiamo un file di database vuoto
      final dbPath = '/path/to/empty.db';
      final dbDir = fs.directory('/path/to');
      await dbDir.create(recursive: true);
      final dbFile = fs.file(dbPath);
      await dbFile.writeAsBytes(Uint8List(0)); // File vuoto

      // Prepariamo i dati delle preferenze
      final prefsMap = {'setting1': 'value1', 'setting2': 42, 'setting3': true};

      // Nomi dei file nell'archivio
      const dbName = 'test.db';
      const prefsName = 'prefs.json';

      // Creiamo l'archivio
      final archive = await utils.createArchive(
        dbName,
        prefsName,
        dbPath,
        prefsMap,
      );

      // Verifichiamo che l'archivio sia stato creato
      expect(archive, isNotNull);
      expect(archive, isA<Archive>());

      // Troviamo i file nell'archivio
      final dbArchiveFile = archive.findFile(dbName);
      final prefsArchiveFile = archive.findFile(prefsName);

      // Verifichiamo che entrambi i file esistano nell'archivio
      expect(dbArchiveFile, isNotNull);
      expect(prefsArchiveFile, isNotNull);

      // Verifichiamo che il file del database sia vuoto
      expect(
        dbArchiveFile!.content,
        isEmpty,
        reason: 'Il contenuto del database nell\'archivio deve essere vuoto',
      );

      // Verifichiamo il contenuto del file delle preferenze
      final prefsContent = utf8.decode(prefsArchiveFile!.content as List<int>);
      final decodedPrefs = jsonDecode(prefsContent);
      expect(
        decodedPrefs,
        equals(prefsMap),
        reason:
            'Le preferenze nell\'archivio devono corrispondere alla Map originale',
      );

      // Verifichiamo i permessi dei file (420 = 0644)
      expect(dbArchiveFile.mode, equals(420));
      expect(prefsArchiveFile.mode, equals(420));
    });

    test('createArchive handles large database file correctly', () async {
      // Creiamo un file system in memoria
      final fs = MemoryFileSystem();
      final utils = TestDatabaseExportImportUtils(fs);

      // Creiamo un file di database molto grande (10MB)
      final dbPath = '/path/to/large.db';
      final dbDir = fs.directory('/path/to');
      await dbDir.create(recursive: true);
      final dbFile = fs.file(dbPath);

      // Creiamo un contenuto fittizio di 10MB
      final dbContent = Uint8List(10 * 1024 * 1024); // 10MB
      for (var i = 0; i < dbContent.length; i++) {
        dbContent[i] = i % 256; // Pattern ripetitivo per occupare spazio
      }
      await dbFile.writeAsBytes(dbContent);

      // Prepariamo i dati delle preferenze
      final prefsMap = {'setting1': 'value1', 'setting2': 42, 'setting3': true};

      // Nomi dei file nell'archivio
      const dbName = 'test.db';
      const prefsName = 'prefs.json';

      // Creiamo l'archivio e misuriamo il tempo di esecuzione
      final stopwatch = Stopwatch()..start();
      final archive = await utils.createArchive(
        dbName,
        prefsName,
        dbPath,
        prefsMap,
      );
      stopwatch.stop();

      // Verifichiamo che l'archivio sia stato creato
      expect(archive, isNotNull);
      expect(archive, isA<Archive>());

      // Troviamo i file nell'archivio
      final dbArchiveFile = archive.findFile(dbName);
      final prefsArchiveFile = archive.findFile(prefsName);

      // Verifichiamo che entrambi i file esistano nell'archivio
      expect(dbArchiveFile, isNotNull);
      expect(prefsArchiveFile, isNotNull);

      // Verifichiamo che il file del database contenga tutti i dati
      expect(
        dbArchiveFile!.content,
        equals(dbContent),
        reason:
            'Il contenuto del database nell\'archivio deve corrispondere al file originale',
      );

      // Verifichiamo il contenuto del file delle preferenze
      final prefsContent = utf8.decode(prefsArchiveFile!.content as List<int>);
      final decodedPrefs = jsonDecode(prefsContent);
      expect(
        decodedPrefs,
        equals(prefsMap),
        reason:
            'Le preferenze nell\'archivio devono corrispondere alla Map originale',
      );

      // Verifichiamo i permessi dei file (420 = 0644)
      expect(dbArchiveFile.mode, equals(420));
      expect(prefsArchiveFile.mode, equals(420));

      // Verifichiamo che il tempo di esecuzione sia ragionevole (meno di 5 secondi)
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'La creazione dell\'archivio con un file grande non dovrebbe essere troppo lenta',
      );
    });
  });
}
