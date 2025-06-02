import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'platform_handler_test.mocks.dart';
import 'package:platform/platform.dart';

@GenerateMocks([
  DeviceInfoPlugin,
  AndroidDeviceInfo,
  AndroidBuildVersion,
  PermissionRequester,
])
void main() {
  late MockPermissionRequester mockPermissionRequester;
  late MockDeviceInfoPlugin mockDeviceInfo;
  late MockAndroidDeviceInfo mockAndroidInfo;
  late MockAndroidBuildVersion mockBuildVersion;
  late FakePlatform fakePlatform;

  setUp(() {
    mockPermissionRequester = MockPermissionRequester();
    mockDeviceInfo = MockDeviceInfoPlugin();
    mockAndroidInfo = MockAndroidDeviceInfo();
    mockBuildVersion = MockAndroidBuildVersion();
    fakePlatform = FakePlatform(operatingSystem: 'android');

    // Reset all mocks
    reset(mockPermissionRequester);
    reset(mockDeviceInfo);
    reset(mockAndroidInfo);
    reset(mockBuildVersion);

    // Set up default stubs for common calls
    when(mockAndroidInfo.version).thenReturn(mockBuildVersion);
    when(mockDeviceInfo.androidInfo).thenAnswer((_) async => mockAndroidInfo);
  });

  group('Android Permission Tests', () {
    test(
      'requestStoragePermission on Android 15 (API 34+) requests correct permissions',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(34);
        when(
          mockPermissionRequester.requestPhotos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));
        when(
          mockPermissionRequester.requestVideos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));
        when(
          mockPermissionRequester.requestAudio(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isTrue);
        verify(mockPermissionRequester.requestPhotos()).called(1);
        verify(mockPermissionRequester.requestVideos()).called(1);
        verify(mockPermissionRequester.requestAudio()).called(1);
      },
    );

    test(
      'requestStoragePermission on Android 13 (API 33) requests correct permissions',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(33);
        when(
          mockPermissionRequester.requestPhotos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isTrue);
        verify(mockPermissionRequester.requestPhotos()).called(1);
        verifyNever(mockPermissionRequester.requestVideos());
        verifyNever(mockPermissionRequester.requestAudio());
      },
    );

    test(
      'requestStoragePermission on Android 12 (API 31) requests legacy storage permission',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(31);
        when(
          mockPermissionRequester.requestStorage(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isTrue);
        verify(mockPermissionRequester.requestStorage()).called(1);
        verifyNever(mockPermissionRequester.requestPhotos());
        verifyNever(mockPermissionRequester.requestVideos());
        verifyNever(mockPermissionRequester.requestAudio());
      },
    );

    test(
      'requestStoragePermission handles denied permissions correctly',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(34);
        when(
          mockPermissionRequester.requestPhotos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.denied));
        when(
          mockPermissionRequester.requestVideos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));
        when(
          mockPermissionRequester.requestAudio(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isFalse);
        verify(mockPermissionRequester.requestPhotos()).called(1);
        verify(mockPermissionRequester.requestVideos()).called(1);
        verify(mockPermissionRequester.requestAudio()).called(1);
      },
    );

    test(
      'requestStoragePermission handles permanently denied permissions correctly',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(34);
        when(
          mockPermissionRequester.requestPhotos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.permanentlyDenied));
        when(
          mockPermissionRequester.requestVideos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));
        when(
          mockPermissionRequester.requestAudio(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isFalse);
        verify(mockPermissionRequester.requestPhotos()).called(1);
        verify(mockPermissionRequester.requestVideos()).called(1);
        verify(mockPermissionRequester.requestAudio()).called(1);
      },
    );

    test(
      'requestStoragePermission handles restricted permissions correctly',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(34);
        when(
          mockPermissionRequester.requestPhotos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.restricted));
        when(
          mockPermissionRequester.requestVideos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));
        when(
          mockPermissionRequester.requestAudio(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isFalse);
        verify(mockPermissionRequester.requestPhotos()).called(1);
        verify(mockPermissionRequester.requestVideos()).called(1);
        verify(mockPermissionRequester.requestAudio()).called(1);
      },
    );

    test(
      'requestStoragePermission handles limited permissions correctly',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(34);
        when(
          mockPermissionRequester.requestPhotos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.limited));
        when(
          mockPermissionRequester.requestVideos(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));
        when(
          mockPermissionRequester.requestAudio(),
        ).thenAnswer((_) => Future.value(PermissionStatus.granted));

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.requestStoragePermission();
        expect(result, isFalse);
        verify(mockPermissionRequester.requestPhotos()).called(1);
        verify(mockPermissionRequester.requestVideos()).called(1);
        verify(mockPermissionRequester.requestAudio()).called(1);
      },
    );
  });

  group('isAndroid13OrHigher Tests', () {
    test('isAndroid13OrHigher returns true for Android 13+', () async {
      // Set up specific stubs for this test
      when(mockBuildVersion.sdkInt).thenReturn(33);

      final platformHandler = DefaultPlatformHandler(
        permissionRequester: mockPermissionRequester,
        deviceInfo: mockDeviceInfo,
        platform: fakePlatform,
      );

      final result = await platformHandler.isAndroid13OrHigher();
      expect(result, isTrue);
    });

    test(
      'isAndroid13OrHigher returns false for Android 12 and below',
      () async {
        // Set up specific stubs for this test
        when(mockBuildVersion.sdkInt).thenReturn(31);

        final platformHandler = DefaultPlatformHandler(
          permissionRequester: mockPermissionRequester,
          deviceInfo: mockDeviceInfo,
          platform: fakePlatform,
        );

        final result = await platformHandler.isAndroid13OrHigher();
        expect(result, isFalse);
      },
    );
  });
}
