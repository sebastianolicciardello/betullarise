import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final tomorrow = today.add(const Duration(days: 1));
    final plus3Days = today.add(const Duration(days: 3));
    final plus7Days = today.add(const Duration(days: 7));

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
        const SizedBox(height: 16),
        _QuickDateOption(
          label: 'Today',
          date: today,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(today),
        ),
        const SizedBox(height: 8),
        _QuickDateOption(
          label: 'Tomorrow',
          date: tomorrow,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(tomorrow),
        ),
        const SizedBox(height: 8),
        _QuickDateOption(
          label: 'In 3 days',
          date: plus3Days,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(plus3Days),
        ),
        const SizedBox(height: 8),
        _QuickDateOption(
          label: 'In 7 days',
          date: plus7Days,
          selectedDate: selectedDate,
          onTap: () => onDateSelected(plus7Days),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        _CalendarOption(
          selectedDate: selectedDate,
          onTap: () => _showCalendar(context),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _showCalendar(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = selectedDate ?? now.add(const Duration(days: 1));
    final firstDate = minDate ?? now;
    final lastDate = maxDate ?? DateTime(2100);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(firstDate) ? firstDate : initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
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

  const _QuickDateOption({
    required this.label,
    required this.date,
    this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedDate != null &&
        date.year == selectedDate!.year &&
        date.month == selectedDate!.month &&
        date.day == selectedDate!.day;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 20,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            Text(
              DateFormat('dd/MM/yyyy').format(date),
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range,
              size: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
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
              size: 16,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}