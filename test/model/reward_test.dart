import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/reward.dart';

void main() {
  group('Reward model', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final reward = Reward(
      id: 1,
      title: 'Reward',
      description: 'Desc',
      type: 'single',
      points: 10.0,
      insertTime: now,
      updateTime: now,
    );

    test('copyWith returns a new instance with updated values', () {
      final updated = reward.copyWith(title: 'New', points: 20.0);
      expect(updated.title, 'New');
      expect(updated.points, 20.0);
      expect(updated.id, reward.id);
    });

    test('toMap and fromMap produce equivalent object', () {
      final map = reward.toMap();
      final fromMap = Reward.fromMap(map);
      expect(fromMap.title, reward.title);
      expect(fromMap.description, reward.description);
      expect(fromMap.type, reward.type);
      expect(fromMap.points, reward.points);
      expect(fromMap.insertTime, reward.insertTime);
      expect(fromMap.updateTime, reward.updateTime);
    });

    test('toString returns a string', () {
      expect(reward.toString(), contains('Reward'));
    });
  });
}
