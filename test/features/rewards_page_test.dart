import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/features/rewards/rewards_page.dart';
import 'package:betullarise/model/reward.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'rewards_page_test.mocks.dart';

void main() {
  late MockRewardsDatabaseHelper mockDbHelper;

  setUp(() {
    mockDbHelper = MockRewardsDatabaseHelper();
  });

  group('RewardsPage', () {
    testWidgets('renders loading indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => PointsProvider())],
          child: MaterialApp(home: RewardsPage(dbHelper: mockDbHelper)),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when no rewards', (
      WidgetTester tester,
    ) async {
      mockDbHelper.mockRewards = [];
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => PointsProvider())],
          child: MaterialApp(home: RewardsPage(dbHelper: mockDbHelper)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No rewards created'), findsOneWidget);
    });

    testWidgets('renders rewards list', (WidgetTester tester) async {
      mockDbHelper.mockRewards = [
        Reward(
          id: 1,
          title: 'Reward 1',
          description: 'Desc 1',
          type: 'single',
          points: 5.0,
          insertTime: 0,
          updateTime: 0,
        ),
        Reward(
          id: 2,
          title: 'Reward 2',
          description: 'Desc 2',
          type: 'multipler',
          points: 10.0,
          insertTime: 0,
          updateTime: 0,
        ),
      ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => PointsProvider())],
          child: MaterialApp(home: RewardsPage(dbHelper: mockDbHelper)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reward 1'), findsOneWidget);
      expect(find.text('Reward 2'), findsOneWidget);
    });

    testWidgets('search filters rewards list', (WidgetTester tester) async {
      mockDbHelper.mockRewards = [
        Reward(
          id: 1,
          title: 'Reward 1',
          description: 'Desc 1',
          type: 'single',
          points: 5.0,
          insertTime: 0,
          updateTime: 0,
        ),
        Reward(
          id: 2,
          title: 'Special',
          description: 'Desc 2',
          type: 'multipler',
          points: 10.0,
          insertTime: 0,
          updateTime: 0,
        ),
      ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => PointsProvider())],
          child: MaterialApp(home: RewardsPage(dbHelper: mockDbHelper)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Special');
      await tester.pumpAndSettle();
      // Verifica che il titolo della reward filtrata sia presente come discendente di Card
      final cardWithSpecial = find.ancestor(
        of: find.text('Special'),
        matching: find.byType(Card),
      );
      expect(cardWithSpecial, findsOneWidget);
      expect(find.text('Reward 1'), findsNothing);
    });

    testWidgets('can open new reward page with FAB', (
      WidgetTester tester,
    ) async {
      mockDbHelper.mockRewards = [];
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider(create: (_) => PointsProvider())],
          child: MaterialApp(home: RewardsPage(dbHelper: mockDbHelper)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('New Reward'), findsOneWidget);
    });
  });
}
