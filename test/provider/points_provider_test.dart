import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/database/points_database_helper.dart';
import 'package:betullarise/model/point.dart';

// Generiamo i mock per PointsDatabaseHelper
@GenerateMocks([PointsDatabaseHelper])
import 'points_provider_test.mocks.dart';

void main() {
  late PointsProvider pointsProvider;
  late MockPointsDatabaseHelper mockDatabaseHelper;

  setUpAll(() {
    // Inizializziamo il binding di Flutter per i test
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    // Inizializziamo il mock del database helper
    mockDatabaseHelper = MockPointsDatabaseHelper();
    // Inizializziamo il provider con il mock
    pointsProvider = PointsProvider(databaseHelper: mockDatabaseHelper);
  });

  group('PointsProvider', () {
    test('initializes with zero points', () {
      // Verifichiamo che i punti iniziali siano zero
      expect(pointsProvider.totalPoints, equals(0));
      expect(pointsProvider.taskPoints, equals(0));
      expect(pointsProvider.habitPoints, equals(0));
    });

    test('loads points correctly from database', () async {
      // Configuriamo il mock per restituire valori specifici
      when(mockDatabaseHelper.getTotalPoints()).thenAnswer((_) async => 100.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('task'),
      ).thenAnswer((_) async => 60.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('habit'),
      ).thenAnswer((_) async => 40.0);

      // Carichiamo i punti
      await pointsProvider.loadAllPoints();

      // Verifichiamo che i punti siano stati caricati correttamente
      expect(pointsProvider.totalPoints, equals(100.0));
      expect(pointsProvider.taskPoints, equals(60.0));
      expect(pointsProvider.habitPoints, equals(40.0));
    });

    test('saves points correctly', () async {
      // Creiamo un punto di test
      final testPoint = Point(
        referenceId: 1,
        type: 'task',
        points: 10.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Configuriamo il mock per il salvataggio
      when(
        mockDatabaseHelper.insertPoint(testPoint),
      ).thenAnswer((_) async => 1);

      // Configuriamo il mock per il caricamento successivo
      when(mockDatabaseHelper.getTotalPoints()).thenAnswer((_) async => 10.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('task'),
      ).thenAnswer((_) async => 10.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('habit'),
      ).thenAnswer((_) async => 0.0);

      // Salviamo il punto
      await pointsProvider.savePoints(testPoint);

      // Verifichiamo che il punto sia stato salvato
      verify(mockDatabaseHelper.insertPoint(testPoint)).called(1);

      // Verifichiamo che i punti siano stati aggiornati
      expect(pointsProvider.totalPoints, equals(10.0));
      expect(pointsProvider.taskPoints, equals(10.0));
      expect(pointsProvider.habitPoints, equals(0.0));
    });

    test('removes points by reference ID and type', () async {
      // Configuriamo il mock per la rimozione
      when(
        mockDatabaseHelper.deletePoint(1, 'task'),
      ).thenAnswer((_) async => 1);

      // Configuriamo il mock per il caricamento successivo
      when(mockDatabaseHelper.getTotalPoints()).thenAnswer((_) async => 0.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('task'),
      ).thenAnswer((_) async => 0.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('habit'),
      ).thenAnswer((_) async => 0.0);

      // Rimuoviamo i punti
      await pointsProvider.removePoints(1, 'task');

      // Verifichiamo che i punti siano stati rimossi
      verify(mockDatabaseHelper.deletePoint(1, 'task')).called(1);

      // Verifichiamo che i punti siano stati aggiornati
      expect(pointsProvider.totalPoints, equals(0.0));
      expect(pointsProvider.taskPoints, equals(0.0));
      expect(pointsProvider.habitPoints, equals(0.0));
    });

    test('removes points by entity', () async {
      // Creiamo un punto di test
      final testPoint = Point(
        referenceId: 1,
        type: 'task',
        points: 10.0,
        insertTime: DateTime.now().millisecondsSinceEpoch,
      );

      // Configuriamo il mock per la rimozione
      when(
        mockDatabaseHelper.deletePointUndo(1, 'task', testPoint.insertTime),
      ).thenAnswer((_) async => 1);

      // Configuriamo il mock per il caricamento successivo
      when(mockDatabaseHelper.getTotalPoints()).thenAnswer((_) async => 0.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('task'),
      ).thenAnswer((_) async => 0.0);
      when(
        mockDatabaseHelper.getTotalPointsByType('habit'),
      ).thenAnswer((_) async => 0.0);

      // Rimuoviamo i punti
      await pointsProvider.removePointsByEntity(testPoint);

      // Verifichiamo che i punti siano stati rimossi
      verify(
        mockDatabaseHelper.deletePointUndo(1, 'task', testPoint.insertTime),
      ).called(1);

      // Verifichiamo che i punti siano stati aggiornati
      expect(pointsProvider.totalPoints, equals(0.0));
      expect(pointsProvider.taskPoints, equals(0.0));
      expect(pointsProvider.habitPoints, equals(0.0));
    });
  });
}
