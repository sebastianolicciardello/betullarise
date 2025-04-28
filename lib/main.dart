import 'dart:io';

import 'package:betullarise/features/tasks/handlers/expired_tasks_handler.dart';
import 'package:betullarise/provider/theme_notifier.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/tasks/pages/tasks_page.dart';
import 'features/habits/habits_page.dart';
import 'features/rewards/rewards_page.dart';
import 'features/settings/settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza sqflite_ffi per macOS
  if (Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: Colors.black,
          onPrimary: Colors.black,
          secondary: Colors.black,
          onSecondary: Colors.black,
          error: Colors.red,
          onError: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          bodySmall: TextStyle(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme(
          brightness: Brightness.dark,
          primary: Colors.white,
          onPrimary: Colors.white,
          secondary: Colors.white,
          onSecondary: Colors.white,
          error: Colors.red,
          onError: Colors.black,
          surface: Colors.black,
          onSurface: Colors.white,
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: themeNotifier.themeMode,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [TasksPage(), HabitsPage(), RewardsPage()];

  @override
  void initState() {
    super.initState();
    // Carica i punti totali tramite il provider quando la pagina viene inizializzata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PointsProvider>(context, listen: false).loadAllPoints();
      // Check for expired tasks when the app starts
      ExpiredTasksHandler.handleExpiredTasks(context);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _openSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void _openRewards(BuildContext context) {
    setState(() {
      _currentIndex = 2;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Usa Consumer per accedere ai punti totali dal provider
    return Consumer<PointsProvider>(
      builder: (context, pointsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _openRewards(context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.card_giftcard,
                        size: 21,
                        color: ColorScheme.of(context).primary,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${(pointsProvider.totalPoints * 100).floor() / 100.0}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color:
                              pointsProvider.totalPoints >= 0
                                  ? ColorScheme.of(context).primary
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                iconSize: 21,
                color: ColorScheme.of(context).primary,
                onPressed: () => _openSettings(context),
              ),
            ],
            automaticallyImplyLeading:
                false, // Disabilita il pulsante back automatico
          ),
          body: _pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.task_alt_rounded),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.loop_rounded),
                label: 'Habits',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.card_giftcard_rounded),
                label: 'Rewards',
              ),
            ],
          ),
        );
      },
    );
  }
}
