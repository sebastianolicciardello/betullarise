import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';

class TaskDetailPage extends StatefulWidget {
  final Task? task;

  const TaskDetailPage({super.key, this.task});

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _scoreController = TextEditingController();

  DateTime _deadline = DateTime.now().add(const Duration(days: 1));

  final TasksDatabaseHelper _dbHelper = TasksDatabaseHelper.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _penaltyController.text = widget.task!.penalty.toString();
      _scoreController.text = widget.task!.score.toString();
      _deadline = DateTime.fromMillisecondsSinceEpoch(widget.task!.deadline);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _penaltyController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final now = DateTime.now();
    final initialDate = _deadline.isBefore(now) ? now : _deadline;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: DateTime(2100),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              onPrimary:
                  brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white, // per il tema
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      final pickedTime = const TimeOfDay(
        hour: 0,
        minute: 0,
      ); // per rimuovere la parte oraria
      if (true) {
        setState(() {
          _deadline = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now().millisecondsSinceEpoch;

    final task = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: _descriptionController.text,
      deadline: _deadline.millisecondsSinceEpoch,
      completionTime: widget.task?.completionTime ?? 0,
      score: double.parse(_scoreController.text),
      penalty: double.parse(_penaltyController.text),
      createdTime: widget.task?.createdTime ?? now,
      updatedTime: now,
    );

    try {
      if (widget.task == null) {
        await _dbHelper.insertTask(task);
      } else {
        await _dbHelper.updateTask(task);
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Errore: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteTask() async {
    // Mostra dialog di conferma
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Task'),
            content: Text(
              'Are you sure you want to delete "${_titleController.text}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (shouldDelete != true || widget.task?.id == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _dbHelper.deleteTask(widget.task!.id!);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Torna indietro comunicando l'avvenuta eliminazione
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting task: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.task != null;
    final isCompleted = isEditing ? widget.task!.completionTime != 0 : false;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        actions:
            isEditing
                ? [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _deleteTask,
                    tooltip: 'Delete Task',
                  ),
                ]
                : null,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Write a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Write a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _scoreController,
                        decoration: const InputDecoration(
                          labelText: 'Score',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insert a score';
                          }
                          try {
                            final penalty = double.parse(value);
                            if (penalty < 0) {
                              return 'Insert a valid score';
                            }
                          } catch (e) {
                            return 'Insert a valid score';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _penaltyController,
                        decoration: const InputDecoration(
                          labelText: 'Penalty',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Insert a penalty';
                          }
                          try {
                            final penalty = double.parse(value);
                            if (penalty < 0) {
                              return 'Insert a valid penalty';
                            }
                          } catch (e) {
                            return 'Insert a valid penalty';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Deadline',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        leading: const Icon(Icons.calendar_today),
                        title: Text(DateFormat('dd/MM/yyyy').format(_deadline)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: Theme.of(context).focusColor,
                            width: 2,
                          ),
                        ),
                        onTap: () => _selectDeadline(context),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveTask,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: Theme.of(context).focusColor,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            isCompleted
                                ? 'Reschedule Task'
                                : (isEditing ? 'Update Task' : 'Save Task'),
                            style: const TextStyle(fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
