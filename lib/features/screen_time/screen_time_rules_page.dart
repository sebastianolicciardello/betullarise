import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../model/screen_time_rule.dart';
import '../../provider/screen_time_provider.dart';
import '../../services/ui/snackbar_service.dart';
import 'create_rule_page.dart';

class ScreenTimeRulesPage extends StatefulWidget {
  const ScreenTimeRulesPage({super.key});

  @override
  State<ScreenTimeRulesPage> createState() => _ScreenTimeRulesPageState();
}

class _ScreenTimeRulesPageState extends State<ScreenTimeRulesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage Rules',
          style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const CreateRulePage()),
              );
            },
            icon: Icon(Icons.add, size: 24.sp),
            tooltip: 'Create new rule',
          ),
        ],
      ),
      body: Consumer<ScreenTimeProvider>(
        builder: (context, screenTimeProvider, child) {
          if (screenTimeProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (screenTimeProvider.rules.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => screenTimeProvider.loadRules(),
            child: ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: screenTimeProvider.rules.length,
              itemBuilder: (context, index) {
                final rule = screenTimeProvider.rules[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: _buildRuleCard(context, rule, screenTimeProvider),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule, size: 80.sp, color: Colors.grey),
            SizedBox(height: 24.h),
            Text(
              'No Rules',
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
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateRulePage(),
                  ),
                );
              },
              icon: Icon(Icons.add, size: 20.sp),
              label: Text('Create Rule', style: TextStyle(fontSize: 16.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                foregroundColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.white
                        : Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleCard(
    BuildContext context,
    ScreenTimeRule rule,
    ScreenTimeProvider provider,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with name and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    rule.name,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                // Active/inactive toggle
                Switch(
                  value: rule.isActive,
                  onChanged: (value) async {
                    final success = await provider.toggleRuleActive(
                      rule.id!,
                      value,
                    );
                    if (success && context.mounted) {
                      SnackbarService.showSuccessSnackbar(
                        context,
                        'Rule ${value ? 'activated' : 'deactivated'}',
                      );
                    } else if (context.mounted) {
                      SnackbarService.showErrorSnackbar(
                        context,
                        'Errore nell\'aggiornamento della regola',
                      );
                    }
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Rule details
            Row(
              children: [
                Icon(
                  Icons.timer,
                  size: 20.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${rule.dailyTimeLimitMinutes} minutes per day',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            SizedBox(height: 8.h),

            Row(
              children: [
                Icon(Icons.warning, size: 20.sp, color: Colors.orange),
                SizedBox(width: 8.w),
                Text(
                  '${rule.penaltyPerMinuteExtra.abs().toStringAsFixed(2)} points/minute extra',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Included apps
            Row(
              children: [
                Icon(
                  Icons.apps,
                  size: 20.sp,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: 8.w),
                Text(
                  '${rule.appPackages.length} app${rule.appPackages.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // Actions
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    // TODO: Implement rule editing
                    SnackbarService.showErrorSnackbar(
                      context,
                      'Rule editing not yet implemented',
                    );
                  },
                  icon: Icon(Icons.edit, size: 18.sp),
                  label: Text('Edit', style: TextStyle(fontSize: 14.sp)),
                ),
                SizedBox(width: 8.w),
                TextButton.icon(
                  onPressed: () => _showDeleteDialog(context, rule, provider),
                  icon: Icon(Icons.delete, size: 18.sp, color: Colors.red),
                  label: Text(
                    'Delete',
                    style: TextStyle(fontSize: 14.sp, color: Colors.red),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    ScreenTimeRule rule,
    ScreenTimeProvider provider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Rule'),
            content: Text(
              'Are you sure you want to delete the rule "${rule.name}"? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop(); // Close dialog
                  final success = await provider.deleteRule(rule.id!);
                  if (success && context.mounted) {
                    SnackbarService.showSuccessSnackbar(
                      context,
                      'Rule "${rule.name}" deleted',
                    );
                  } else if (context.mounted) {
                    SnackbarService.showErrorSnackbar(
                      context,
                      'Errore nell\'eliminazione della regola',
                    );
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
