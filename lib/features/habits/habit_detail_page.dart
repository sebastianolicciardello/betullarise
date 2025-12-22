import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/database/habits_database_helper.dart';
import 'package:betullarise/services/ui/dialog_service.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';
import 'package:betullarise/widgets/info_tooltip.dart';

class HabitDetailPage extends StatefulWidget {
  final Habit? habit;
  final HabitsDatabaseHelper? dbHelper;

  const HabitDetailPage({super.key, this.habit, this.dbHelper});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  // Per il controllo delle modifiche
  String? _initialTitle;
  String? _initialDescription;
  String? _initialPenalty;
  String? _initialScore;
  String? _initialType;
  bool? _initialIncludeScore;
  bool? _initialIncludePenalty;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _scoreController = TextEditingController();
  final _goalController = TextEditingController();

  String _selectedType = 'single'; // Default type
  bool _includeScore = true;
  bool _includePenalty = false;
  bool _showStreak = false;
  bool _showStreakMultiplier = false;

  late final HabitsDatabaseHelper _dbHelper;
  final DialogService _dialogService = DialogService();
  bool _isLoading = false;
  bool _isShowingDiscardDialog = false;

  @override
  void initState() {
    super.initState();
    _dbHelper = widget.dbHelper ?? HabitsDatabaseHelper.instance;
    _goalController.addListener(() {
      setState(() {});
    });
    if (widget.habit != null) {
      _titleController.text = widget.habit!.title;
      _descriptionController.text = widget.habit!.description;
      _penaltyController.text = widget.habit!.penalty.toString();
      _scoreController.text = widget.habit!.score.toString();
      _goalController.text = widget.habit!.goal?.toString() ?? '';

      // Determine habit type and properties
      final type = widget.habit!.type;
      if (type.startsWith('single')) {
        _selectedType = 'single';
      } else if (type.startsWith('multipler')) {
        _selectedType = 'multipler';
      }

      _includeScore =
          widget.habit!.score > 0 ||
          type == 'singleWithScore' ||
          type == 'multiplerWithScore' ||
          type == 'single' ||
          type == 'multipler';

      _includePenalty =
          widget.habit!.penalty > 0 ||
          type == 'singleWithPenalty' ||
          type == 'multiplerWithPenalty';

      // Salva valori iniziali
      _initialTitle = widget.habit!.title;
      _initialDescription = widget.habit!.description;
      _initialPenalty = widget.habit!.penalty.toString();
      _initialScore = widget.habit!.score.toString();
      _initialType = _selectedType;
      _initialIncludeScore = _includeScore;
      _initialIncludePenalty = _includePenalty;
      _showStreak = widget.habit!.showStreak;
      _showStreakMultiplier = widget.habit!.showStreakMultiplier;
    } else {
      // Set default values for new habit
      _scoreController.text = '1.0';
      _penaltyController.text = '0.0';
      _goalController.text = '';

      _initialTitle = '';
      _initialDescription = '';
      _initialPenalty = '0.0';
      _initialScore = '1.0';
      _initialType = _selectedType;
      _initialIncludeScore = _includeScore;
      _initialIncludePenalty = _includePenalty;
      _showStreak = false;
      _showStreakMultiplier = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _penaltyController.dispose();
    _scoreController.dispose();
    _goalController.dispose();
    super.dispose();
  }

  bool get _isDirty {
    return _titleController.text != (_initialTitle ?? '') ||
        _descriptionController.text != (_initialDescription ?? '') ||
        _penaltyController.text != (_initialPenalty ?? '') ||
        _scoreController.text != (_initialScore ?? '') ||
        _goalController.text != (widget.habit?.goal?.toString() ?? '') ||
        _selectedType != (_initialType ?? 'single') ||
        _includeScore != (_initialIncludeScore ?? true) ||
        _includePenalty != (_initialIncludePenalty ?? false) ||
        _showStreak != (widget.habit?.showStreak ?? false) ||
        _showStreakMultiplier != (widget.habit?.showStreakMultiplier ?? false);
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

  String _determineHabitType() {
    final baseType = _selectedType; // 'single' or 'multipler'

    if (_includeScore && _includePenalty) {
      return baseType; // Default type includes both
    } else if (_includeScore) {
      return '${baseType}WithScore';
    } else if (_includePenalty) {
      return '${baseType}WithPenalty';
    } else {
      // At least one should be included, default to score
      return '${baseType}WithScore';
    }
  }

  Future<void> _saveHabit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if at least score or penalty is enabled
    if (!_includeScore && !_includePenalty) {
      SnackbarService.showWarningSnackbar(
        context,
        'Please enable at least Score or Penalty',
      );
      return;
    }

    // Se stiamo modificando un'abitudine esistente, chiedi conferma
    if (widget.habit != null) {
      final bool? shouldUpdate = await _dialogService.showConfirmDialog(
        context,
        'Update Habit',
        'Are you sure you want to update "${_titleController.text}"?',
        confirmText: 'Update',
        cancelText: 'Cancel',
      );

      if (shouldUpdate != true) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final double score =
          _includeScore ? double.parse(_scoreController.text) : 0;
      final double penalty =
          _includePenalty ? double.parse(_penaltyController.text) : 0;

      int? goal;
      if (_selectedType == 'multipler' && _goalController.text.isNotEmpty) {
        goal = int.tryParse(_goalController.text);
      }

      final habit = Habit(
        id: widget.habit?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        score: score,
        penalty: penalty,
        type: _determineHabitType(),
        showStreak: _showStreak,
        showStreakMultiplier: _showStreakMultiplier,
        goal: goal,
        createdTime: widget.habit?.createdTime ?? now,
        updatedTime: now,
      );

      if (widget.habit == null) {
        await _dbHelper.insertHabit(habit);
      } else {
        await _dbHelper.updateHabit(habit);
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
        SnackbarService.showErrorSnackbar(context, 'Error: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteHabit() async {
    final bool? shouldDelete = await _dialogService.showConfirmDialog(
      context,
      'Delete Habit',
      'Are you sure you want to delete "${_titleController.text}"?\n\n'
          'This will NOT affect any points previously earned or lost with this habit.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmColor: Colors.red,
      isDangerous: true,
    );

    if (shouldDelete != true || widget.habit?.id == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _dbHelper.deleteHabit(widget.habit!.id!);

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
          'Error deleting habit: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.habit != null;

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
          title: Text(isEditing ? 'Edit Habit' : 'New Habit'),
          actions:
              isEditing
                  ? [
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: _deleteHabit,
                      tooltip: 'Delete Habit',
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
                              return 'Please enter a title';
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
                            Text(
                              'Habit Type',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InfoTooltip(
                              title: 'Habit Types',
                              message:
                                  'Single: Simple habits that you complete and earn the base score. Perfect for habits like "drink 8 glasses of water" or "take vitamins".\n\nMultipler: Habits with a multiplier based on quantity, duration, or intensity. For example, "Running" - if you set multiplier to 1 you get points for 10 minutes of running, if you set 6 you get points for 60 minutes of running. Great for scalable activities like exercise, reading, or studying.',
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        RadioGroup<String>(
                          groupValue: _selectedType,
                          onChanged: (value) {
                            setState(() {
                              _selectedType = value!;
                            });
                          },
                          child: Row(
                            children: [
                              Expanded(
                                child: RadioListTile<String>(
                                  title: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: const Text('Single'),
                                  ),
                                  value: 'single',
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<String>(
                                  title: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: const Text('Multipler'),
                                  ),
                                  value: 'multipler',
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Text(
                              'Points',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            InfoTooltip(
                              title: 'About Points',
                              message:
                                  'Score and Penalty values can be decimal numbers (e.g., 1.5, 2.25). Always enter positive values only - the app handles the math automatically.\n\nScore: Points earned when completing the habit.\nPenalty: Points lost when missing the habit (for habits with penalties enabled).',
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        // Compact Score Row
                        Card(
                          margin: EdgeInsets.symmetric(vertical: 8.h),
                          child: Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Row(
                              children: [
                                Switch(
                                  value: _includeScore,
                                  onChanged: (value) {
                                    setState(() {
                                      _includeScore = value;
                                      if (!value && !_includePenalty) {
                                        _includePenalty =
                                            true; // Ensure at least one is selected
                                      }
                                    });
                                  },
                                  // Theme color
                                  activeThumbColor:
                                      Theme.of(context).colorScheme.primary,
                                  activeTrackColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  inactiveThumbColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  inactiveTrackColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.1),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Score',
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _scoreController,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 12.h,
                                      ),
                                      border: const OutlineInputBorder(),
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    enabled: _includeScore,
                                    validator: (value) {
                                      if (!_includeScore) return null;
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      try {
                                        final score = double.parse(value);
                                        if (score <= 0) {
                                          return 'Must be > 0';
                                        }
                                      } catch (e) {
                                        return 'Invalid number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Compact Penalty Row
                        Card(
                          margin: EdgeInsets.symmetric(vertical: 8.h),
                          child: Padding(
                            padding: EdgeInsets.all(8.w),
                            child: Row(
                              children: [
                                Switch(
                                  value: _includePenalty,
                                  onChanged: (value) {
                                    setState(() {
                                      _includePenalty = value;
                                      if (!value && !_includeScore) {
                                        _includeScore =
                                            true; // Ensure at least one is selected
                                      }
                                    });
                                  },
                                  // Theme color
                                  activeThumbColor:
                                      Theme.of(context).colorScheme.primary,
                                  activeTrackColor: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.3),
                                  inactiveThumbColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                  inactiveTrackColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.1),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Penalty',
                                    style: TextStyle(fontSize: 16.sp),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _penaltyController,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12.w,
                                                  vertical: 12.h,
                                                ),
                                            border: const OutlineInputBorder(),
                                          ),
                                          keyboardType:
                                              const TextInputType.numberWithOptions(
                                                decimal: true,
                                              ),
                                          enabled: _includePenalty,
                                          validator: (value) {
                                            if (!_includePenalty) return null;
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Required';
                                            }
                                            try {
                                              final penalty = double.parse(
                                                value,
                                              );
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
                                      SizedBox(width: 4.w),
                                      IconButton(
                                        onPressed:
                                            _includePenalty && _includeScore
                                                ? () {
                                                  setState(() {
                                                    _penaltyController.text =
                                                        _scoreController.text;
                                                  });
                                                }
                                                : null,
                                        icon: Icon(
                                          Icons.content_copy,
                                          size: 18.sp,
                                        ),
                                        tooltip: 'Set penalty equal to score',
                                        padding: EdgeInsets.all(4.w),
                                        constraints: BoxConstraints(
                                          minWidth: 32.w,
                                          minHeight: 32.h,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        // Goal field for multipler habits
                        if (_selectedType == 'multipler') ...[
                          Row(
                            children: [
                              Text(
                                'Goal',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              InfoTooltip(
                                title: 'Goal',
                                message:
                                    'Set a daily goal for this habit. The card will turn green when you reach this goal today.',
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Card(
                            margin: EdgeInsets.symmetric(vertical: 8.h),
                            child: Padding(
                              padding: EdgeInsets.all(8.w),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _goalController,
                                          decoration: InputDecoration(
                                            labelText: 'Daily Goal',
                                            hintText: 'e.g., 5',
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12.w,
                                                  vertical: 12.h,
                                                ),
                                            border: const OutlineInputBorder(),
                                          ),
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (value) {
                                            if (value != null &&
                                                value.isNotEmpty) {
                                              final goal = int.tryParse(value);
                                              if (goal == null || goal <= 0) {
                                                return 'Must be a positive number';
                                              }
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Streak toggle for multipler habits
                        if (_selectedType == 'multipler') ...[
                          Row(
                            children: [
                              Text(
                                'Streak Visualization',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              InfoTooltip(
                                title: 'Streak Visualization',
                                message:
                                    'When enabled, shows a fire icon when you reach your daily goal both yesterday and today. Awards a 2x multiplier bonus on points when reaching the goal consecutively.',
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Card(
                            margin: EdgeInsets.symmetric(vertical: 8.h),
                            child: Padding(
                              padding: EdgeInsets.all(8.w),
                              child: Row(
                                children: [
                                  Switch(
                                    value: _showStreakMultiplier,
                                    onChanged:
                                        (_goalController.text.isNotEmpty &&
                                                int.tryParse(
                                                      _goalController.text,
                                                    ) !=
                                                    null &&
                                                int.tryParse(
                                                      _goalController.text,
                                                    )! >
                                                    0)
                                            ? (value) {
                                              setState(() {
                                                _showStreakMultiplier = value;
                                              });
                                            }
                                            : null,
                                    activeThumbColor:
                                        Theme.of(context).colorScheme.primary,
                                    activeTrackColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                    inactiveThumbColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    inactiveTrackColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.1),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Show streak indicator',
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        // Streak toggle for single habits
                        if (_selectedType == 'single') ...[
                          Row(
                            children: [
                              Text(
                                'Streak Visualization',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              InfoTooltip(
                                title: 'Streak Visualization',
                                message:
                                    'When enabled, shows a fire icon when you complete the habit both yesterday and today. This helps you maintain consistent daily habits.',
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Card(
                            margin: EdgeInsets.symmetric(vertical: 8.h),
                            child: Padding(
                              padding: EdgeInsets.all(8.w),
                              child: Row(
                                children: [
                                  Switch(
                                    value: _showStreak,
                                    onChanged: (value) {
                                      setState(() {
                                        _showStreak = value;
                                      });
                                    },
                                    activeThumbColor:
                                        Theme.of(context).colorScheme.primary,
                                    activeTrackColor: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.3),
                                    inactiveThumbColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                                    inactiveTrackColor: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.1),
                                  ),
                                  SizedBox(width: 8.w),
                                  Expanded(
                                    child: Text(
                                      'Show streak indicator',
                                      style: TextStyle(fontSize: 16.sp),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: 24.h),
                        SizedBox(
                          width: double.infinity,
                          height: 50.h,
                          child: ElevatedButton(
                            onPressed: _saveHabit,
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
                              isEditing ? 'Update Habit' : 'Save Habit',
                              style: TextStyle(fontSize: 16.sp),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
      ),
    );
  }
}
