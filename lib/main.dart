import 'dart:io';

import 'dart:async';
import 'dart:developer' as developer;
import 'package:betullarise/provider/theme_notifier.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/provider/tooltip_provider.dart';
import 'package:betullarise/provider/first_day_of_week_provider.dart';
import 'package:betullarise/provider/auto_backup_provider.dart';
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

  final List<Widget> _pages = const [TasksPage(), HabitsPage(), RewardsPage()];

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

      final backupResult = await autoBackupProvider.checkAndPerformAutoBackup();

      // Always show a message about auto-backup status for debugging
      if (mounted) {
        if (backupResult) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Auto-backup completed successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          final error = autoBackupProvider.lastError;
          if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('❌ Auto-backup failed: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Details',
                  textColor: Colors.white,
                  onPressed: () {
                    // Navigate to settings to see more details
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsPage(),
                      ),
                    );
                  },
                ),
              ),
            );

            // Schedule a retry after 10 seconds if backup failed
            Timer(Duration(seconds: 10), () async {
              if (mounted &&
                  autoBackupProvider.isEnabled &&
                  autoBackupProvider.backupFolderPath != null) {
                developer.log(
                  'Retrying auto-backup after delay...',
                  name: 'HomePage',
                );
                final retryResult =
                    await autoBackupProvider.checkAndPerformAutoBackup();
                if (mounted && retryResult) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔄 Auto-backup retry successful!'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            });
          } else {
            // Backup was skipped (disabled, no folder, or already done today)
            String reason = '';
            if (!autoBackupProvider.isEnabled) {
              reason = 'Auto-backup is disabled';
            } else if (autoBackupProvider.backupFolderPath == null) {
              reason = 'No backup folder configured';
            } else if (autoBackupProvider.lastBackupDate != null) {
              final now = DateTime.now();
              final last = autoBackupProvider.lastBackupDate!;
              if (now.year == last.year &&
                  now.month == last.month &&
                  now.day == last.day) {
                reason = 'Backup already completed today';
              }
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ℹ️ Auto-backup skipped: $reason'),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }
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
