import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../provider/theme_notifier.dart';
import '../../../provider/tooltip_provider.dart';

class InterfaceSectionWidget extends StatelessWidget {
  const InterfaceSectionWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Interface',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            // Theme Dropdown
            Consumer<ThemeNotifier>(
              builder: (context, themeNotifier, child) {
                return DropdownButtonFormField<ThemeMode>(
                  decoration: const InputDecoration(
                    labelText: 'Theme',
                    border: OutlineInputBorder(),
                  ),
                  value: themeNotifier.themeMode,
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('System'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      themeNotifier.setThemeMode(value);
                    }
                  },
                );
              },
            ),
            SizedBox(height: 16.h),
            // Info Tooltips Switch
            Consumer<TooltipProvider>(
              builder: (context, tooltipProvider, child) {
                return SwitchListTile(
                  title: const Text('Info Tooltips'),
                  value: tooltipProvider.showTooltips,
                  onChanged: (value) {
                    tooltipProvider.setShowTooltips(value);
                  },
                  contentPadding: EdgeInsets.zero,
                  activeColor: Theme.of(context).colorScheme.primary,
                  activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}