import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:betullarise/features/settings/widgets/data_management_widget.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

import 'data_management_widget_test.mocks.dart';

// Generate mocks
@GenerateNiceMocks([
  MockSpec<DatabaseExportImportService>(),
  MockSpec<DialogService>(),
])
void main() {
  late MockDatabaseExportImportService mockExportImportService;
  late MockDialogService mockDialogService;

  setUp(() {
    mockExportImportService = MockDatabaseExportImportService();
    mockDialogService = MockDialogService();
  });

  testWidgets('DataManagementWidget should render correctly', (
    WidgetTester tester,
  ) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataManagementWidget(
            exportImportService: mockExportImportService,
            dialogService: mockDialogService,
          ),
        ),
      ),
    );

    // Assert
    expect(find.text('Data Management:'), findsOneWidget);
    expect(find.text('Export Data'), findsOneWidget);
    expect(find.text('Import Data'), findsOneWidget);
  });

  testWidgets('Export flow should work correctly', (WidgetTester tester) async {
    // Arrange
    const exportPath = '/path/to/export.zip';
    when(
      mockExportImportService.exportData(),
    ).thenAnswer((_) async => exportPath);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataManagementWidget(
            exportImportService: mockExportImportService,
            dialogService: mockDialogService,
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Export Data'));
    await tester.pump();

    // Verify loading dialog is shown
    verify(
      mockDialogService.showLoadingDialog(any, 'Exporting data...'),
    ).called(1);

    // Simulate export completion
    await tester.pump();

    // Verify export was called
    verify(mockExportImportService.exportData()).called(1);

    // Verify success dialog is shown with correct path
    verify(
      mockDialogService.showResultDialog(
        any,
        'Data Exported',
        'Your data has been exported to:\n$exportPath',
      ),
    ).called(1);
  });

  testWidgets('Export flow should handle failure correctly', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(mockExportImportService.exportData()).thenAnswer((_) async => null);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataManagementWidget(
            exportImportService: mockExportImportService,
            dialogService: mockDialogService,
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Export Data'));
    await tester.pump();

    // Verify loading dialog is shown
    verify(
      mockDialogService.showLoadingDialog(any, 'Exporting data...'),
    ).called(1);

    // Simulate export completion
    await tester.pump();

    // Verify export was called
    verify(mockExportImportService.exportData()).called(1);

    // Verify failure dialog is shown
    verify(
      mockDialogService.showResultDialog(
        any,
        'Export Failed',
        'Failed to export data. Please try again.',
      ),
    ).called(1);
  });

  testWidgets('Import flow should work correctly when user confirms', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(
      mockDialogService.showConfirmDialog(any, 'Import Data', any),
    ).thenAnswer((_) async => true);
    when(mockExportImportService.importData()).thenAnswer((_) async => true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataManagementWidget(
            exportImportService: mockExportImportService,
            dialogService: mockDialogService,
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Import Data'));
    await tester.pump();

    // Verify confirm dialog is shown
    verify(
      mockDialogService.showConfirmDialog(
        any,
        'Import Data',
        'This will overwrite your current data. Make sure you have a backup. Continue?',
      ),
    ).called(1);

    // Simulate confirmation dialog completion
    await tester.pump();

    // Verify loading dialog is shown
    verify(
      mockDialogService.showLoadingDialog(any, 'Importing data...'),
    ).called(1);

    // Simulate import completion
    await tester.pump();

    // Verify import was called
    verify(mockExportImportService.importData()).called(1);

    // Verify success dialog is shown
    verify(
      mockDialogService.showResultDialog(
        any,
        'Data Imported',
        'Your data has been imported successfully. Please restart the app for changes to take effect.',
      ),
    ).called(1);
  });

  testWidgets('Import flow should stop when user cancels', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(
      mockDialogService.showConfirmDialog(any, 'Import Data', any),
    ).thenAnswer((_) async => false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataManagementWidget(
            exportImportService: mockExportImportService,
            dialogService: mockDialogService,
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Import Data'));
    await tester.pump();

    // Verify confirm dialog is shown
    verify(
      mockDialogService.showConfirmDialog(
        any,
        'Import Data',
        'This will overwrite your current data. Make sure you have a backup. Continue?',
      ),
    ).called(1);

    // Verify that no other dialogs are shown and import is not called
    verifyNever(mockDialogService.showLoadingDialog(any, any));
    verifyNever(mockExportImportService.importData());
    verifyNever(mockDialogService.showResultDialog(any, any, any));
  });

  testWidgets('Import flow should handle failure correctly', (
    WidgetTester tester,
  ) async {
    // Arrange
    when(
      mockDialogService.showConfirmDialog(any, 'Import Data', any),
    ).thenAnswer((_) async => true);
    when(mockExportImportService.importData()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DataManagementWidget(
            exportImportService: mockExportImportService,
            dialogService: mockDialogService,
          ),
        ),
      ),
    );

    // Act
    await tester.tap(find.text('Import Data'));
    await tester.pump();

    // Verify confirm dialog is shown
    verify(
      mockDialogService.showConfirmDialog(
        any,
        'Import Data',
        'This will overwrite your current data. Make sure you have a backup. Continue?',
      ),
    ).called(1);

    // Simulate confirmation dialog completion
    await tester.pump();

    // Verify loading dialog is shown
    verify(
      mockDialogService.showLoadingDialog(any, 'Importing data...'),
    ).called(1);

    // Simulate import completion
    await tester.pump();

    // Verify import was called
    verify(mockExportImportService.importData()).called(1);

    // Verify failure dialog is shown
    verify(
      mockDialogService.showResultDialog(
        any,
        'Import Failed',
        'Failed to import data. Please make sure the backup file is valid.',
      ),
    ).called(1);
  });
}
