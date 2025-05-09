import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

void main() {
  late DialogService dialogService;

  setUp(() {
    dialogService = DialogService();
  });

  group('DialogService', () {
    testWidgets('showLoadingDialog shows loading dialog with message', (
      WidgetTester tester,
    ) async {
      late BuildContext savedContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              savedContext = context;
              return const Placeholder();
            },
          ),
        ),
      );

      final dialog = dialogService.showLoadingDialog(
        savedContext,
        'Loading...',
      );
      Navigator.of(savedContext).push(dialog);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('showConfirmDialog shows dialog and returns correct value', (
      WidgetTester tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  result = await dialogService.showConfirmDialog(
                    context,
                    'Test Title',
                    'Test Message',
                    confirmText: 'Yes',
                    cancelText: 'No',
                    isDangerous: true,
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Test Message'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(result, true);

      // Test cancel button
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(result, false);
    });

    testWidgets('showResultDialog shows dialog with correct content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () {
                  dialogService.showResultDialog(
                    context,
                    'Result Title',
                    'Result Message',
                    buttonText: 'Close',
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Result Title'), findsOneWidget);
      expect(find.text('Result Message'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('showInputDialog shows dialog and returns input value', (
      WidgetTester tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              return TextButton(
                onPressed: () async {
                  result = await dialogService.showInputDialog(
                    context,
                    'Input Title',
                    message: 'Enter value',
                    initialValue: 'Initial',
                    labelText: 'Input',
                    validator:
                        (value) =>
                            value?.isEmpty == true ? 'Cannot be empty' : null,
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Input Title'), findsOneWidget);
      expect(find.text('Enter value'), findsOneWidget);
      expect(find.text('Initial'), findsOneWidget);

      // Test validation
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Cannot be empty'), findsOneWidget);

      // Test valid input
      await tester.enterText(find.byType(TextFormField), 'Test Input');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result, 'Test Input');
    });

    testWidgets(
      'showSelectionDialog shows dialog with items and returns selected value',
      (WidgetTester tester) async {
        final items = ['Item 1', 'Item 2', 'Item 3'];
        String? result;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (BuildContext context) {
                return TextButton(
                  onPressed: () async {
                    result = await dialogService.showSelectionDialog<String>(
                      context,
                      'Select Item',
                      items,
                      message: 'Choose an item',
                      itemLabelBuilder: (item) => 'Option: $item',
                    );
                  },
                  child: const Text('Show Dialog'),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Select Item'), findsOneWidget);
        expect(find.text('Choose an item'), findsOneWidget);
        expect(find.text('Option: Item 1'), findsOneWidget);
        expect(find.text('Option: Item 2'), findsOneWidget);
        expect(find.text('Option: Item 3'), findsOneWidget);

        await tester.tap(find.text('Option: Item 2'));
        await tester.pumpAndSettle();
        expect(result, 'Item 2');
      },
    );
  });
}
