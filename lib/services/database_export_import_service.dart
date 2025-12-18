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
import 'package:device_info_plus/device_info_plus.dart';
import 'package:platform/platform.dart';
import 'package:sqflite/sqflite.dart';

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

/// Interface for requesting permissions (for testability)
abstract class PermissionRequester {
  Future<PermissionStatus> requestPhotos();
  Future<PermissionStatus> requestVideos();
  Future<PermissionStatus> requestAudio();
  Future<PermissionStatus> requestStorage();
  Future<PermissionStatus> requestManageExternalStorage();
}

/// Default implementation using permission_handler
class DefaultPermissionRequester implements PermissionRequester {
  @override
  Future<PermissionStatus> requestPhotos() => Permission.photos.request();
  @override
  Future<PermissionStatus> requestVideos() => Permission.videos.request();
  @override
  Future<PermissionStatus> requestAudio() => Permission.audio.request();
  @override
  Future<PermissionStatus> requestStorage() => Permission.storage.request();
  @override
  Future<PermissionStatus> requestManageExternalStorage() =>
      Permission.manageExternalStorage.request();
}

/// Default implementation of PlatformHandler
class DefaultPlatformHandler implements PlatformHandler {
  final BuildContext? context;
  final ExportImportConfig config;
  final DeviceInfoPlugin _deviceInfo;
  final PermissionRequester permissionRequester;
  final Platform _platform;

  DefaultPlatformHandler({
    this.context,
    this.config = const ExportImportConfig(),
    PermissionRequester? permissionRequester,
    DeviceInfoPlugin? deviceInfo,
    Platform? platform,
  }) : permissionRequester =
           permissionRequester ?? DefaultPermissionRequester(),
       _deviceInfo = deviceInfo ?? DeviceInfoPlugin(),
       _platform = platform ?? const LocalPlatform();

  @override
  Future<bool> requestStoragePermission() async {
    if (_platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30) {
        // Android 11+ (API 30+) - Requires MANAGE_EXTERNAL_STORAGE for File API access to shared storage
        final status = await permissionRequester.requestManageExternalStorage();
        return status.isGranted;
      } else {
        // Android 10 and below
        final storage = await permissionRequester.requestStorage();
        return storage.isGranted;
      }
    }
    return true;
  }

  @override
  Future<String> getDatabasePath(String databaseName) async {
    if (_platform.isMacOS) {
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

    if (_platform.isIOS || _platform.isMacOS) {
      directory = await getApplicationDocumentsDirectory();
    } else if (_platform.isAndroid) {
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
    if (_platform.isAndroid) {
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

  /// Request storage permission
  Future<bool> requestStoragePermission() async {
    return await _platformHandler.requestStoragePermission();
  }

  /// Export database and shared preferences as bytes
  /// This method returns the raw ZIP archive bytes without showing a save dialog
  /// Useful for automated backups
  Future<Uint8List?> exportDataAsBytes() async {
    try {
      developer.log('Starting exportDataAsBytes...', name: 'EXPORT_DEBUG');

      final dbPath = await _platformHandler.getDatabasePath(
        _config.databaseName,
      );
      developer.log('Database path obtained: $dbPath', name: 'EXPORT_DEBUG');

      final prefs = await SharedPreferences.getInstance();
      final prefsMap = DatabaseExportImportUtils.prefsToMap(prefs);
      developer.log(
        'Preferences loaded: ${prefsMap.length} entries',
        name: 'EXPORT_DEBUG',
      );

      developer.log('Creating archive...', name: 'EXPORT_DEBUG');
      final archive = await DatabaseExportImportUtils.createArchive(
        _config.databaseName,
        _config.prefsFilename,
        dbPath,
        prefsMap,
      );

      developer.log('Encoding archive...', name: 'EXPORT_DEBUG');
      final zipEncoder = ZipEncoder();
      final zipData = zipEncoder.encode(archive);
      final bytes = Uint8List.fromList(zipData);

      developer.log(
        'Export successful: ${bytes.length} bytes',
        name: 'EXPORT_DEBUG',
      );
      return bytes;
    } catch (e, stackTrace) {
      developer.log(
        'Error during export: $e',
        name: 'EXPORT_ERROR',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Export database and shared preferences to a zip file
  Future<String?> exportData() async {
    try {
      if (!await _platformHandler.requestStoragePermission()) {
        throw PermissionException('Storage permission denied');
      }

      final archiveBytes = await exportDataAsBytes();
      if (archiveBytes == null) {
        return null;
      }

      return await _platformHandler.saveFile(
        archiveBytes,
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

      // Validate the backup file completely before processing
      await DatabaseExportImportUtils.validateBackupFile(
        fileBytes,
        _config.databaseName,
        _config.prefsFilename,
      );

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

      // Both components must be imported successfully
      if (!dbSuccess || !prefsSuccess) {
        throw InvalidBackupException(
          'Failed to import all components. Database: $dbSuccess, Preferences: $prefsSuccess',
        );
      }

      return true;
    } on PermissionException catch (e) {
      developer.log(
        'Permission error during import: ${e.message}',
        name: 'IMPORT_ERROR',
      );
      rethrow;
    } on InvalidBackupException catch (e) {
      developer.log('Invalid backup file: ${e.message}', name: 'IMPORT_ERROR');
      rethrow;
    } catch (e, stackTrace) {
      developer.log(
        'Error during import: $e\n$stackTrace',
        name: 'IMPORT_ERROR',
      );
      throw InvalidBackupException('Corrupted or invalid backup file: $e');
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

/// Custom exception for invalid backup file errors
class InvalidBackupException implements Exception {
  final String message;
  InvalidBackupException(this.message);

  @override
  String toString() => message;
}

/// Utility class containing pure functions for JSON conversion
class DatabaseExportImportUtils {
  /// Validates a backup file before import
  static Future<void> validateBackupFile(
    Uint8List fileBytes,
    String expectedDatabaseName,
    String expectedPrefsFilename,
  ) async {
    try {
      // Try to decode the ZIP file
      Archive archive;
      try {
        archive = ZipDecoder().decodeBytes(fileBytes);
      } catch (e) {
        throw InvalidBackupException('File is not a valid ZIP archive');
      }

      // Check if archive is empty
      if (archive.files.isEmpty) {
        throw InvalidBackupException('Backup file is empty');
      }

      // Check for required database file
      final dbFile = archive.findFile(expectedDatabaseName);
      if (dbFile == null) {
        throw InvalidBackupException(
          'Database file "$expectedDatabaseName" not found in backup',
        );
      }

      // Validate database file content
      if ((dbFile.content as List<int>).isEmpty) {
        throw InvalidBackupException('Database file is empty or corrupted');
      }

      // Basic SQLite file validation (check magic header)
      final dbContent = dbFile.content as List<int>;
      if (dbContent.length < 16) {
        throw InvalidBackupException('Database file is too small to be valid');
      }

      // SQLite files start with "SQLite format 3\0"
      final sqliteHeader = [
        0x53,
        0x51,
        0x4c,
        0x69,
        0x74,
        0x65,
        0x20,
        0x66,
        0x6f,
        0x72,
        0x6d,
        0x61,
        0x74,
        0x20,
        0x33,
        0x00,
      ];
      final fileHeader = dbContent.take(16).toList();
      bool headerMatches = true;
      for (int i = 0; i < sqliteHeader.length; i++) {
        if (fileHeader[i] != sqliteHeader[i]) {
          headerMatches = false;
          break;
        }
      }

      if (!headerMatches) {
        throw InvalidBackupException(
          'Database file is not a valid SQLite database',
        );
      }

      // Check for required preferences file
      final prefsFile = archive.findFile(expectedPrefsFilename);
      if (prefsFile == null) {
        throw InvalidBackupException(
          'Preferences file "$expectedPrefsFilename" not found in backup',
        );
      }

      // Validate preferences file content
      if ((prefsFile.content as List<int>).isEmpty) {
        throw InvalidBackupException('Preferences file is empty');
      }

      // Validate JSON format of preferences
      try {
        final prefsJson = String.fromCharCodes(prefsFile.content as List<int>);
        final decoded = jsonDecode(prefsJson);

        // Must be a Map/Object
        if (decoded is! Map) {
          throw InvalidBackupException(
            'Preferences file does not contain valid JSON object',
          );
        }
      } catch (e) {
        throw InvalidBackupException(
          'Preferences file contains invalid JSON: $e',
        );
      }

      developer.log(
        'Backup file validation successful',
        name: 'IMPORT_VALIDATION',
      );
    } catch (e) {
      if (e is InvalidBackupException) {
        rethrow;
      }
      throw InvalidBackupException('Failed to validate backup file: $e');
    }
  }

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
