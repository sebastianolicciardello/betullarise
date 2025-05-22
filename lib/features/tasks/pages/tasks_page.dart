import 'package:betullarise/database/points_database_helper.dart';
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
  List<Task> _filteredIncompleteTasks = [];
  List<Task> _filteredCompletedTasks = [];
  bool _isLoading = true;
  bool _showCompletedTasks = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterTasks(_searchController.text);
  }

  void _filterTasks(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredIncompleteTasks = List.from(_incompleteTasks);
        _filteredCompletedTasks = List.from(_completedTasks);
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    setState(() {
      _filteredIncompleteTasks =
          _incompleteTasks.where((task) {
            return task.title.toLowerCase().contains(lowerCaseQuery) ||
                task.description.toLowerCase().contains(lowerCaseQuery);
          }).toList();

      _filteredCompletedTasks =
          _completedTasks.where((task) {
            return task.title.toLowerCase().contains(lowerCaseQuery) ||
                task.description.toLowerCase().contains(lowerCaseQuery);
          }).toList();
    });
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
      return deadlineComparison != 0
          ? deadlineComparison
          : a.title.compareTo(b.title);
    });

    // Sort completed tasks by completion time (most recent first)
    completed.sort((a, b) => b.completionTime.compareTo(a.completionTime));

    setState(() {
      _incompleteTasks = incomplete;
      _completedTasks = completed;
      _filteredIncompleteTasks = List.from(incomplete);
      _filteredCompletedTasks = List.from(completed);
      _isLoading = false;
    });
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
              : RefreshIndicator(
                onRefresh: _loadTasks,
                child: ListView(
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search tasks...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    if (_filteredIncompleteTasks.isEmpty &&
                        _filteredCompletedTasks.isEmpty &&
                        _searchController.text.isNotEmpty) ...[
                      const SizedBox(height: 64),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No tasks found for "${_searchController.text}"',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_incompleteTasks.isEmpty &&
                        _completedTasks.isEmpty) ...[
                      const SizedBox(height: 64),
                      Center(
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
                      ),
                    ] else ...[
                      ..._filteredIncompleteTasks.map(_buildTaskCard),

                      if (_filteredCompletedTasks.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
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
                                  '(${_filteredCompletedTasks.length})',
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
                          ..._filteredCompletedTasks.map(_buildTaskCard),
                      ],
                    ],
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

    // Calculate overdue days and effective points (can be negative)
    int overdueDays = 0;
    double effectivePoints = task.score;
    if (!isCompleted && isOverdue) {
      final now = DateTime.now();
      final deadline = DateTime.fromMillisecondsSinceEpoch(task.deadline);
      overdueDays = now.difference(deadline).inDays;
      if (overdueDays > 0) {
        effectivePoints = task.score - (task.penalty * overdueDays);
      }
    }

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
                      Text('Score: +${task.score.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      Text('Penalty: -${task.penalty.toStringAsFixed(2)}'),
                      if (!isCompleted && isOverdue) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Effective Points: ${effectivePoints.toStringAsFixed(2)}',
                          style: TextStyle(
                            color:
                                effectivePoints >= 0
                                    ? Colors.orange
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Penalty for overdue: -${(task.penalty * overdueDays).toStringAsFixed(2)} ($overdueDays days late)',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isCompleted)
                    IconButton(
                      icon: const Icon(Icons.circle_outlined),
                      onPressed: () async {
                        // If the task is overdue, assign (subtract) the effectivePoints
                        double pointsToAssign =
                            isOverdue ? effectivePoints : task.score;
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
                            points: pointsToAssign, // can be negative
                            insertTime: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );

                        // Create point object for the provider
                        final point = Point(
                          referenceId: task.id!,
                          type: 'task',
                          points: pointsToAssign,
                          insertTime: DateTime.now().millisecondsSinceEpoch,
                        );

                        // Aggiorna il provider per riflettere i nuovi punti
                        if (mounted) {
                          Provider.of<PointsProvider>(
                            context,
                            listen: false,
                          ).savePoints(point);
                        }

                        // Reload tasks to update UI
                        _loadTasks();

                        // Show a confirmation snackbar with undo button
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                pointsToAssign >= 0
                                    ? 'Task completed! +${pointsToAssign.toStringAsFixed(1)} points'
                                    : 'Task completed! ${pointsToAssign.toStringAsFixed(1)} points',
                              ),
                              duration: const Duration(
                                seconds: 4,
                              ), // Extended duration for undo action
                              action: SnackBarAction(
                                label: 'UNDO',
                                textColor: Colors.red,
                                onPressed: () async {
                                  // Revert the task back to incomplete
                                  await _dbHelper.updateTask(
                                    task.copyWith(
                                      completionTime:
                                          0, // Reset completion time to 0 (incomplete)
                                      updatedTime:
                                          DateTime.now().millisecondsSinceEpoch,
                                    ),
                                  );

                                  // Update the provider to reflect the removed points
                                  if (mounted) {
                                    Provider.of<PointsProvider>(
                                      context,
                                      listen: false,
                                    ).removePointsByEntity(point);
                                  }

                                  // Reload tasks to update UI
                                  _loadTasks();

                                  // Show feedback that the action was undone
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          pointsToAssign >= 0
                                              ? 'Task completion undone. -${pointsToAssign.toStringAsFixed(1)} points'
                                              : 'Task completion undone. +${(-pointsToAssign).toStringAsFixed(1)} points',
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
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
