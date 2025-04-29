import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/task.dart';

void main() {
  group('Task model', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final task = Task(
      id: 1,
      title: 'Test',
      description: 'Desc',
      deadline: now + 1000,
      completionTime: 0,
      score: 5.0,
      penalty: 2.0,
      createdTime: now,
      updatedTime: now,
    );

    test('copyWith returns a new instance with updated values', () {
      final updated = task.copyWith(title: 'New', score: 10.0);
      expect(updated.title, 'New');
      expect(updated.score, 10.0);
      expect(updated.id, task.id);
    });

    test('toMap and fromMap produce equivalent object', () {
      final map = task.toMap();
      final fromMap = Task.fromMap(map);
      expect(fromMap.title, task.title);
      expect(fromMap.description, task.description);
      expect(fromMap.deadline, task.deadline);
      expect(fromMap.completionTime, task.completionTime);
      expect(fromMap.score, task.score);
      expect(fromMap.penalty, task.penalty);
      expect(fromMap.createdTime, task.createdTime);
      expect(fromMap.updatedTime, task.updatedTime);
    });
  });
}
