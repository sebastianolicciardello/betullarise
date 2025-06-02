import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DefaultPlatformHandler platformHandler;
  late DeviceInfoPlugin deviceInfo;

  setUp(() {
    platformHandler = DefaultPlatformHandler();
    deviceInfo = DeviceInfoPlugin();
  });

  group('Permission Handling Integration Tests', () {
    test(
      'requestStoragePermission returns correct result based on actual permissions',
      () async {
        // Request permissions
        final result = await platformHandler.requestStoragePermission();

        // Verify the result matches the actual permission state
        if (await Permission.photos.isGranted &&
            await Permission.videos.isGranted &&
            await Permission.audio.isGranted) {
          expect(result, isTrue);
        } else {
          expect(result, isFalse);
        }
      },
    );

    test(
      'isAndroid13OrHigher returns correct result based on actual device',
      () async {
        final result = await platformHandler.isAndroid13OrHigher();
        final androidInfo = await deviceInfo.androidInfo;

        if (androidInfo.version.sdkInt >= 33) {
          expect(result, isTrue);
        } else {
          expect(result, isFalse);
        }
      },
    );

    test(
      'Permission status is correctly reflected in export operation',
      () async {
        final service = DatabaseExportImportService();

        try {
          await service.exportData();
          // If we get here, permissions were granted
          expect(await Permission.photos.isGranted, isTrue);
          expect(await Permission.videos.isGranted, isTrue);
          expect(await Permission.audio.isGranted, isTrue);
        } catch (e) {
          // If we get here, permissions were denied
          expect(
            await Permission.photos.isGranted ||
                await Permission.videos.isGranted ||
                await Permission.audio.isGranted,
            isFalse,
          );
        }
      },
    );

    test(
      'Permission status is correctly reflected in import operation',
      () async {
        final service = DatabaseExportImportService();

        try {
          await service.importData();
          // If we get here, permissions were granted
          expect(await Permission.photos.isGranted, isTrue);
          expect(await Permission.videos.isGranted, isTrue);
          expect(await Permission.audio.isGranted, isTrue);
        } catch (e) {
          // If we get here, permissions were denied
          expect(
            await Permission.photos.isGranted ||
                await Permission.videos.isGranted ||
                await Permission.audio.isGranted,
            isFalse,
          );
        }
      },
    );
  });
}
