import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/model/point.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:betullarise/database/points_database_helper.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';
import 'package:betullarise/services/completion_date_picker_service.dart';
import 'package:betullarise/widgets/overdue_task_dialog.dart';
import 'package:betullarise/features/tasks/pages/task_detail_page.dart';

class TaskCompletionService {
  static final TasksDatabaseHelper _dbHelper = TasksDatabaseHelper.instance;

  static Future<void> handleTaskCompletion({
    required BuildContext context,
    required Task task,
    required VoidCallback onTaskUpdated,
  }) async {
    final bool isOverdue = task.deadline <
        DateTime.now()
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
            .millisecondsSinceEpoch;

    if (isOverdue) {
      await _showOverdueTaskDialog(context, task, onTaskUpdated);
    } else {
      await _completeTask(context, task, task.score, onTaskUpdated);
    }
  }

  static Future<void> _showOverdueTaskDialog(
    BuildContext context,
    Task task,
    VoidCallback onTaskUpdated,
  ) async {
    final int overdueDays = _calculateOverdueDays(task);
    final double effectivePoints = task.score - (task.penalty * overdueDays);

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return OverdueTaskDialog(
          task: task,
          overdueDays: overdueDays,
          effectivePoints: effectivePoints,
          onExtendDeadline: () async {
            Navigator.of(context).pop();
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TaskDetailPage(task: task)),
            );
            if (result == true) {
              onTaskUpdated();
            }
          },
          onAcceptPenalty: () async {
            Navigator.of(context).pop();
            await _completeTask(context, task, effectivePoints, onTaskUpdated);
          },
          onSetActualDate: () async {
            // Non chiudere il dialog qui - lo facciamo dopo la selezione
            await _handleDatePickerKeepingDialog(context, task, onTaskUpdated);
          },
          onFullPoints: () async {
            Navigator.of(context).pop();
            await _completeTask(context, task, task.score, onTaskUpdated);
          },
        );
      },
    );
  }

  static Future<void> _handleDatePickerKeepingDialog(
    BuildContext context,
    Task task,
    VoidCallback onTaskUpdated,
  ) async {
    // Cattura il PointsProvider e il Navigator prima che il context si smonti
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);
    final navigator = Navigator.of(context);

    final DateTime? pickedDate = await CompletionDatePickerService.showCompletionDatePicker(
      context: context,
      task: task,
    );

    if (pickedDate != null) {
      // Chiudi il dialog overdue ora
      Navigator.of(context).pop();

      final DateTime deadline = DateTime.fromMillisecondsSinceEpoch(task.deadline);
      final DateTime completionDate = pickedDate.copyWith(hour: 23, minute: 59);

      final Map<String, dynamic> calculation = CompletionDatePickerService.calculatePointsForDate(
        task: task,
        completionDate: completionDate,
      );

      if (context.mounted) {

        final bool? confirm = await CompletionDatePickerService.showCompletionConfirmation(
          context: context,
          completionDate: completionDate,
          deadline: deadline,
          pointsToAssign: calculation['pointsToAssign'],
          isOnTime: calculation['isOnTime'],
        );

        debugPrint('TaskCompletion - Confirmation result: $confirm');

        if (confirm == true) {
          debugPrint('TaskCompletion - User confirmed, context mounted: ${context.mounted}');
          // Non controllare context.mounted - procedi direttamente con il completion
          debugPrint('TaskCompletion - Completing task with date');
          await _completeTaskWithDateAndProvider(
            context,
            task,
            calculation['pointsToAssign'],
            completionDate.millisecondsSinceEpoch,
            onTaskUpdated,
            pointsProvider,
            navigator,
          );
          debugPrint('TaskCompletion - Task completion finished');
        } else {
          debugPrint('TaskCompletion - User cancelled confirmation');
        }
      }
    } else {
      // Se l'utente cancella il date picker, non chiudere il dialog overdue
      debugPrint('TaskCompletion - Date picker cancelled, keeping overdue dialog');
    }
  }


  static Future<void> _completeTask(
    BuildContext context,
    Task task,
    double pointsToAssign,
    VoidCallback onTaskUpdated,
  ) async {
    await _completeTaskWithDate(
      context,
      task,
      pointsToAssign,
      DateTime.now().millisecondsSinceEpoch,
      onTaskUpdated,
    );
  }

  static Future<void> _completeTaskWithDateAndProvider(
    BuildContext context,
    Task task,
    double pointsToAssign,
    int completionTime,
    VoidCallback onTaskUpdated,
    PointsProvider pointsProvider,
    NavigatorState navigator,
  ) async {
    await _dbHelper.updateTask(
      task.copyWith(
        completionTime: completionTime,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final point = Point(
      referenceId: task.id!,
      type: 'task',
      points: pointsToAssign,
      insertTime: currentTime,
    );

    // Usa il provider catturato invece di cercare di ottenerlo dal context
    pointsProvider.savePoints(point);

    onTaskUpdated();

    // Usa il navigator context catturato per mostrare lo snackbar
    final scaffoldContext = navigator.context;
    SnackbarService.showSnackbar(
      scaffoldContext,
      pointsToAssign >= 0
          ? 'Task completed! +${pointsToAssign.toStringAsFixed(1)} points'
          : 'Task completed! ${pointsToAssign.toStringAsFixed(1)} points',
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: Colors.red,
        onPressed: () async {
          await _undoTaskCompletionWithProvider(scaffoldContext, task, point, onTaskUpdated, pointsProvider);
        },
      ),
    );
  }

  static Future<void> _completeTaskWithDate(
    BuildContext context,
    Task task,
    double pointsToAssign,
    int completionTime,
    VoidCallback onTaskUpdated,
  ) async {
    debugPrint('TaskCompletion - _completeTaskWithDate called for task ${task.id} with $pointsToAssign points');
    await _dbHelper.updateTask(
      task.copyWith(
        completionTime: completionTime,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final point = Point(
      referenceId: task.id!,
      type: 'task',
      points: pointsToAssign,
      insertTime: currentTime,
    );

    if (context.mounted) {
      Provider.of<PointsProvider>(context, listen: false).savePoints(point);
    }

    onTaskUpdated();

    if (context.mounted) {
      // Capture the PointsProvider reference before showing snackbar
      final pointsProvider = Provider.of<PointsProvider>(context, listen: false);

      SnackbarService.showSnackbar(
        context,
        pointsToAssign >= 0
            ? 'Task completed! +${pointsToAssign.toStringAsFixed(1)} points'
            : 'Task completed! ${pointsToAssign.toStringAsFixed(1)} points',
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.red,
          onPressed: () async {
            debugPrint('UNDO button pressed!');
            await _undoTaskCompletionWithProvider(context, task, point, onTaskUpdated, pointsProvider);
          },
        ),
      );
    }
  }

  static Future<void> _undoTaskCompletionWithProvider(
    BuildContext context,
    Task task,
    Point point,
    VoidCallback onTaskUpdated,
    PointsProvider pointsProvider,
  ) async {
    debugPrint('UNDO: _undoTaskCompletionWithProvider called for task ${task.id} with ${point.points} points');

    debugPrint('UNDO: Updating task completion status...');
    await _dbHelper.updateTask(
      task.copyWith(
        completionTime: 0,
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    debugPrint('UNDO: Task updated. Context mounted: ${context.mounted}');

    // Remove points directly from database and refresh provider
    debugPrint('UNDO: Starting point removal with provider...');
    try {
      final pointsDb = PointsDatabaseHelper.instance;

      // Get all points for this task with matching points value
      final allPoints = await pointsDb.getAllPoints();
      final taskPoints = allPoints.where((p) =>
        p.referenceId == task.id &&
        p.type == 'task' &&
        (p.points - point.points).abs() < 0.01 // Handle floating point precision
      ).toList();

      if (taskPoints.isNotEmpty) {
        // Sort by insertion time, most recent first
        taskPoints.sort((a, b) => b.insertTime.compareTo(a.insertTime));
        final mostRecentPoint = taskPoints.first;

        debugPrint('UNDO: Removing point with insertTime: ${mostRecentPoint.insertTime}, points: ${mostRecentPoint.points}');

        // Remove the most recent point directly from database
        await pointsDb.deletePointUndo(
          mostRecentPoint.referenceId!,
          mostRecentPoint.type,
          mostRecentPoint.insertTime,
        );

        debugPrint('UNDO: Point removed from database');

        // Refresh the captured provider
        await pointsProvider.loadAllPoints();
        debugPrint('UNDO: Points provider refreshed successfully');
      } else {
        debugPrint('UNDO: No matching points found for task ${task.id} with ${point.points} points');
      }
    } catch (e) {
      debugPrint('UNDO failed: $e');
    }

    onTaskUpdated();

    if (context.mounted) {
      SnackbarService.showSnackbar(
        context,
        point.points >= 0
            ? 'Task completion undone. -${point.points.toStringAsFixed(1)} points'
            : 'Task completion undone. +${(-point.points).toStringAsFixed(1)} points',
        duration: const Duration(seconds: 2),
      );
    }
  }


  static int _calculateOverdueDays(Task task) {
    final now = DateTime.now();
    final deadline = DateTime.fromMillisecondsSinceEpoch(task.deadline);
    int overdueDays = now.difference(deadline).inDays;
    if (now.isAfter(deadline)) {
      overdueDays += 1;
    }
    return overdueDays > 0 ? overdueDays : 0;
  }
}