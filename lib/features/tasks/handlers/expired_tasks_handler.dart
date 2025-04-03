// Create a new file: lib/features/tasks/expired_tasks_handler.dart

import 'package:betullarise/features/tasks/pages/expired_tasks_resolution_page.dart';
import 'package:flutter/material.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';

class ExpiredTasksHandler {
  static final TasksDatabaseHelper _dbHelper = TasksDatabaseHelper.instance;

  // Check if there are any expired tasks
  static Future<List<Task>> checkExpiredTasks() async {
    final tasks = await _dbHelper.queryAllTasks();
    final now =
        DateTime.now()
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
            .millisecondsSinceEpoch;

    final expiredTasks =
        tasks
            .where((task) => task.deadline < now && task.completionTime == 0)
            .toList();

    return expiredTasks;
  }

  // Show the expired tasks resolution page if needed
  static Future<void> handleExpiredTasks(BuildContext context) async {
    final expiredTasks = await checkExpiredTasks();

    // Check if the widget is still mounted before using the context
    if (expiredTasks.isNotEmpty && context.mounted) {
      // Navigate to the resolution page and prevent going back
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => ExpiredTasksResolutionPage(tasks: expiredTasks),
        ),
        (route) => false, // This prevents going back
      );
    }
  }
}
