import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:developer' as developer;
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

/// Utility class containing pure functions for JSON conversion
class DatabaseExportImportUtils {
  /// Converts SharedPreferences to a Map
  static Map<String, dynamic> prefsToMap(SharedPreferences prefs) {
    return prefs.getKeys().fold<Map<String, dynamic>>({}, (map, key) {
      map[key] = prefs.get(key);
      return map;
    });
  }

  /// Converts preferences Map to JSON string
  static String prefsMapToJson(Map<String, dynamic> prefsMap) =>
      jsonEncode(prefsMap);

  /// Converts JSON string to preferences Map
  static Map<String, dynamic> prefsJsonToMap(String json) => jsonDecode(json);

  /// Creates an archive containing database and preferences
  static Future<Archive> createArchive(
    String databaseName,
    String prefsFilename,
    String dbPath,
    Map<String, dynamic> prefsMap,
  ) async {
    final archive = Archive();

    // Add database file to archive
    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      final dbBytes = await dbFile.readAsBytes();
      final archiveFile = ArchiveFile(databaseName, 420, dbBytes);
      archive.addFile(archiveFile);
      developer.log('Added database to archive', name: 'EXPORT');
    } else {
      developer.log('Database file not found', name: 'EXPORT_WARNING');
    }

    // Add shared preferences to archive
    final prefsJson = prefsMapToJson(prefsMap);
    final prefsBytes = utf8.encode(prefsJson);
    final prefsFile = ArchiveFile(prefsFilename, 420, prefsBytes);
    archive.addFile(prefsFile);
    developer.log('Added preferences to archive', name: 'EXPORT');

    return archive;
  }

  /// Processes imported preferences and updates SharedPreferences
  static Future<void> processImportedPreferences(String prefsJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear existing preferences

    final prefsMap = prefsJsonToMap(prefsJson);
    for (var entry in (prefsMap as Map).entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is List) {
        await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      }
    }
  }

  /// Reads the database file from the archive and writes it to the specified path
  static Future<bool> readDatabaseFromArchive(
    Archive archive,
    String databaseName,
    String dbPath,
  ) async {
    final dbArchiveFile = archive.findFile(databaseName);
    if (dbArchiveFile != null) {
      final dbFile = File(dbPath);

      // Create parent directories if they don't exist
      if (!await dbFile.parent.exists()) {
        await dbFile.parent.create(recursive: true);
      }

      // Write database file
      await dbFile.writeAsBytes(dbArchiveFile.content as List<int>);
      developer.log('Database imported successfully', name: 'IMPORT');
      return true;
    } else {
      developer.log(
        'Database file not found in archive',
        name: 'IMPORT_WARNING',
      );
      return false;
    }
  }

  /// Reads preferences from the archive and processes them
  static Future<bool> readPreferencesFromArchive(
    Archive archive,
    String prefsFilename,
  ) async {
    final prefsArchiveFile = archive.findFile(prefsFilename);
    if (prefsArchiveFile != null) {
      final prefsJson = String.fromCharCodes(
        prefsArchiveFile.content as List<int>,
      );

      try {
        await processImportedPreferences(prefsJson);
        developer.log('Preferences imported successfully', name: 'IMPORT');
        return true;
      } catch (e) {
        developer.log('Error importing preferences: $e', name: 'IMPORT_ERROR');
        return false;
      }
    } else {
      developer.log(
        'Preferences file not found in archive',
        name: 'IMPORT_WARNING',
      );
      return false;
    }
  }
}

class DatabaseExportImportService {
  static const String _databaseName = 'betullarise.db';
  static const String _prefsFilename = 'preferences.json';
  static const String _exportFilename = 'betullarise_backup.zip';

  /// Handles errors during export/import operations
  Future<bool> _handleError(
    BuildContext context,
    String message,
    dynamic error,
    StackTrace? stackTrace,
    String operation,
  ) async {
    developer.log(
      'Error during $operation: $error\n$stackTrace',
      name: '${operation.toUpperCase()}_ERROR',
    );
    if (context.mounted) {
      _showSnackBar(context, message);
    }
    return false;
  }

  /// Requests storage permission on Android
  Future<bool> _requestStoragePermission(BuildContext context) async {
    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.request();
      if (!status.isGranted && context.mounted) {
        _showSnackBar(context, 'Storage permission denied');
        return false;
      }
    }
    return true;
  }

  /// Gets the database path based on platform
  Future<String> _getDatabasePath() async {
    if (Platform.isMacOS) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return path.join(documentsDirectory.path, _databaseName);
    } else {
      final databasePath = await getDatabasesPath();
      return path.join(databasePath, _databaseName);
    }
  }

  /// Gets the default export directory path based on platform
  Future<String> _getDefaultExportPath() async {
    Directory directory;

    if (Platform.isIOS || Platform.isMacOS) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isAndroid) {
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory =
            await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory.path;
  }

  /// Creates a temporary file for export
  Future<File> _createTempFile(List<int> zipData) async {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(path.join(tempDir.path, _exportFilename));
    await tempFile.writeAsBytes(zipData);
    return tempFile;
  }

  /// Uses file picker to choose a directory to save the export file
  Future<String?> _chooseExportDirectory(BuildContext context) async {
    String? saveDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save the backup',
    );

    if (saveDir == null) {
      if (context.mounted) {
        _showSnackBar(context, 'Export canceled');
      }
      return null;
    }

    return saveDir;
  }

  /// Uses file picker to save the export file
  Future<String?> _saveFileWithPicker(
    BuildContext context,
    Uint8List zipDataUint8List,
  ) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save backup file',
      fileName: _exportFilename,
      type: FileType.any,
      bytes: zipDataUint8List,
    );

    if (outputFile == null) {
      if (context.mounted) {
        _showSnackBar(context, 'Export canceled');
      }
      return null;
    }

    return outputFile;
  }

  /// Uses file picker to choose a file to import
  Future<Uint8List?> _chooseImportFile(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      compressionQuality: 100,
      allowMultiple: false,
      withData: true,
      dialogTitle: 'Seleziona un file di backup (.zip)',
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    if (file.bytes != null) {
      return file.bytes;
    } else if (file.path != null) {
      return await File(file.path!).readAsBytes();
    }

    if (context.mounted) {
      _showSnackBar(context, 'Impossibile leggere i dati del file');
    }
    return null;
  }

  /// Handles file system operations for export
  Future<String?> _handleExportFileSystem(
    BuildContext context,
    List<int> zipData,
    Uint8List zipDataUint8List,
  ) async {
    String? outputPath;

    if (Platform.isIOS || Platform.isMacOS) {
      // On iOS/macOS, we'll use a temporary file and then let the user choose where to save it
      final tempFile = await _createTempFile(zipData);

      // Use file_picker to choose the save location
      if (!context.mounted) return null;
      final saveDir = await _chooseExportDirectory(context);
      if (saveDir == null) {
        return null;
      }

      // Copy the temp file to the chosen location
      final saveFile = File(path.join(saveDir, _exportFilename));
      await tempFile.copy(saveFile.path);
      await tempFile.delete(); // Clean up the temp file

      outputPath = saveFile.path;
    } else if (Platform.isAndroid) {
      // On Android, we'll use the FilePicker.platform.saveFile
      try {
        outputPath = await _saveFileWithPicker(context, zipDataUint8List);
        if (outputPath == null) {
          return null;
        }
      } catch (e) {
        // If saveFile is not supported (older Android), fall back to default location
        developer.log(
          'SaveFile not supported, using default location',
          name: 'EXPORT',
        );
        final defaultDir = await _getDefaultExportPath();
        final file = File(path.join(defaultDir, _exportFilename));
        await file.writeAsBytes(zipData);
        outputPath = file.path;
      }
    } else {
      // Fallback for other platforms
      final defaultDir = await _getDefaultExportPath();
      final file = File(path.join(defaultDir, _exportFilename));
      await file.writeAsBytes(zipData);
      outputPath = file.path;
    }

    return outputPath;
  }

  /// Handles file system operations for import
  Future<bool> _handleImportFileSystem(
    BuildContext context,
    Archive archive,
  ) async {
    try {
      // Process database file
      final dbPath = await _getDatabasePath();
      await DatabaseExportImportUtils.readDatabaseFromArchive(
        archive,
        _databaseName,
        dbPath,
      );

      // Process preferences file
      await DatabaseExportImportUtils.readPreferencesFromArchive(
        archive,
        _prefsFilename,
      );

      if (context.mounted) {
        _showSnackBar(
          context,
          'Dati importati con successo. Riavvia l\'app per applicare le modifiche.',
        );
      }

      return true;
    } catch (e, stackTrace) {
      if (!context.mounted) return false;
      return await _handleError(
        context,
        'Errore nell\'elaborazione del file di backup: $e',
        e,
        stackTrace,
        'import',
      );
    }
  }

  // Export database and shared preferences to a zip file
  Future<String?> exportData(BuildContext context) async {
    try {
      // Request storage permission on Android
      if (!await _requestStoragePermission(context)) {
        return null;
      }

      // Get database path and create archive
      final dbPath = await _getDatabasePath();
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = DatabaseExportImportUtils.prefsToMap(prefs);

      final archive = await DatabaseExportImportUtils.createArchive(
        _databaseName,
        _prefsFilename,
        dbPath,
        prefsMap,
      );

      // Create zip file
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      final zipDataUint8List = Uint8List.fromList(zipData);

      // Save the export file
      if (!context.mounted) return null;
      final outputPath = await _handleExportFileSystem(
        context,
        zipData,
        zipDataUint8List,
      );

      if (outputPath != null && context.mounted) {
        _showSnackBar(context, 'Export completed: $outputPath');
        developer.log('Data exported to $outputPath', name: 'EXPORT');
      }

      return outputPath;
    } catch (e, stackTrace) {
      if (!context.mounted) return null;
      await _handleError(
        context,
        'Error exporting data: $e',
        e,
        stackTrace,
        'export',
      );
      return null;
    }
  }

  Future<bool> importData(BuildContext context) async {
    try {
      if (Platform.isAndroid) {
        // Mostra prima un suggerimento utile
        if (context.mounted) {
          _showSnackBar(
            context,
            'Consiglio: Posiziona i tuoi file di backup nella cartella Download per un facile accesso',
          );
        }

        // Prova prima con l'approccio standard di FilePicker
        final fileBytes = await _chooseImportFile(context);
        if (!context.mounted) return false;

        if (fileBytes == null) {
          // Se non è stato selezionato nessun file, prova con il browser personalizzato
          return await _browseDownloadsFolder(context);
        }

        final archive = ZipDecoder().decodeBytes(fileBytes);
        return await _handleImportFileSystem(context, archive);
      } else {
        return await _legacyImportFlow(context);
      }
    } catch (e, stackTrace) {
      return await _handleError(
        context,
        'Errore durante l\'importazione: $e',
        e,
        stackTrace,
        'import',
      );
    }
  }

  // Browser personalizzato per la cartella Download
  Future<bool> _browseDownloadsFolder(BuildContext context) async {
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        if (context.mounted) {
          _showSnackBar(context, 'Cartella Download non trovata');
        }
        return false;
      }

      // Elenca tutti i file zip nella cartella Download
      List<FileSystemEntity> files = await downloadsDir.list().toList();
      List<File> zipFiles =
          files
              .whereType<File>()
              .where((file) => file.path.toLowerCase().endsWith('.zip'))
              .toList();

      if (!context.mounted) return false;

      if (zipFiles.isEmpty) {
        if (context.mounted) {
          _showSnackBar(
            context,
            'Nessun file di backup trovato nella cartella Download',
          );
        }
        return false;
      }

      // Mostra un dialog con l'elenco dei file zip
      File? selectedFile;
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Seleziona un file di backup'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: zipFiles.length,
                  itemBuilder: (context, index) {
                    final file = zipFiles[index];
                    final fileName = path.basename(file.path);
                    return ListTile(
                      title: Text(fileName),
                      onTap: () {
                        selectedFile = file;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Annulla'),
                ),
              ],
            );
          },
        );
      }

      if (selectedFile != null) {
        final fileBytes = await selectedFile!.readAsBytes();

        if (!context.mounted) return false;
        final archive = ZipDecoder().decodeBytes(fileBytes);
        return await _handleImportFileSystem(context, archive);
      }

      return false;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Errore nell\'accesso alla cartella Download: $e',
        );
      }
      return false;
    }
  }

  // Elabora i bytes di un file zip di backup
  Future<bool> _processImportBytes(
    BuildContext context,
    Uint8List bytes,
  ) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      return await _handleImportFileSystem(context, archive);
    } catch (e, stackTrace) {
      return await _handleError(
        context,
        'Errore nell\'elaborazione del file di backup: $e',
        e,
        stackTrace,
        'import',
      );
    }
  }

  // Mantiene il flusso di importazione originale per le piattaforme non-Android
  Future<bool> _legacyImportFlow(BuildContext context) async {
    // Qui inserisci il codice originale per le altre piattaforme
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      dialogTitle: 'Select a backup file to import',
    );

    if (result == null || result.files.isEmpty) {
      if (context.mounted) {
        _showSnackBar(context, 'No file selected');
      }
      return false;
    }

    final file = result.files.first;
    late Uint8List fileBytes;

    if (file.bytes != null) {
      fileBytes = file.bytes!;
    } else if (file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    } else {
      if (context.mounted) {
        _showSnackBar(context, 'Could not read file data');
      }
      return false;
    }

    if (!context.mounted) return false;

    return _processImportBytes(context, fileBytes);
  }

  // Show a snackbar with a message
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
