import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/features/rewards/rewards_detail_page.dart';
import 'package:betullarise/model/reward.dart';

void main() {
  group('RewardDetailPage', () {
    testWidgets('renders empty form for new reward', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RewardDetailPage()));
      expect(find.text('New Reward'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.text('Save Reward'), findsOneWidget);
    });

    testWidgets('renders form with reward data for editing', (
      WidgetTester tester,
    ) async {
      final reward = Reward(
        id: 1,
        title: 'Test Reward',
        description: 'Test Description',
        type: 'single',
        points: 10.0,
        insertTime: 0,
        updateTime: 0,
      );
      await tester.pumpWidget(
        MaterialApp(home: RewardDetailPage(reward: reward)),
      );
      expect(find.text('Edit Reward'), findsOneWidget);
      expect(find.text('Test Reward'), findsOneWidget);
      expect(find.text('Test Description'), findsOneWidget);
      expect(find.text('10.0'), findsOneWidget);
      expect(find.text('Update Reward'), findsOneWidget);
    });

    testWidgets('shows validation errors if fields are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RewardDetailPage()));
      // Svuota il campo points (che di default è 1.0)
      await tester.enterText(find.byType(TextFormField).last, '');
      await tester.tap(find.text('Save Reward'));
      await tester.pump();
      expect(find.text('Please enter a title'), findsOneWidget);
      expect(find.text('Please enter points'), findsOneWidget);
      // Verifica anche il messaggio per valore non valido
      await tester.enterText(find.byType(TextFormField).last, '-1');
      await tester.tap(find.text('Save Reward'));
      await tester.pump();
      expect(find.text('Points must be greater than 0'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, 'abc');
      await tester.tap(find.text('Save Reward'));
      await tester.pump();
      expect(find.text('Please enter a valid number'), findsOneWidget);
    });

    testWidgets('shows discard changes dialog when editing and pressing back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: RewardDetailPage()));
      // Modifica un campo
      await tester.enterText(find.byType(TextFormField).first, 'Changed title');
      await tester.pumpAndSettle();
      // Premi il tasto back nell'app bar
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      // Verifica che compaia il dialog di conferma
      expect(find.textContaining('discard'), findsOneWidget);
      expect(find.text('Discard'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });
  });
}
