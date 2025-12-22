import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../provider/screen_time_provider.dart';
import '../../database/daily_screen_usage_database_helper.dart';
import 'create_rule_page.dart';
import 'edit_rule_page.dart';
import 'widgets/rule_card.dart';
import 'widgets/loading_indicator.dart';

class ScreenTimePage extends StatefulWidget {
  const ScreenTimePage({super.key});

  @override
  State<ScreenTimePage> createState() => _ScreenTimePageState();
}

class _ScreenTimePageState extends State<ScreenTimePage> {
  Map<int, int> _todayUsageMap = {}; // ruleId -> todayUsageMinutes
  Timer? _usageUpdateTimer;

  @override
  void initState() {
    super.initState();
    // Perform initial check when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialCheck();
    });

    // Set up periodic updates every 5 minutes
    _usageUpdateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) {
        _calculateTodayUsage();
      }
    });
  }

  @override
  void dispose() {
    _usageUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _performInitialCheck() async {
    try {
      debugPrint('ScreenTimePage: Starting initial check...');
      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );
      await screenTimeProvider.performInitialCheck();

      debugPrint('ScreenTimePage: Initial check completed');

      // Always calculate today's usage to check for new violations
      await _calculateTodayUsage();
      debugPrint('ScreenTimePage: Calculated today usage');
    } catch (e) {
      debugPrint('ScreenTimePage: Error in _performInitialCheck: $e');
      // Don't show error dialog to avoid loop
    }
  }

  Future<void> _calculateTodayUsage() async {
    try {
      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );

      final today = DateTime.now();
      final appsUsage = await screenTimeProvider.calculatePenaltiesForDate(
        today,
      );

      // Save penalties that have been calculated
      for (final usage in appsUsage) {
        if (usage.calculatedPenalty < 0) {
          // Only save if there's a penalty to apply
          // Check if this penalty is already confirmed for today
          final dbHelper = DailyScreenUsageDatabaseHelper.instance;
          final existingUsage = await dbHelper.queryDailyUsageByRuleAndDate(
            usage.ruleId,
            usage.date,
          );

          // Only save if no existing confirmed penalty for today
          if (existingUsage == null || !existingUsage.penaltyConfirmed) {
            await screenTimeProvider.saveDailyUsage(usage);
          }
        }
      }

      // Reload unconfirmed days to show new penalties
      await screenTimeProvider.checkForUnconfirmedDays();

      // Create a map of ruleId -> totalUsageMinutes
      final Map<int, int> usageMap = {};
      for (final usage in appsUsage) {
        usageMap[usage.ruleId] = usage.totalUsageMinutes;
      }

      if (mounted) {
        setState(() {
          _todayUsageMap = usageMap;
        });
      }

      debugPrint(
        'ScreenTimePage: Calculated today usage and saved penalties for ${usageMap.length} rules',
      );
    } catch (e) {
      debugPrint('ScreenTimePage: Error calculating today usage: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ScreenTimeProvider>(
        builder: (context, screenTimeProvider, child) {
          if (screenTimeProvider.isLoading) {
            return const LoadingIndicator(
              message: 'Loading screen time rules...',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await screenTimeProvider.performInitialCheck();
              // Always calculate today usage to check for new violations
              await _calculateTodayUsage();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Permission banner if not granted
                  if (!screenTimeProvider.hasPermission)
                    _buildPermissionBanner(screenTimeProvider),
                  // List of active rules
                  if (screenTimeProvider.rules.isEmpty)
                    _buildEmptyState(screenTimeProvider)
                  else
                    _buildRulesList(screenTimeProvider),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context)
              .push(
                MaterialPageRoute(builder: (context) => const CreateRulePage()),
              )
              .then((_) => _performInitialCheck());
        },
        tooltip: 'Create new rule',
        backgroundColor:
            Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
        foregroundColor:
            Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
        child: Icon(Icons.add, size: 24.sp),
      ),
    );
  }

  Widget _buildEmptyState(ScreenTimeProvider screenTimeProvider) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule, size: 80.sp, color: Colors.grey),
            SizedBox(height: 24.h),
            Text(
              'No Rules Created',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Create your first rule to monitor time spent on apps.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            if (!screenTimeProvider.hasPermission)
              Text(
                'Note: grant permission to enable automatic monitoring.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 32.h),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(ScreenTimeProvider screenTimeProvider) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.grey.shade700, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Permission required to monitor app usage. Grant permission to enable rules.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  Theme.of(context).brightness == Brightness.light
                      ? Colors.black
                      : Colors.white,
              foregroundColor:
                  Theme.of(context).brightness == Brightness.light
                      ? Colors.white
                      : Colors.black,
            ),
            onPressed: () {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        'How to grant permission',
                        style: TextStyle(fontSize: 18.sp),
                      ),
                      content: Text(
                        'To monitor app usage, you need to manually grant permission to access usage data:\n\n'
                        '1. Open phone Settings\n'
                        '2. Go to "Apps" or "Applications"\n'
                        '3. Find and select "Betullarise"\n'
                        '4. Go to "Permissions" or "Authorizations"\n'
                        '5. Enable "Access to usage data"\n\n'
                        'After granting permission, return to the app and reload.',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white,
                            foregroundColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.white
                                    : Colors.black,
                          ),
                          onPressed: () async {
                            // Try to open settings
                            try {
                              await screenTimeProvider
                                  .requestUsageStatsPermission();
                            } catch (e) {
                              debugPrint('Error opening settings: $e');
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(
                            'Open Settings',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: Text('Grant', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesList(ScreenTimeProvider screenTimeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: screenTimeProvider.rules.length,
          itemBuilder: (context, index) {
            final rule = screenTimeProvider.rules[index];
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context)
                      .push(
                        MaterialPageRoute(
                          builder: (context) => EditRulePage(rule: rule),
                        ),
                      )
                      .then((_) {
                        // Refresh data after returning from edit page
                        if (mounted) {
                          _performInitialCheck();
                        }
                      });
                },
                child: Card(
                  margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  child: RuleCard(
                    rule: rule,
                    todayUsageMinutes: _todayUsageMap[rule.id],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
