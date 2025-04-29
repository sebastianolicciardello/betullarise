import 'package:flutter_test/flutter_test.dart';
import 'package:betullarise/model/point.dart';

void main() {
  group('Point model', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final point = Point(
      id: 1,
      referenceId: 2,
      type: 'task',
      points: 5.5,
      insertTime: now,
    );

    test('copyWith returns a new instance with updated values', () {
      final updated = point.copyWith(points: 10.0, type: 'habit');
      expect(updated.points, 10.0);
      expect(updated.type, 'habit');
      expect(updated.id, point.id);
    });

    test('toMap and fromMap produce equivalent object', () {
      final map = point.toMap();
      final fromMap = Point.fromMap(map);
      expect(fromMap.referenceId, point.referenceId);
      expect(fromMap.type, point.type);
      expect(fromMap.points, point.points);
      expect(fromMap.insertTime, point.insertTime);
    });

    test('toString returns a string', () {
      expect(point.toString(), contains('Point'));
    });
  });
}
