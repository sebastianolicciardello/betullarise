import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/theme_notifier.dart';

class ThemeSelectorWidget extends StatelessWidget {
  const ThemeSelectorWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select theme:', style: TextStyle(fontSize: 18)),
        RadioListTile<ThemeMode>(
          title: const Text('Automatic'),
          value: ThemeMode.system,
          groupValue: themeNotifier.themeMode,
          onChanged: (m) => m != null ? themeNotifier.setThemeMode(m) : null,
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Light'),
          value: ThemeMode.light,
          groupValue: themeNotifier.themeMode,
          onChanged: (m) => m != null ? themeNotifier.setThemeMode(m) : null,
        ),
        RadioListTile<ThemeMode>(
          title: const Text('Dark'),
          value: ThemeMode.dark,
          groupValue: themeNotifier.themeMode,
          onChanged: (m) => m != null ? themeNotifier.setThemeMode(m) : null,
        ),
      ],
    );
  }
}
