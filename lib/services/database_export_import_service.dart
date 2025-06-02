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
import 'package:device_info_plus/device_info_plus.dart';

/// Configuration for the export/import service
class ExportImportConfig {
  final String databaseName;
  final String prefsFilename;
  final String exportFilename;

  const ExportImportConfig({
    this.databaseName = 'betullarise.db',
    this.prefsFilename = 'preferences.json',
    this.exportFilename = 'betullarise_backup.zip',
  });
}

/// Interface for handling platform-specific operations
abstract class PlatformHandler {
  Future<bool> requestStoragePermission();
  Future<String> getDatabasePath(String databaseName);
  Future<String> getDefaultExportPath();
  Future<String?> chooseExportDirectory();
  Future<String?> saveFile(Uint8List data, String filename);
  Future<Uint8List?> chooseImportFile();
  Future<bool> isAndroid13OrHigher();
}

/// Default implementation of PlatformHandler
class DefaultPlatformHandler implements PlatformHandler {
  final BuildContext? context;
  final ExportImportConfig config;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  DefaultPlatformHandler({
    this.context,
    this.config = const ExportImportConfig(),
  });

  @override
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 34) {
        // Android 14+ (API 34+)
        final photos = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio = await Permission.audio.request();

        return photos.isGranted && videos.isGranted && audio.isGranted;
      } else if (sdkInt >= 33) {
        // Android 13 (API 33)
        final photos = await Permission.photos.request();
        return photos.isGranted;
      } else {
        // Android 12 and below
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }
    return true;
  }

  @override
  Future<String> getDatabasePath(String databaseName) async {
    if (Platform.isMacOS) {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      return path.join(documentsDirectory.path, databaseName);
    } else {
      final databasePath = await getDatabasesPath();
      return path.join(databasePath, databaseName);
    }
  }

  @override
  Future<String> getDefaultExportPath() async {
    Directory directory;

    if (Platform.isIOS || Platform.isMacOS) {
      directory = await getApplicationDocumentsDirectory();
    } else if (Platform.isAndroid) {
      if (await isAndroid13OrHigher()) {
        // Use app-specific directory for Android 13+
        directory = await getApplicationDocumentsDirectory();
      } else {
        // Use Downloads directory for older Android versions
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory =
              await getExternalStorageDirectory() ??
              await getApplicationDocumentsDirectory();
        }
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    return directory.path;
  }

  @override
  Future<String?> chooseExportDirectory() async {
    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose where to save the backup',
    );
  }

  @override
  Future<String?> saveFile(Uint8List data, String filename) async {
    try {
      return await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup file',
        fileName: filename,
        type: FileType.any,
        bytes: data,
      );
    } catch (e) {
      final defaultDir = await getDefaultExportPath();
      final file = File(path.join(defaultDir, filename));
      await file.writeAsBytes(data);
      return file.path;
    }
  }

  @override
  Future<Uint8List?> chooseImportFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
      dialogTitle: 'Select a backup file to import',
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
    return null;
  }

  @override
  Future<bool> isAndroid13OrHigher() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      return androidInfo.version.sdkInt >= 33;
    }
    return false;
  }
}

/// Service for handling database and preferences export/import
class DatabaseExportImportService {
  final PlatformHandler _platformHandler;
  final ExportImportConfig _config;

  DatabaseExportImportService({
    PlatformHandler? platformHandler,
    ExportImportConfig? config,
  }) : _platformHandler = platformHandler ?? DefaultPlatformHandler(),
       _config = config ?? const ExportImportConfig();

  /// Export database and shared preferences to a zip file
  Future<String?> exportData() async {
    try {
      if (!await _platformHandler.requestStoragePermission()) {
        throw PermissionException('Storage permission denied');
      }

      final dbPath = await _platformHandler.getDatabasePath(
        _config.databaseName,
      );
      final prefs = await SharedPreferences.getInstance();
      final prefsMap = DatabaseExportImportUtils.prefsToMap(prefs);

      final archive = await DatabaseExportImportUtils.createArchive(
        _config.databaseName,
        _config.prefsFilename,
        dbPath,
        prefsMap,
      );

      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      final zipDataUint8List = Uint8List.fromList(zipData);

      return await _platformHandler.saveFile(
        zipDataUint8List,
        _config.exportFilename,
      );
    } on PermissionException catch (e) {
      developer.log(
        'Permission error during export: ${e.message}',
        name: 'EXPORT_ERROR',
      );
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error during export: $e\n$stackTrace',
        name: 'EXPORT_ERROR',
      );
      return null;
    }
  }

  /// Import database and shared preferences from a zip file
  Future<bool> importData() async {
    try {
      if (!await _platformHandler.requestStoragePermission()) {
        throw PermissionException('Storage permission denied');
      }

      final fileBytes = await _platformHandler.chooseImportFile();
      if (fileBytes == null) {
        return false;
      }

      final archive = ZipDecoder().decodeBytes(fileBytes);

      // Process database file
      final dbPath = await _platformHandler.getDatabasePath(
        _config.databaseName,
      );
      final dbSuccess = await DatabaseExportImportUtils.readDatabaseFromArchive(
        archive,
        _config.databaseName,
        dbPath,
      );

      // Process preferences file
      final prefsSuccess =
          await DatabaseExportImportUtils.readPreferencesFromArchive(
            archive,
            _config.prefsFilename,
          );

      return dbSuccess && prefsSuccess;
    } on PermissionException catch (e) {
      developer.log(
        'Permission error during import: ${e.message}',
        name: 'IMPORT_ERROR',
      );
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error during import: $e\n$stackTrace',
        name: 'IMPORT_ERROR',
      );
      return false;
    }
  }
}

/// Custom exception for permission-related errors
class PermissionException implements Exception {
  final String message;
  PermissionException(this.message);

  @override
  String toString() => message;
}

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
