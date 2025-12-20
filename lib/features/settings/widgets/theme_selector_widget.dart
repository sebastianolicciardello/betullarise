import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/theme_notifier.dart';

class ThemeSelectorWidget extends StatelessWidget {
  const ThemeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return RadioGroup<ThemeMode>(
      groupValue: themeNotifier.themeMode,
      onChanged: (m) => m != null ? themeNotifier.setThemeMode(m) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Select theme:', style: TextStyle(fontSize: 18.sp)),
          RadioListTile<ThemeMode>(
            title: const Text('Automatic'),
            value: ThemeMode.system,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
          ),
        ],
      ),
    );
  }
}
