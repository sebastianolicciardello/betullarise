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

class DatabaseExportImportService {
  static const String _databaseName = 'betullarise.db';
  static const String _prefsFilename = 'preferences.json';
  static const String _exportFilename = 'betullarise_backup.zip';

  // Export database and shared preferences to a zip file
  Future<String?> exportData(BuildContext context) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.request();
        if (!status.isGranted && context.mounted) {
          _showSnackBar(context, 'Storage permission denied');
          return null;
        }
      }

      // Create archive
      final archive = Archive();

      // Add database file to archive
      final dbPath = await _getDatabasePath();
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        final dbBytes = await dbFile.readAsBytes();
        final archiveFile = ArchiveFile(_databaseName, 420, dbBytes);
        archive.addFile(archiveFile);
        developer.log('Added database to archive', name: 'EXPORT');
      } else {
        developer.log('Database file not found', name: 'EXPORT_WARNING');
      }

      // Add shared preferences to archive
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = prefs.getKeys().fold<Map<String, dynamic>>({}, (
        map,
        key,
      ) {
        map[key] = prefs.get(key);
        return map;
      });

      final prefsJson = jsonEncode(prefsMap);
      final prefsBytes = utf8.encode(prefsJson);
      final prefsFile = ArchiveFile(_prefsFilename, 420, prefsBytes);
      archive.addFile(prefsFile);
      developer.log('Added preferences to archive', name: 'EXPORT');

      // Create zip file
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      // Convert List<int> to Uint8List
      final zipDataUint8List = Uint8List.fromList(zipData);

      // Let the user choose where to save the file
      String? outputPath;

      // Different behavior based on platform
      if (Platform.isIOS || Platform.isMacOS) {
        // On iOS/macOS, we'll use a temporary file and then let the user choose where to save it
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(path.join(tempDir.path, _exportFilename));
        await tempFile.writeAsBytes(zipData);

        // Use file_picker to choose the save location
        String? saveDir = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Choose where to save the backup',
        );

        if (saveDir == null) {
          if (context.mounted) {
            _showSnackBar(context, 'Export canceled');
          }
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
          String? outputFile = await FilePicker.platform.saveFile(
            dialogTitle: 'Save backup file',
            fileName: _exportFilename,
            type: FileType.any,
            bytes: zipDataUint8List, // Add this line to provide the bytes
          );

          if (outputFile == null) {
            if (context.mounted) {
              _showSnackBar(context, 'Export canceled');
            }
            return null;
          }

          // No need to write bytes again since FilePicker does it for us
          outputPath = outputFile;
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

      if (context.mounted) {
        _showSnackBar(context, 'Export completed: $outputPath');
        developer.log('Data exported to $outputPath', name: 'EXPORT');
      }

      return outputPath;
    } catch (e, stackTrace) {
      developer.log(
        'Error exporting data: $e\n$stackTrace',
        name: 'EXPORT_ERROR',
      );
      if (context.mounted) {
        _showSnackBar(context, 'Error exporting data: $e');
      }

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
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          compressionQuality: 100,
          allowMultiple: false,
          withData: true, // Importante: carica i dati del file in memoria
          dialogTitle: 'Seleziona un file di backup (.zip)',
        );

        if (!context.mounted) return false;

        if (result == null || result.files.isEmpty) {
          // Se non è stato selezionato nessun file, prova con il browser personalizzato
          return await _browseDownloadsFolder(context);
        }

        final file = result.files.first;
        late Uint8List fileBytes;

        // Ottieni i byte del file
        if (file.bytes != null) {
          fileBytes = file.bytes!;
        } else if (file.path != null) {
          fileBytes = await File(file.path!).readAsBytes();
        } else {
          if (context.mounted) {
            _showSnackBar(context, 'Impossibile leggere i dati del file');
          }
          return false;
        }

        if (!context.mounted) return false;

        // Procedi con l'elaborazione del file
        return await _processImportBytes(context, fileBytes);
      } else {
        // Per piattaforme non Android, usa il codice esistente...
        return await _legacyImportFlow(context);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error importing data: $e\n$stackTrace',
        name: 'IMPORT_ERROR',
      );
      if (context.mounted) {
        _showSnackBar(context, 'Errore durante l\'importazione: $e');
      }
      return false;
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
        return await _processImportBytes(context, fileBytes);
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

      // Process database file
      final dbArchiveFile = archive.findFile(_databaseName);
      if (dbArchiveFile != null) {
        final dbPath = await _getDatabasePath();
        final dbFile = File(dbPath);

        // Create parent directories if they don't exist
        if (!await dbFile.parent.exists()) {
          await dbFile.parent.create(recursive: true);
        }

        // Write database file
        await dbFile.writeAsBytes(dbArchiveFile.content as List<int>);
        developer.log('Database imported successfully', name: 'IMPORT');
      } else {
        developer.log(
          'Database file not found in archive',
          name: 'IMPORT_WARNING',
        );
      }

      // Process preferences file
      final prefsArchiveFile = archive.findFile(_prefsFilename);
      if (prefsArchiveFile != null) {
        final prefsJson = String.fromCharCodes(
          prefsArchiveFile.content as List<int>,
        );

        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear(); // Clear existing preferences

          final prefsMap = jsonDecode(prefsJson);
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
              await prefs.setStringList(
                key,
                value.map((e) => e.toString()).toList(),
              );
            }
          }
          developer.log('Preferences imported successfully', name: 'IMPORT');
        } catch (e) {
          developer.log(
            'Error importing preferences: $e',
            name: 'IMPORT_ERROR',
          );
        }
      } else {
        developer.log(
          'Preferences file not found in archive',
          name: 'IMPORT_WARNING',
        );
      }

      if (context.mounted) {
        _showSnackBar(
          context,
          'Dati importati con successo. Riavvia l\'app per applicare le modifiche.',
        );
      }

      return true;
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(
          context,
          'Errore nell\'elaborazione del file di backup: $e',
        );
      }
      return false;
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

  // Get the database path
  Future<String> _getDatabasePath() async {
    if (Platform.isMacOS) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return path.join(documentsDirectory.path, _databaseName);
    } else {
      final databasePath = await getDatabasesPath();
      return path.join(databasePath, _databaseName);
    }
  }

  // Get the default export directory path
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

  // Show a snackbar with a message
  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
