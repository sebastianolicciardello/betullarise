import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:betullarise/model/task.dart';

class CompletionDatePickerService {
  static Future<DateTime?> showCompletionDatePicker({
    required BuildContext context,
    required Task task,
  }) async {
    final DateTime deadline = DateTime.fromMillisecondsSinceEpoch(task.deadline);
    final DateTime createdDate = DateTime.fromMillisecondsSinceEpoch(task.createdTime);
    final DateTime now = DateTime.now();

    // For overdue tasks, allow selecting from much earlier dates
    // The earliest should be the earlier of deadline or created date, but also allow up to 30 days before
    final DateTime earliestAllowedDate = deadline.isBefore(createdDate)
        ? deadline.subtract(const Duration(days: 30))
        : createdDate.subtract(const Duration(days: 30));

    // For overdue tasks, start from the deadline date
    DateTime initialDate = deadline;

    // Ensure initialDate is not before firstDate
    if (initialDate.isBefore(earliestAllowedDate)) {
      initialDate = earliestAllowedDate;
    }

    // Ensure initialDate is not after lastDate (now)
    if (initialDate.isAfter(now)) {
      initialDate = now;
    }

    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: earliestAllowedDate, // Allow much earlier selection for testing overdue scenarios
      lastDate: now, // Always allow selection up to today
      helpText: 'When did you actually complete this task?',
      confirmText: 'Select',
      cancelText: 'Cancel',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
  }

  static Future<bool?> showCompletionConfirmation({
    required BuildContext context,
    required DateTime completionDate,
    required DateTime deadline,
    required double pointsToAssign,
    required bool isOnTime,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Completion Date'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Completion date: ${DateFormat('dd/MM/yyyy').format(completionDate)}'),
            Text('Deadline was: ${DateFormat('dd/MM/yyyy').format(deadline)}'),
            SizedBox(height: 8.h),
            if (isOnTime) ...[
              const Text('Great! This task was completed on time.'),
              SizedBox(height: 8.h),
              Text(
                'Points to receive: ${pointsToAssign.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ] else ...[
              Text('This was ${completionDate.difference(deadline).inDays + 1} day${completionDate.difference(deadline).inDays > 0 ? 's' : ''} after the deadline.'),
              SizedBox(height: 8.h),
              Text(
                'Points to receive: ${pointsToAssign.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pointsToAssign >= 0 ? Colors.orange : Colors.red,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  static Map<String, dynamic> calculatePointsForDate({
    required Task task,
    required DateTime completionDate,
  }) {
    final DateTime deadline = DateTime.fromMillisecondsSinceEpoch(task.deadline);
    final bool isOnTime = !completionDate.isAfter(deadline);

    double pointsToAssign = task.score;

    if (!isOnTime) {
      final int overdueDays = completionDate.difference(deadline).inDays + 1;
      pointsToAssign = task.score - (task.penalty * overdueDays);
    }

    return {
      'pointsToAssign': pointsToAssign,
      'isOnTime': isOnTime,
      'overdueDays': isOnTime ? 0 : completionDate.difference(deadline).inDays + 1,
    };
  }
}