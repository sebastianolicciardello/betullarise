import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:archive/archive.dart';
import 'database_export_import_service_test.mocks.dart';
import 'dart:io';

// Add a mock utility class for archive and preferences operations
class MockExportImportUtils extends Mock implements DatabaseExportImportUtils {}

@GenerateMocks([PlatformHandler, SharedPreferences, Archive, ArchiveFile])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockPlatformHandler mockPlatformHandler;
  late DatabaseExportImportService service;
  late ExportImportConfig config;

  setUp(() {
    mockPlatformHandler = MockPlatformHandler();
    config = const ExportImportConfig();
    // Patch the service to use the mock utility if needed
    service = DatabaseExportImportService(
      platformHandler: mockPlatformHandler,
      config: config,
    );
  });

  group('Export Tests', () {
    test(
      'exportData throws PermissionException when permission is denied',
      () async {
        when(
          mockPlatformHandler.requestStoragePermission(),
        ).thenAnswer((_) async => false);

        expect(() => service.exportData(), throwsA(isA<PermissionException>()));
      },
    );

    test('exportData handles successful export up to utility call', () async {
      when(
        mockPlatformHandler.requestStoragePermission(),
      ).thenAnswer((_) async => true);
      when(
        mockPlatformHandler.getDatabasePath(any),
      ).thenAnswer((_) async => '/test/path/db.sqlite');
      when(
        mockPlatformHandler.saveFile(any, any),
      ).thenAnswer((_) async => '/test/path/backup.zip');
      SharedPreferences.setMockInitialValues({});

      // We can't mock static methods, so we just check up to the saveFile call
      final result = await service.exportData();

      // The result should be the mocked path
      expect(result, '/test/path/backup.zip');
      verify(mockPlatformHandler.requestStoragePermission()).called(1);
      verify(
        mockPlatformHandler.getDatabasePath(config.databaseName),
      ).called(1);
      verify(
        mockPlatformHandler.saveFile(any, config.exportFilename),
      ).called(1);
    });

    test('exportData handles export failure gracefully', () async {
      when(
        mockPlatformHandler.requestStoragePermission(),
      ).thenAnswer((_) async => true);
      when(
        mockPlatformHandler.getDatabasePath(any),
      ).thenThrow(Exception('Database error'));

      final result = await service.exportData();

      expect(result, isNull);
    });
  });

  group('Import Tests', () {
    test(
      'importData throws PermissionException when permission is denied',
      () async {
        when(
          mockPlatformHandler.requestStoragePermission(),
        ).thenAnswer((_) async => false);

        expect(() => service.importData(), throwsA(isA<PermissionException>()));
      },
    );

    test('importData handles successful import up to utility call', () async {
      when(
        mockPlatformHandler.requestStoragePermission(),
      ).thenAnswer((_) async => true);
      when(
        mockPlatformHandler.chooseImportFile(),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(
        mockPlatformHandler.getDatabasePath(any),
      ).thenAnswer((_) async => '/test/path/db.sqlite');

      // Only verify method calls, not the return value
      await service.importData();

      verify(mockPlatformHandler.requestStoragePermission()).called(1);
      verify(mockPlatformHandler.chooseImportFile()).called(1);
      verify(
        mockPlatformHandler.getDatabasePath(config.databaseName),
      ).called(1);
    });

    test('importData handles import cancellation', () async {
      when(
        mockPlatformHandler.requestStoragePermission(),
      ).thenAnswer((_) async => true);
      when(
        mockPlatformHandler.chooseImportFile(),
      ).thenAnswer((_) async => null);

      final result = await service.importData();

      expect(result, isFalse);
      verify(mockPlatformHandler.requestStoragePermission()).called(1);
      verify(mockPlatformHandler.chooseImportFile()).called(1);
    });

    test('importData handles import failure gracefully', () async {
      when(
        mockPlatformHandler.requestStoragePermission(),
      ).thenAnswer((_) async => true);
      when(
        mockPlatformHandler.chooseImportFile(),
      ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
      when(
        mockPlatformHandler.getDatabasePath(any),
      ).thenThrow(Exception('Database error'));

      final result = await service.importData();

      expect(result, isFalse);
    });
  });

  group('DatabaseExportImportUtils Tests', () {
    late MockSharedPreferences mockPrefs;
    late MockArchive mockArchive;
    late MockArchiveFile mockPrefsFile;

    setUp(() {
      mockPrefs = MockSharedPreferences();
      mockArchive = MockArchive();
      mockPrefsFile = MockArchiveFile();
    });

    test('prefsToMap converts SharedPreferences to Map correctly', () {
      when(mockPrefs.getKeys()).thenReturn({'key1', 'key2'});
      when(mockPrefs.get('key1')).thenReturn('value1');
      when(mockPrefs.get('key2')).thenReturn(42);

      final result = DatabaseExportImportUtils.prefsToMap(mockPrefs);

      expect(result, {'key1': 'value1', 'key2': 42});
    });

    test('prefsMapToJson and prefsJsonToMap work correctly', () {
      final testMap = {
        'string': 'value',
        'int': 42,
        'bool': true,
        'double': 3.14,
        'list': ['item1', 'item2'],
      };

      final json = DatabaseExportImportUtils.prefsMapToJson(testMap);
      final result = DatabaseExportImportUtils.prefsJsonToMap(json);

      expect(result, testMap);
    });

    test(
      'readDatabaseFromArchive handles successful database import',
      () async {
        // Use a temporary directory for file operations
        final tempDir = await Directory.systemTemp.createTemp('db_test');
        final dbPath = '${tempDir.path}/test.db';
        final dbContent = Uint8List.fromList([1, 2, 3]);

        final archive = Archive();
        final archiveFile = ArchiveFile('test.db', dbContent.length, dbContent);
        archive.addFile(archiveFile);

        final result = await DatabaseExportImportUtils.readDatabaseFromArchive(
          archive,
          'test.db',
          dbPath,
        );

        expect(result, isTrue);
        await tempDir.delete(recursive: true);
      },
    );

    test('readDatabaseFromArchive handles missing database file', () async {
      when(mockArchive.findFile(any)).thenReturn(null);

      final result = await DatabaseExportImportUtils.readDatabaseFromArchive(
        mockArchive,
        'test.db',
        '/test/path/test.db',
      );

      expect(result, isFalse);
    });

    test(
      'readPreferencesFromArchive handles successful preferences import',
      () async {
        when(mockArchive.findFile(any)).thenReturn(mockPrefsFile);
        when(
          mockPrefsFile.content,
        ).thenReturn(Uint8List.fromList(utf8.encode('{"key": "value"}')));

        final result =
            await DatabaseExportImportUtils.readPreferencesFromArchive(
              mockArchive,
              'prefs.json',
            );

        expect(result, isTrue);
      },
    );

    test(
      'readPreferencesFromArchive handles missing preferences file',
      () async {
        when(mockArchive.findFile(any)).thenReturn(null);

        final result =
            await DatabaseExportImportUtils.readPreferencesFromArchive(
              mockArchive,
              'prefs.json',
            );

        expect(result, isFalse);
      },
    );
  });
}
