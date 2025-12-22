import 'dart:io';

import 'dart:async';
import 'package:betullarise/provider/theme_notifier.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/provider/tooltip_provider.dart';
import 'package:betullarise/provider/first_day_of_week_provider.dart';
import 'package:betullarise/provider/auto_backup_provider.dart';
import 'package:betullarise/provider/screen_time_provider.dart';
import 'package:betullarise/services/database_export_import_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'features/tasks/pages/tasks_page.dart';
import 'features/habits/habits_page.dart';
import 'features/rewards/rewards_page.dart';
import 'features/settings/settings_page.dart';
import 'features/screen_time/screen_time_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite_ffi for macOS
  if (Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
        ChangeNotifierProvider(create: (_) => TooltipProvider()),
        ChangeNotifierProvider(create: (_) => FirstDayOfWeekProvider()),
        ChangeNotifierProvider(create: (_) => ScreenTimeProvider()),
        ChangeNotifierProvider(
          create:
              (_) => AutoBackupProvider(
                exportService: DatabaseExportImportService(),
              ),
        ),
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
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', 'US'), // Sunday first
            Locale('en', 'GB'), // Monday first
          ],
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
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
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
              surface: Color(0xFF0D0D0D),
              onSurface: Colors.white,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0D0D0D),
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
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
      },
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

  final List<Widget> _pages = const [
    TasksPage(),
    HabitsPage(),
    ScreenTimePage(),
    RewardsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Load total points via the provider when the page is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      Provider.of<PointsProvider>(context, listen: false).loadAllPoints();

      // Check and perform auto-backup if needed
      final autoBackupProvider = Provider.of<AutoBackupProvider>(
        context,
        listen: false,
      );

      // Wait a bit more to ensure provider is fully initialized
      await Future.delayed(Duration(milliseconds: 500));

      await autoBackupProvider.checkAndPerformAutoBackup();
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
      _currentIndex = 3; // Rewards is now at index 3
    });
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to access total points from the provider
    return Consumer<PointsProvider>(
      builder: (context, pointsProvider, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            systemOverlayStyle:
                Theme.of(context).brightness == Brightness.dark
                    ? SystemUiOverlayStyle.light
                    : SystemUiOverlayStyle.dark,
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
                        size: 21.sp,
                        color: ColorScheme.of(context).primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '${(pointsProvider.totalPoints * 100).floor() / 100.0}',
                        style: TextStyle(
                          fontSize: 16.sp,
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
                iconSize: 21.sp,
                color: ColorScheme.of(context).primary,
                onPressed: () => _openSettings(context),
              ),
            ],
            automaticallyImplyLeading:
                false, // Disable the automatic back button
          ),
          body: _pages[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onItemTapped,
            selectedFontSize: 14.sp,
            unselectedFontSize: 12.sp,
            selectedIconTheme: IconThemeData(size: 28.sp),
            unselectedIconTheme: IconThemeData(size: 22.sp),
            selectedItemColor: ColorScheme.of(context).primary,
            unselectedItemColor: ColorScheme.of(
              context,
            ).onSurface.withValues(alpha: 0.6),
            backgroundColor: Theme.of(context).colorScheme.surface,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.task_alt_rounded),
                label: 'Tasks',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.loop_rounded),
                label: 'Habits',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.screen_lock_portrait),
                label: 'Screen Time',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.card_giftcard_rounded),
                label: 'Rewards',
              ),
            ],
          ),
        );
      },
    );
  }
}
