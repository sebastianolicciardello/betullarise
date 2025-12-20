import 'package:flutter/material.dart';

class HabitCompletionDatePickerService {
  static Future<DateTime?> showCompletionDatePicker({
    required BuildContext context,
    DateTime? initialDate,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    // Allow selection from 30 days ago up to today
    final DateTime firstDate = today.subtract(const Duration(days: 30));
    final DateTime lastDate = today;

    // Default to today if not specified
    final DateTime defaultInitialDate = initialDate ?? today;

    return await showDatePicker(
      context: context,
      initialDate: defaultInitialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Which day did you complete this habit?',
      confirmText: 'Select',
      cancelText: 'Cancel',
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary:
                  brightness == Brightness.dark ? Colors.black : Colors.white,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
