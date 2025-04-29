import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/habit.dart';

void main() {
  group('Habit model', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final habit = Habit(
      id: 1,
      title: 'Test',
      description: 'Desc',
      score: 5.0,
      penalty: 2.0,
      type: 'single',
      createdTime: now,
      updatedTime: now,
    );

    test('copyWith returns a new instance with updated values', () {
      final updated = habit.copyWith(title: 'New', score: 10.0);
      expect(updated.title, 'New');
      expect(updated.score, 10.0);
      expect(updated.id, habit.id);
    });

    test('toMap and fromMap produce equivalent object', () {
      final map = habit.toMap();
      final fromMap = Habit.fromMap(map);
      expect(fromMap.title, habit.title);
      expect(fromMap.description, habit.description);
      expect(fromMap.score, habit.score);
      expect(fromMap.penalty, habit.penalty);
      expect(fromMap.type, habit.type);
      expect(fromMap.createdTime, habit.createdTime);
      expect(fromMap.updatedTime, habit.updatedTime);
    });

    test('assert throws for invalid type', () {
      expect(
        () => Habit(
          id: 2,
          title: 'Invalid',
          description: 'Invalid',
          score: 1.0,
          penalty: 1.0,
          type: 'invalid',
          createdTime: now,
          updatedTime: now,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
