import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> setUpWidgetTest() async {
  // Setup shared preferences for testing
  SharedPreferences.setMockInitialValues({});
  TestWidgetsFlutterBinding.ensureInitialized();
}

Widget makeTestableWidget({required Widget child}) {
  return MaterialApp(home: child);
}
