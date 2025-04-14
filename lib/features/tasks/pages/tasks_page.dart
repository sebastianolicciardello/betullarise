import 'package:betullarise/database/points_database_helper.dart';
import 'package:betullarise/features/tasks/handlers/expired_tasks_handler.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:betullarise/features/tasks/pages/task_detail_page.dart';
import 'package:provider/provider.dart';

import '../../../model/point.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final TasksDatabaseHelper _dbHelper = TasksDatabaseHelper.instance;
  List<Task> _incompleteTasks = [];
  List<Task> _completedTasks = [];
  bool _isLoading = true;
  bool _showCompletedTasks = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    final tasks = await _dbHelper.queryAllTasks();
    // Separate incomplete and completed tasks
    final incomplete = <Task>[];
    final completed = <Task>[];

    for (final task in tasks) {
      if (task.completionTime != 0) {
        completed.add(task);
      } else {
        incomplete.add(task);
      }
    }

    // Sort incomplete tasks by deadline, then by title
    incomplete.sort((a, b) {
      final deadlineComparison = a.deadline.compareTo(b.deadline);
      if (deadlineComparison != 0) {
        return deadlineComparison;
      }
      return a.title.compareTo(b.title);
    });

    // Sort completed tasks by completion time (most recent first)
    completed.sort((a, b) => b.completionTime.compareTo(a.completionTime));

    setState(() {
      _incompleteTasks = incomplete;
      _completedTasks = completed;
      _isLoading = false;
    });

    // After loading tasks, check if there are any expired ones
    if (mounted) {
      ExpiredTasksHandler.handleExpiredTasks(context);
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _incompleteTasks.isEmpty && _completedTasks.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.task_alt_rounded,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tasks created',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadTasks,
                child: ListView(
                  children: [
                    // Incomplete tasks
                    if (_incompleteTasks.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Text(
                          'TODO',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ..._incompleteTasks.map((task) => _buildTaskCard(task)),
                    ],

                    // Completed tasks (collapsible section)
                    if (_completedTasks.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          top: 24,
                          right: 16,
                          bottom: 8,
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _showCompletedTasks = !_showCompletedTasks;
                            });
                          },
                          child: Row(
                            children: [
                              const Text(
                                'COMPLETED',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(${_completedTasks.length})',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showCompletedTasks
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showCompletedTasks)
                        ..._completedTasks.map((task) => _buildTaskCard(task)),
                    ],

                    // Add bottom space for better UX
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskDetailPage()),
          );
          if (result == true) {
            _loadTasks();
          }
        },
        backgroundColor:
            Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
        foregroundColor:
            Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    final isCompleted = task.completionTime != 0;
    final isOverdue =
        task.deadline <
        DateTime.now()
            .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
            .millisecondsSinceEpoch;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              isCompleted
                  ? Colors.green
                  : isOverdue
                  ? Colors.red
                  : Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TaskDetailPage(task: task)),
          );
          if (result == true) {
            _loadTasks();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCompleted) ...[
                        Text(
                          'Completed: ${_formatDate(task.completionTime)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        'Deadline: ${_formatDate(task.deadline)}',
                        style: TextStyle(
                          color:
                              isOverdue
                                  ? Colors.red
                                  : (Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.black
                                      : Colors.white),
                          fontWeight:
                              isOverdue ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Score: +${task.score.toStringAsFixed(1)}'),
                      const SizedBox(height: 4),
                      Text('Penalty: -${task.penalty.toStringAsFixed(1)}'),
                    ],
                  ),
                  if (!isCompleted)
                    IconButton(
                      icon: const Icon(Icons.circle_outlined),
                      onPressed: () async {
                        // First update the task to mark it as completed
                        await _dbHelper.updateTask(
                          task.copyWith(
                            completionTime:
                                DateTime.now().millisecondsSinceEpoch,
                            updatedTime: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );

                        // Then insert a new point with the task's score
                        final pointsDb = PointsDatabaseHelper.instance;
                        await pointsDb.insertPoint(
                          Point(
                            referenceId: task.id!,
                            type: 'task',
                            points:
                                task.score, // Using the task's score as points value
                            insertTime: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );

                        // Aggiorna il provider per riflettere i nuovi punti
                        if (mounted) {
                          Provider.of<PointsProvider>(
                            context,
                            listen: false,
                          ).savePoints(
                            Point(
                              referenceId: task.id!,
                              type: 'task',
                              points: task.score,
                              insertTime: DateTime.now().millisecondsSinceEpoch,
                            ),
                          );
                        }

                        // Reload tasks to update UI
                        _loadTasks();

                        // Show a confirmation snackbar or some visual feedback
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Task completed! +${task.score} points',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
