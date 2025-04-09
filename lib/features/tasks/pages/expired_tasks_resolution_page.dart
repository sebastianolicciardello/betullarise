import 'package:flutter/material.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';

class ExpiredTasksResolutionPage extends StatefulWidget {
  final List<Task> tasks;

  const ExpiredTasksResolutionPage({super.key, required this.tasks});

  @override
  State<ExpiredTasksResolutionPage> createState() =>
      _ExpiredTasksResolutionPageState();
}

class _ExpiredTasksResolutionPageState
    extends State<ExpiredTasksResolutionPage> {
  final TasksDatabaseHelper _dbHelper = TasksDatabaseHelper.instance;
  List<Task> _remainingTasks = [];
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _remainingTasks = List.from(widget.tasks);
  }

  void _markAsCompleted(Task task) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Update task as completed
      await _dbHelper.updateTask(
        task.copyWith(
          completionTime: DateTime.now().millisecondsSinceEpoch,
          updatedTime: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Add points for completion
      if (mounted) {
        Provider.of<PointsProvider>(context, listen: false).savePoints(
          Point(
            referenceId: task.id!,
            type: 'task',
            points: task.score,
            insertTime: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task completed! +${task.score} points'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Remove task from list
      setState(() {
        _remainingTasks.remove(task);
        _isProcessing = false;
      });

      // Check if all tasks are handled
      _checkIfAllTasksHandled();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  void _acceptPenalty(Task task) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Add the penalty to points database as negative points
      if (mounted) {
        Provider.of<PointsProvider>(context, listen: false).savePoints(
          Point(
            referenceId: task.id!,
            type: 'task',
            points: -task.penalty, // Negative points for penalty
            insertTime: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Penalty applied: -${task.penalty} points'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Show dialog to ask whether to reschedule or delete
      await _showRescheduleOrDeleteDialog(task);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _showRescheduleOrDeleteDialog(Task task) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Task Not Completed'),
            content: Text('What would you like to do with "${task.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'delete'),
                child: const Text('Delete Task'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'reschedule'),
                child: const Text('Reschedule Task'),
              ),
            ],
          ),
    );

    if (result == 'delete') {
      await _deleteTask(task);
    } else if (result == 'reschedule') {
      await _showRescheduleDialog(task);
    }
  }

  Future<void> _deleteTask(Task task) async {
    try {
      await _dbHelper.deleteTask(task.id!);

      setState(() {
        _remainingTasks.remove(task);
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task deleted'),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Check if all tasks are handled
      _checkIfAllTasksHandled();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting task: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showRescheduleDialog(Task task) async {
    // Controllers for editing
    final titleController = TextEditingController(text: task.title);
    final descriptionController = TextEditingController(text: task.description);
    final scoreController = TextEditingController(text: task.score.toString());
    final penaltyController = TextEditingController(
      text: task.penalty.toString(),
    );

    // Default new deadline (tomorrow)
    DateTime newDeadline = DateTime.now().add(const Duration(days: 1));

    // Show dialog with form
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reschedule Task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: scoreController,
                      decoration: const InputDecoration(labelText: 'Score'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: penaltyController,
                      decoration: const InputDecoration(labelText: 'Penalty'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'New Deadline:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: newDeadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );

                        if (pickedDate != null) {
                          setState(() {
                            newDeadline = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('dd/MM/yyyy').format(newDeadline)),
                            const Icon(Icons.calendar_today),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'score':
                          double.tryParse(scoreController.text) ?? task.score,
                      'penalty':
                          double.tryParse(penaltyController.text) ??
                          task.penalty,
                      'deadline': newDeadline.millisecondsSinceEpoch,
                    });
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    // Clean up controllers
    titleController.dispose();
    descriptionController.dispose();
    scoreController.dispose();
    penaltyController.dispose();

    if (result != null) {
      await _rescheduleTask(task, result);
    } else {
      // If dialog was dismissed, we still need to remove the task from the list
      setState(() {
        _remainingTasks.remove(task);
        _isProcessing = false;
      });
      _checkIfAllTasksHandled();
    }
  }

  Future<void> _rescheduleTask(Task task, Map<String, dynamic> newData) async {
    try {
      final updatedTask = task.copyWith(
        title: newData['title'],
        description: newData['description'],
        score: newData['score'],
        penalty: newData['penalty'],
        deadline: newData['deadline'],
        updatedTime: DateTime.now().millisecondsSinceEpoch,
      );

      await _dbHelper.updateTask(updatedTask);

      setState(() {
        _remainingTasks.remove(task);
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task rescheduled for ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(newData['deadline']))}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Check if all tasks are handled
      _checkIfAllTasksHandled();
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rescheduling task: ${e.toString()}')),
        );
      }
    }
  }

  void _checkIfAllTasksHandled() {
    if (_remainingTasks.isEmpty) {
      // All tasks handled, return to home page
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expired Tasks'),
        automaticallyImplyLeading: false, // Disable back button
      ),
      body:
          _isProcessing
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'You have ${_remainingTasks.length} expired tasks that need attention.',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Please indicate for each task whether you completed it or need to accept the penalty.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _remainingTasks.length,
                      itemBuilder: (context, index) {
                        final task = _remainingTasks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.red, width: 2),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  task.description,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Deadline: ${_formatDate(task.deadline)}',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Score: ${task.score.toStringAsFixed(1)}',
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Penalty: ${task.penalty.toStringAsFixed(1)}',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _acceptPenalty(task),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text(
                                          'Accept Penalty (-${task.penalty})',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _markAsCompleted(task),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.green,
                                        ),
                                        child: Text(
                                          'Mark Completed (+${task.score})',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
    );
  }
}
