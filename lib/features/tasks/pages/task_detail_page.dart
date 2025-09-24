import 'package:betullarise/provider/points_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:betullarise/model/task.dart';
import 'package:betullarise/database/tasks_database_helper.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/database/points_database_helper.dart';
import 'package:betullarise/services/ui/dialog_service.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';
import 'package:betullarise/widgets/quick_date_picker.dart';
import 'package:betullarise/widgets/info_tooltip.dart';

class TaskDetailPage extends StatefulWidget {
  final Task? task;
  final TasksDatabaseHelper? dbHelper;
  final PointsDatabaseHelper? pointsDbHelper;
  final DialogService? dialogService;

  const TaskDetailPage({
    super.key,
    this.task,
    this.dbHelper,
    this.pointsDbHelper,
    this.dialogService,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _scoreController = TextEditingController();
  // final _dialogService = DialogService();

  // Store initial values for dirty check
  String? _initialTitle;
  String? _initialDescription;
  String? _initialPenalty;
  String? _initialScore;
  DateTime? _initialDeadline;

  DateTime _deadline = DateTime.now().add(const Duration(days: 1));

  late final TasksDatabaseHelper _dbHelper;
  bool _isLoading = false;
  late final PointsDatabaseHelper _pointsDbHelper;
  late final DialogService _dialogService;
  bool _isShowingDiscardDialog = false;

  @override
  void initState() {
    super.initState();
    _dbHelper = widget.dbHelper ?? TasksDatabaseHelper.instance;
    _pointsDbHelper = widget.pointsDbHelper ?? PointsDatabaseHelper.instance;
    _dialogService = widget.dialogService ?? DialogService();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descriptionController.text = widget.task!.description;
      _penaltyController.text = widget.task!.penalty.toString();
      _scoreController.text = widget.task!.score.toString();
      _deadline = DateTime.fromMillisecondsSinceEpoch(widget.task!.deadline);
      // Save initial values for dirty check
      _initialTitle = widget.task!.title;
      _initialDescription = widget.task!.description;
      _initialPenalty = widget.task!.penalty.toString();
      _initialScore = widget.task!.score.toString();
      _initialDeadline = DateTime.fromMillisecondsSinceEpoch(
        widget.task!.deadline,
      );
    } else {
      _scoreController.text = '1.0';
      _penaltyController.text = '0.0';
      _initialTitle = '';
      _initialDescription = '';
      _initialPenalty = '0.0';
      _initialScore = '1.0';
      _initialDeadline = _deadline;
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

  bool get _isDirty {
    return _titleController.text != (_initialTitle ?? '') ||
        _descriptionController.text != (_initialDescription ?? '') ||
        _penaltyController.text != (_initialPenalty ?? '') ||
        _scoreController.text != (_initialScore ?? '') ||
        _deadline != (_initialDeadline ?? _deadline);
  }

  Future<bool> _onWillPop() async {
    if (_isShowingDiscardDialog) return false;
    if (!_isDirty) return true;
    
    _isShowingDiscardDialog = true;
    final shouldDiscard = await _dialogService.showConfirmDialog(
      context,
      'Discard changes?',
      'You have unsaved changes. Are you sure you want to discard them?',
      confirmText: 'Discard',
      cancelText: 'Cancel',
      isDangerous: true,
    );
    _isShowingDiscardDialog = false;
    
    return shouldDiscard == true;
  }

  Future<void> _selectDeadline(BuildContext context) async {
    final now = DateTime.now();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16.w,
            right: 16.w,
            top: 24.h,
          ),
          child: QuickDatePicker(
            selectedDate: _deadline,
            onDateSelected: (DateTime selectedDate) {
              setState(() {
                _deadline = selectedDate;
              });
              Navigator.of(context).pop();
            },
            minDate: kDebugMode ? DateTime(2020) : now,
            maxDate: DateTime(2100),
          ),
        );
      },
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Verifica se stiamo rischedulando un task completato
    final bool isReschedulingCompletedTask =
        widget.task != null && widget.task!.completionTime != 0;

    // Check if the selected date is valid (not before today, unless in debug mode)
    final bool isDeadlineValid = kDebugMode || _deadline.isAfter(
      DateTime.now().subtract(const Duration(days: 1)),
    );

    if (!isDeadlineValid) {
      SnackbarService.showWarningSnackbar(
        context,
        'The deadline must be at least today. Please select a valid date.',
      );
      return;
    }

    // Se stiamo rischedulando un task completato, mostra una conferma
    if (isReschedulingCompletedTask) {
      final bool? shouldReschedule = await _dialogService.showConfirmDialog(
        context,
        'Reschedule Completed Task',
        'Rescheduling this task will reset its completion status and you will lose the ${widget.task!.score} points earned.\n\n'
            'The task will be rescheduled with the deadline: ${DateFormat('dd/MM/yyyy').format(_deadline)}.\n\n'
            'Do you want to continue?',
        confirmText: 'Reschedule',
        cancelText: 'Cancel',
        isDangerous: true,
      );

      if (shouldReschedule != true) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Se stiamo rischedulando un task completato, sottraiamo i punti prima di aggiornare il task
      if (isReschedulingCompletedTask && widget.task?.id != null) {
        // 1. Ottieni i punti associati a questo task
        final pointsDbHelper = _pointsDbHelper;
        final point = await pointsDbHelper
            .queryPointByReferenceIdOnlyPositiveTasks(widget.task!.id!);

        // 2. Se ci sono punti associati a questo task, sottraili dal provider
        if (point != null && mounted) {
          final pointsProvider = Provider.of<PointsProvider>(
            context,
            listen: false,
          );

          await pointsProvider.removePointsByEntity(point); // Sottrai i punti
        }
      }

      final now = DateTime.now().millisecondsSinceEpoch;

      final task = Task(
        id: widget.task?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        deadline: _deadline.millisecondsSinceEpoch,
        // Reimposta il completionTime a 0 se stiamo rischedulando
        completionTime:
            isReschedulingCompletedTask
                ? 0
                : (widget.task?.completionTime ?? 0),
        score: double.parse(_scoreController.text),
        penalty: double.parse(_penaltyController.text),
        createdTime: widget.task?.createdTime ?? now,
        updatedTime: now,
      );

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
        SnackbarService.showErrorSnackbar(
          context,
          'Errore: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _deleteTask() async {
    // Mostra dialog di conferma
    final bool? shouldDelete = await _dialogService.showConfirmDialog(
      context,
      'Delete Task',
      'Are you sure you want to delete "${_titleController.text}"?\n\n${widget.task?.completionTime != 0 ? 'If you delete this task, you will NOT lose the ${widget.task!.score} points earned from completing it.' : ''}',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      isDangerous: true,
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
        SnackbarService.showErrorSnackbar(
          context,
          'Error deleting task: ${e.toString()}',
        );
      }
    }
  }

  Future<void> _cancelTask() async {
    // Show confirmation dialog
    final bool? shouldCancel = await _dialogService.showConfirmDialog(
      context,
      'Cancel Task',
      'Are you sure you want to cancel "${_titleController.text}"?\n\n'
          'This will remove the task and revoke the ${widget.task!.score} points earned from completing it.',
      confirmText: 'Cancel Task',
      cancelText: 'Keep Task',
      isDangerous: true,
    );

    if (shouldCancel != true || widget.task?.id == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Get the point record for this task
      final pointsDbHelper = _pointsDbHelper;
      final point = await pointsDbHelper
          .queryPointByReferenceIdOnlyPositiveTasks(widget.task!.id!);

      // 2. If there are points associated with this task, subtract them from the provider
      if (point != null && mounted) {
        // Update the points provider
        final pointsProvider = Provider.of<PointsProvider>(
          context,
          listen: false,
        );
        await pointsProvider.removePointsByEntity(point); // Subtract the points
      }

      // 4. Delete the task from the tasks table
      await _dbHelper.deleteTask(widget.task!.id!);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        // Return to previous screen indicating that a change occurred
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        SnackbarService.showErrorSnackbar(
          context,
          'Error canceling task: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.task != null;
    final isCompleted = isEditing ? widget.task!.completionTime != 0 : false;

    return PopScope(
      canPop: false, // Always prevent initial pop
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          // ignore: use_build_context_synchronously
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          systemOverlayStyle:
              Theme.of(context).brightness == Brightness.dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && mounted) {
                // ignore: use_build_context_synchronously
                Navigator.of(context).pop();
              }
            },
          ),
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
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Write a title';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 12.h),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: 4,
                        ),
                        SizedBox(height: 14.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
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
                            ),
                            SizedBox(width: 8.w),
                            InfoTooltip(
                              message: 'Score and Penalty can be decimal numbers (e.g., 1.5, 2.25). Always enter positive values only.\n\nScore: Points earned when completing the task.\nPenalty: Points lost per day when the task is overdue.',
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
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
                                    return 'Enter penalty (0 for no penalty)';
                                  }
                                  try {
                                    final penalty = double.parse(value);
                                    if (penalty < 0) {
                                      return 'Must be positive (≥ 0)';
                                    }
                                  } catch (e) {
                                    return 'Invalid number';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 8.w),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _penaltyController.text = _scoreController.text;
                                });
                              },
                              icon: const Icon(Icons.content_copy),
                              tooltip: 'Set penalty equal to score',
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Text(
                              'Deadline',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (kDebugMode) ...[
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4.r),
                                  border: Border.all(color: Colors.orange, width: 1),
                                ),
                                child: Text(
                                  'DEBUG: Past dates allowed',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            DateFormat('dd/MM/yyyy').format(_deadline),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: BorderSide(
                              color: Theme.of(context).focusColor,
                              width: 2.w,
                            ),
                          ),
                          onTap: () => _selectDeadline(context),
                        ),
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: _saveTask,
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                                side: BorderSide(
                                  color: Theme.of(context).focusColor,
                                  width: 2.w,
                                ),
                              ),
                            ),
                            child: Text(
                              isCompleted
                                  ? 'Reschedule Task'
                                  : (isEditing ? 'Update Task' : 'Save Task'),
                              style: TextStyle(fontSize: 16.sp),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        if (isCompleted) ...[
                          SizedBox(height: 24.h),
                          SizedBox(
                            width: double.infinity,
                            height: 50.h,
                            child: ElevatedButton(
                              onPressed: _cancelTask,
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                  side: BorderSide(
                                    color: Theme.of(context).focusColor,
                                    width: 2.w,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Cancel Task',
                                style: TextStyle(fontSize: 16.sp),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
