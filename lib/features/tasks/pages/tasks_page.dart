import 'dart:ui' as ui;

import 'package:betullarise/database/points_database_helper.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:betullarise/features/tasks/pages/task_detail_page.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';

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
                  padding: EdgeInsets.only(top: 16.h, bottom: 80.h),
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search tasks...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),

                    if (_filteredIncompleteTasks.isEmpty &&
                        _filteredCompletedTasks.isEmpty &&
                        _searchController.text.isNotEmpty) ...[
                      SizedBox(height: 64.h),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No tasks found for "${_searchController.text}"',
                              style: TextStyle(fontSize: 18.sp),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_incompleteTasks.isEmpty &&
                        _completedTasks.isEmpty) ...[
                      SizedBox(height: 64.h),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No tasks created',
                              style: TextStyle(fontSize: 18.sp),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ..._filteredIncompleteTasks.map(_buildTaskCard),

                      if (_filteredCompletedTasks.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _showCompletedTasks = !_showCompletedTasks;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  'COMPLETED',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Text(
                                  '(${_filteredCompletedTasks.length})',
                                  style: TextStyle(
                                    fontSize: 16.sp,
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
        child: Icon(Icons.add, size: 24.sp),
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
      if (now.isAfter(deadline)) {
        overdueDays += 1;
      }
      if (overdueDays > 0) {
        effectivePoints = task.score - (task.penalty * overdueDays);
      }
    }

    final bool hasDescription = task.description.trim().isNotEmpty;
    const int maxDescriptionLines = 2;
    const double minCardHeight = 56; // more compact without description
    const double normalCardHeight = 120; // normal with description

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
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
        child: Container(
          constraints: BoxConstraints(
            minHeight: hasDescription ? normalCardHeight : minCardHeight,
          ),
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (hasDescription) ...[
                SizedBox(height: 8.h),
                Builder(
                  builder: (context) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final span = TextSpan(
                          text: task.description,
                          style: TextStyle(fontSize: 14.sp),
                        );
                        final tp = TextPainter(
                          text: span,
                          maxLines: maxDescriptionLines,
                          textDirection: ui.TextDirection.ltr,
                        )..layout(maxWidth: constraints.maxWidth);
                        final isOverflowing = tp.didExceedMaxLines;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              task.description,
                              maxLines: maxDescriptionLines,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.sp),
                            ),
                            if (isOverflowing)
                              Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 18.sp,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: 12.h),
              ] else ...[
                SizedBox(
                  height: 8.h,
                ), // space between title and details if there is no description
              ],
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
                        SizedBox(height: 4.h),
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
                      SizedBox(height: 4.h),
                      Text('Score: +${task.score.toStringAsFixed(2)}'),
                      SizedBox(height: 4.h),
                      Text('Penalty: -${task.penalty.toStringAsFixed(2)}'),
                      if (!isCompleted && isOverdue) ...[
                        SizedBox(height: 4.h),
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
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (!isCompleted)
                    IconButton(
                      icon: Icon(Icons.circle_outlined, size: 24.sp),
                      onPressed: () async {
                        double pointsToAssign =
                            isOverdue ? effectivePoints : task.score;
                        await _dbHelper.updateTask(
                          task.copyWith(
                            completionTime:
                                DateTime.now().millisecondsSinceEpoch,
                            updatedTime: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );
                        final pointsDb = PointsDatabaseHelper.instance;
                        await pointsDb.insertPoint(
                          Point(
                            referenceId: task.id!,
                            type: 'task',
                            points: pointsToAssign,
                            insertTime: DateTime.now().millisecondsSinceEpoch,
                          ),
                        );
                        final point = Point(
                          referenceId: task.id!,
                          type: 'task',
                          points: pointsToAssign,
                          insertTime: DateTime.now().millisecondsSinceEpoch,
                        );
                        if (mounted) {
                          Provider.of<PointsProvider>(
                            context,
                            listen: false,
                          ).savePoints(point);
                        }
                        _loadTasks();
                        if (mounted) {
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
                                await _dbHelper.updateTask(
                                  task.copyWith(
                                    completionTime: 0,
                                    updatedTime:
                                        DateTime.now().millisecondsSinceEpoch,
                                  ),
                                );
                                if (mounted) {
                                  Provider.of<PointsProvider>(
                                    context,
                                    listen: false,
                                  ).removePointsByEntity(point);
                                }
                                _loadTasks();
                                if (mounted) {
                                  SnackbarService.showSnackbar(
                                    context,
                                    pointsToAssign >= 0
                                        ? 'Task completion undone. -${pointsToAssign.toStringAsFixed(1)} points'
                                        : 'Task completion undone. +${(-pointsToAssign).toStringAsFixed(1)} points',
                                    duration: const Duration(seconds: 2),
                                  );
                                }
                              },
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
