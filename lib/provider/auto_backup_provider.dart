import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_export_import_service.dart';

class AutoBackupProvider extends ChangeNotifier {
  static const String _keyAutoBackupEnabled = 'auto_backup_enabled';
  static const String _keyBackupFolderPath = 'backup_folder_path';
  static const String _keyLastBackupDate = 'last_backup_date';
  static const int _maxBackupFiles = 7; // Keep last 7 days of backups

  final DatabaseExportImportService _exportService;

  bool _isEnabled = false;
  String? _backupFolderPath;
  DateTime? _lastBackupDate;

  bool get isEnabled => _isEnabled;
  String? get backupFolderPath => _backupFolderPath;
  DateTime? get lastBackupDate => _lastBackupDate;

  AutoBackupProvider({
    required DatabaseExportImportService exportService,
  })  : _exportService = exportService {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_keyAutoBackupEnabled) ?? false;
    _backupFolderPath = prefs.getString(_keyBackupFolderPath);

    final lastBackupDateStr = prefs.getString(_keyLastBackupDate);
    if (lastBackupDateStr != null) {
      _lastBackupDate = DateTime.tryParse(lastBackupDateStr);
    }

    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoBackupEnabled, enabled);
    notifyListeners();

    developer.log(
      'Auto-backup ${enabled ? "enabled" : "disabled"}',
      name: 'AutoBackupProvider',
    );
  }

  Future<void> setBackupFolderPath(String? folderPath) async {
    _backupFolderPath = folderPath;
    final prefs = await SharedPreferences.getInstance();
    if (folderPath != null) {
      await prefs.setString(_keyBackupFolderPath, folderPath);
    } else {
      await prefs.remove(_keyBackupFolderPath);
    }
    notifyListeners();

    developer.log(
      'Backup folder path set to: $folderPath',
      name: 'AutoBackupProvider',
    );
  }

  Future<void> _setLastBackupDate(DateTime date) async {
    _lastBackupDate = date;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastBackupDate, date.toIso8601String());
    notifyListeners();
  }

  bool _isFirstLaunchToday() {
    if (_lastBackupDate == null) {
      return true;
    }

    final now = DateTime.now();
    final lastBackup = _lastBackupDate!;

    return now.year != lastBackup.year ||
        now.month != lastBackup.month ||
        now.day != lastBackup.day;
  }

  Future<bool> checkAndPerformAutoBackup() async {
    if (!_isEnabled) {
      developer.log(
        'Auto-backup is disabled, skipping',
        name: 'AutoBackupProvider',
      );
      return false;
    }

    if (_backupFolderPath == null) {
      developer.log(
        'No backup folder configured, skipping auto-backup',
        name: 'AutoBackupProvider',
      );
      return false;
    }

    if (!_isFirstLaunchToday()) {
      developer.log(
        'Backup already performed today, skipping',
        name: 'AutoBackupProvider',
      );
      return false;
    }

    developer.log(
      'Performing auto-backup (first launch today)',
      name: 'AutoBackupProvider',
    );

    return await performBackup();
  }

  String? _lastError;
  String? get lastError => _lastError;

  Future<bool> performBackup() async {
    _lastError = null;

    if (_backupFolderPath == null) {
      _lastError = 'No backup folder configured';
      developer.log(_lastError!, name: 'AutoBackupProvider');
      return false;
    }

    try {
      developer.log(
        'Starting backup to folder: $_backupFolderPath',
        name: 'AutoBackupProvider',
      );

      final backupFolder = Directory(_backupFolderPath!);
      if (!await backupFolder.exists()) {
        developer.log(
          'Creating backup folder: $_backupFolderPath',
          name: 'AutoBackupProvider',
        );
        try {
          await backupFolder.create(recursive: true);
        } catch (e) {
          _lastError = 'Failed to create backup folder: $e\nPath: $_backupFolderPath';
          developer.log(_lastError!, name: 'AutoBackupProvider');
          return false;
        }
      }

      final timestamp = DateTime.now();
      final fileName = 'betullarise_backup_${_formatDateTimeForFilename(timestamp)}.zip';
      final filePath = path.join(_backupFolderPath!, fileName);

      developer.log(
        'Creating backup archive...',
        name: 'AutoBackupProvider',
      );

      final archiveBytes = await _exportService.exportDataAsBytes();
      if (archiveBytes == null) {
        _lastError = 'Failed to create backup archive.\n\n'
            'The export service returned null. This usually means:\n'
            '- Database file not found or inaccessible\n'
            '- Insufficient permissions to read database\n'
            '- Corrupted database file\n\n'
            'Try using "Export Data" from the Data Management section to see if export works.';
        developer.log(
          'Failed to create backup archive - exportDataAsBytes returned null',
          name: 'AutoBackupProvider',
        );
        return false;
      }

      developer.log(
        'Archive created successfully (${archiveBytes.length} bytes), writing to: $filePath',
        name: 'AutoBackupProvider',
      );

      try {
        final file = File(filePath);
        await file.writeAsBytes(archiveBytes);
      } catch (e) {
        _lastError = 'Failed to write backup file: $e\n\n'
            'Path: $filePath\n\n'
            'Check:\n'
            '- Write permissions for the folder\n'
            '- Available disk space\n'
            '- Folder path is valid and accessible';
        developer.log(_lastError!, name: 'AutoBackupProvider');
        return false;
      }

      developer.log(
        'Backup file written successfully',
        name: 'AutoBackupProvider',
      );

      await _setLastBackupDate(timestamp);
      await _cleanupOldBackups();

      developer.log(
        'Backup saved successfully to: $filePath',
        name: 'AutoBackupProvider',
      );

      return true;
    } catch (e, stackTrace) {
      _lastError = 'Unexpected error during backup:\n\n$e\n\nStack trace:\n${stackTrace.toString().split('\n').take(5).join('\n')}';
      developer.log(
        'Error performing backup: $e',
        name: 'AutoBackupProvider',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  Future<void> _cleanupOldBackups() async {
    if (_backupFolderPath == null) return;

    try {
      final backupFolder = Directory(_backupFolderPath!);
      if (!await backupFolder.exists()) return;

      final files = await backupFolder
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .map((entity) => entity as File)
          .toList();

      if (files.length <= _maxBackupFiles) return;

      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      final filesToDelete = files.skip(_maxBackupFiles);
      for (final file in filesToDelete) {
        await file.delete();
        developer.log(
          'Deleted old backup: ${file.path}',
          name: 'AutoBackupProvider',
        );
      }
    } catch (e) {
      developer.log(
        'Error cleaning up old backups: $e',
        name: 'AutoBackupProvider',
        error: e,
      );
    }
  }

  String _formatDateTimeForFilename(DateTime dateTime) {
    return '${dateTime.year}${_padZero(dateTime.month)}${_padZero(dateTime.day)}_'
        '${_padZero(dateTime.hour)}${_padZero(dateTime.minute)}${_padZero(dateTime.second)}';
  }

  String _padZero(int value) => value.toString().padLeft(2, '0');

  Future<List<File>> getBackupFiles() async {
    if (_backupFolderPath == null) return [];

    try {
      final backupFolder = Directory(_backupFolderPath!);
      if (!await backupFolder.exists()) return [];

      final files = await backupFolder
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .map((entity) => entity as File)
          .toList();

      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      developer.log(
        'Error getting backup files: $e',
        name: 'AutoBackupProvider',
        error: e,
      );
      return [];
    }
  }
}
