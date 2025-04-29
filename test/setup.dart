import 'package:flutter/widgets.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void setupTestEnvironment() {
  // Inizializza FFI per SQLite
  sqfliteFfiInit();

  // Imposta il factory da utilizzare per i test
  databaseFactory = databaseFactoryFfi;

  // Abilita i messaggi di errore per il debug
  WidgetsFlutterBinding.ensureInitialized();
}
