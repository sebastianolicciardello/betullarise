import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../provider/first_day_of_week_provider.dart';

class QuickDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateSelected;
  final DateTime? minDate;
  final DateTime? maxDate;

  const QuickDatePicker({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.minDate,
    this.maxDate,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Past dates (debug only)
    final lastMonday = _getLastMonday(today);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastMonth = today.subtract(const Duration(days: 30));

    // Future dates
    final tomorrow = today.add(const Duration(days: 1));
    final plus3Days = today.add(const Duration(days: 3));
    final plus7Days = today.add(const Duration(days: 7));

    final List<Widget> options = [];

    // Add debug options first (in chronological order)
    if (kDebugMode) {
      options.addAll([
        _QuickDateOption(
          label: 'Last Month',
          date: lastMonth,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(lastMonth),
          isDebug: true,
        ),
        SizedBox(height: 8.h),
        _QuickDateOption(
          label: 'Last Monday',
          date: lastMonday,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(lastMonday),
          isDebug: true,
        ),
        SizedBox(height: 8.h),
        _QuickDateOption(
          label: 'Yesterday',
          date: yesterday,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(yesterday),
          isDebug: true,
        ),
        SizedBox(height: 8.h),
      ]);
    }

    // Add regular options in chronological order
    options.addAll([
      _QuickDateOption(
        label: 'Today',
        date: today,
        selectedDate: selectedDate,
        onTap: () => onDateSelected(today),
      ),
      SizedBox(height: 8.h),
      _QuickDateOption(
        label: 'Tomorrow',
        date: tomorrow,
        selectedDate: selectedDate,
        onTap: () => onDateSelected(tomorrow),
      ),
      SizedBox(height: 8.h),
      _QuickDateOption(
        label: 'In 3 days',
        date: plus3Days,
        selectedDate: selectedDate,
        onTap: () => onDateSelected(plus3Days),
      ),
      SizedBox(height: 8.h),
      _QuickDateOption(
        label: 'In 7 days',
        date: plus7Days,
        selectedDate: selectedDate,
        onTap: () => onDateSelected(plus7Days),
      ),
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Select Deadline',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 16.h),
        if (kDebugMode) ...[
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Text(
              'DEBUG: Past dates available for testing',
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 12.h),
        ],
        ...options,
        SizedBox(height: 16.h),
        const Divider(),
        SizedBox(height: 8.h),
        _CalendarOption(
          selectedDate: selectedDate,
          onTap: () => _showCalendar(context),
        ),
        SizedBox(height: 24.h),
      ],
    );
  }

  DateTime _getLastMonday(DateTime today) {
    // Find last Monday (at least 1 week ago)
    DateTime lastMonday = today.subtract(const Duration(days: 7));

    // Navigate to the Monday of that week
    while (lastMonday.weekday != DateTime.monday) {
      lastMonday = lastMonday.subtract(const Duration(days: 1));
    }

    return lastMonday;
  }

  Future<void> _showCalendar(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = selectedDate ?? now.add(const Duration(days: 1));
    final firstDate = minDate ?? now;
    final lastDate = maxDate ?? DateTime(2100);
    final firstDayProvider = Provider.of<FirstDayOfWeekProvider>(context, listen: false);

    // Create a custom locale based on first day of week setting
    Locale customLocale = const Locale('en', 'US'); // Default to US (Sunday first)
    if (firstDayProvider.firstDayOfWeek == WeekStartDay.monday) {
      customLocale = const Locale('en', 'GB'); // GB uses Monday first
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: customLocale,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final dateWithoutTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      );
      onDateSelected(dateWithoutTime);
    }
  }
}

class _QuickDateOption extends StatelessWidget {
  final String label;
  final DateTime date;
  final DateTime? selectedDate;
  final VoidCallback onTap;
  final bool isDebug;

  const _QuickDateOption({
    required this.label,
    required this.date,
    this.selectedDate,
    required this.onTap,
    this.isDebug = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedDate != null &&
        date.year == selectedDate!.year &&
        date.month == selectedDate!.month &&
        date.day == selectedDate!.day;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8.r),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isDebug ? Icons.bug_report : Icons.calendar_today,
              size: 20.sp,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : isDebug
                      ? Colors.orange.shade700
                      : Theme.of(context).colorScheme.onSurface,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : isDebug
                              ? Colors.orange.shade700
                              : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (isDebug) ...[
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3.r),
                      ),
                      child: Text(
                        'DEBUG',
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : isDebug
                        ? Colors.orange.shade600
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarOption extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const _CalendarOption({
    this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              size: 20.sp,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'Choose custom date',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}