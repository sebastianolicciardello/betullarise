import 'package:flutter/foundation.dart';
import 'package:betullarise/database/points_database_helper.dart';

import '../model/point.dart';

class PointsProvider with ChangeNotifier {
  double _totalPoints = 0;
  double _taskPoints = 0;
  double _habitPoints = 0;

  double get totalPoints => _totalPoints;
  double get taskPoints => _taskPoints;
  double get habitPoints => _habitPoints;

  // Load all points from the database
  Future<void> loadAllPoints() async {
    try {
      _totalPoints = await PointsDatabaseHelper.instance.getTotalPoints();
      _taskPoints = await PointsDatabaseHelper.instance.getTotalPointsByType(
        'task',
      );
      _habitPoints = await PointsDatabaseHelper.instance.getTotalPointsByType(
        'habit',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading points: ${e.toString()}');
    }
  }

  // Add points and update the total
  Future<void> savePoints(Point point) async {
    try {
      // Insert or update the point in the database
      await PointsDatabaseHelper.instance.insertPoint(point);

      // Update in-memory values
      await loadAllPoints();
    } catch (e) {
      debugPrint('Error adding points: ${e.toString()}');
    }
  }

  // Remove points for a specific reference and type
  Future<void> removePoints(int referenceId, String type) async {
    try {
      await PointsDatabaseHelper.instance.deletePoint(referenceId, type);
      await loadAllPoints();
    } catch (e) {
      debugPrint('Error removing points: ${e.toString()}');
    }
  }

  // Remove points for a specific point
  Future<void> removePointsByEntity(Point point) async {
    try {
      await PointsDatabaseHelper.instance.deletePointUndo(
        point.referenceId!,
        point.type,
        point.insertTime,
      );
      await loadAllPoints();
    } catch (e) {
      debugPrint('Error removing points: ${e.toString()}');
    }
  }
}
