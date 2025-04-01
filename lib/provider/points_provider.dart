import 'package:flutter/foundation.dart';
import 'package:betullarise/database/points_database_helper.dart';

class PointsProvider with ChangeNotifier {
  double _totalPoints = 0;

  double get totalPoints => _totalPoints;

  // Carica i punti totali dal database
  Future<void> loadTotalPoints() async {
    try {
      final points = await PointsDatabaseHelper.instance.getTotalPoints();
      _totalPoints = points;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading points: ${e.toString()}');
    }
  }

  // Aggiunge punti e aggiorna il totale
  Future<void> addPoints(double points) async {
    try {
      // Aggiorna il valore in memoria
      _totalPoints += points;
      notifyListeners();

      // Nota: Non dobbiamo scrivere nel database qui perché
      // l'inserimento viene già fatto nella TasksPage
      // Questa funzione serve solo per aggiornare lo stato in memoria
    } catch (e) {
      debugPrint('Error adding points: ${e.toString()}');
    }
  }
}
