import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:betullarise/database/habits_database_helper.dart';
import 'package:betullarise/features/habits/habit_detail_page.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/services/ui/dialog_service.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';
import 'package:betullarise/services/habit_completion_date_picker_service.dart';
import 'package:intl/intl.dart';

class HabitsPage extends StatefulWidget {
  final HabitsDatabaseHelper? dbHelper;
  const HabitsPage({super.key, this.dbHelper});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  late final HabitsDatabaseHelper _dbHelper;
  final DialogService _dialogService = DialogService();
  List<Habit> _habits = [];
  List<Habit> _filteredHabits = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Set<int> _expandedCards = <int>{};
  final Map<int, int> _habitCompletionKeys = <int, int>{};

  @override
  void initState() {
    super.initState();
    _dbHelper = widget.dbHelper ?? HabitsDatabaseHelper.instance;
    _searchController.addListener(_onSearchChanged);
    _loadHabits();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterHabits(_searchController.text);
  }

  void _filterHabits(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredHabits = List.from(_habits);
        _isSearching = false;
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    final filtered =
        _habits.where((habit) {
          return habit.title.toLowerCase().contains(lowerCaseQuery) ||
              habit.description.toLowerCase().contains(lowerCaseQuery);
        }).toList();

    setState(() {
      _filteredHabits = filtered;
      _isSearching = true;
    });
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago at ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  Future<void> _loadHabits() async {
    setState(() {
      _isLoading = true;
    });

    final habits = await _dbHelper.queryAllHabits();

    // Sort habits by title
    habits.sort((a, b) => a.title.compareTo(b.title));

    setState(() {
      _habits = habits;
      _filteredHabits = List.from(habits);
      _isLoading = false;
    });
  }

  Future<bool> _shouldShowGreenBorder(Habit habit) async {
    if (habit.id == null) return false;

    final todaysCompletions = await _dbHelper.countTodaysCompletions(habit.id!);

    // Condition 1: Single habit completed at least once today
    if (habit.type.startsWith('single') && todaysCompletions > 0) {
      return true;
    }

    // Condition 2: Multipler habit without goal completed at least once today
    if (habit.type.startsWith('multipler') &&
        habit.goal == null &&
        todaysCompletions > 0) {
      return true;
    }

    // Condition 3: Multipler habit with goal completed today (goal reached)
    if (habit.type.startsWith('multipler') && habit.goal != null) {
      final todaysProgress = await _dbHelper.getTodaysProgress(habit.id!);
      if (todaysProgress >= habit.goal!) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadHabits,
                child: ListView(
                  padding: EdgeInsets.only(top: 16.h, bottom: 80.h),
                  children: [
                    // Search Bar
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 4.h,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search habits...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),

                    // Habits List
                    if (_filteredHabits.isEmpty && _isSearching) ...[
                      SizedBox(height: 40.h),
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
                              'No habits found for "${_searchController.text}"',
                              style: TextStyle(fontSize: 18.sp),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_habits.isEmpty) ...[
                      SizedBox(height: 40.h),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.loop_rounded,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No habits created',
                              style: TextStyle(fontSize: 18.sp),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ..._filteredHabits.map(_buildHabitCard),
                    ],
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HabitDetailPage()),
          );
          if (result == true) {
            _loadHabits();
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

  Widget _buildHabitCard(Habit habit) {
    IconData typeIcon;

    if (habit.type.startsWith('single')) {
      typeIcon = Icons.plus_one;
    } else if (habit.type.startsWith('multipler')) {
      typeIcon = Icons.filter_9_plus;
    } else {
      typeIcon = Icons.question_mark;
    }

    final bool hasDescription = habit.description.trim().isNotEmpty;
    const int maxDescriptionLines = 2;
    const double minCardHeight = 56;
    const double normalCardHeight = 120;

    return FutureBuilder<bool>(
      future: _shouldShowGreenBorder(habit),
      builder: (context, snapshot) {
        final shouldShowGreen = snapshot.data ?? false;
        return Card(
          key: ValueKey(
            'habit_${habit.id}_${_habitCompletionKeys[habit.id] ?? 0}',
          ),
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.r),
            side: BorderSide(
              color:
                  shouldShowGreen
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HabitDetailPage(habit: habit),
                ),
              );
              if (result == true) {
                _loadHabits();
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
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                habit.title,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Show fire icon for streak if enabled
                            if ((habit.type.startsWith('single') &&
                                    habit.showStreak) ||
                                (habit.type.startsWith('multipler') &&
                                    habit.showStreakMultiplier))
                              FutureBuilder<bool>(
                                future:
                                    habit.type.startsWith('single')
                                        ? _dbHelper.hasStreak(habit.id!)
                                        : _dbHelper.hasStreakMultiplier(
                                          habit.id!,
                                        ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const SizedBox.shrink();
                                  }
                                  if (snapshot.hasData &&
                                      snapshot.data == true) {
                                    return Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 16.sp,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            // Show dot indicating if yesterday was completed
                            if ((habit.type.startsWith('single') &&
                                    habit.showStreak) ||
                                (habit.type.startsWith('multipler') &&
                                    habit.showStreakMultiplier))
                              FutureBuilder<bool>(
                                future:
                                    habit.type.startsWith('single')
                                        ? _dbHelper.wasCompletedYesterday(
                                          habit.id!,
                                        )
                                        : _dbHelper.wasGoalReachedYesterday(
                                          habit.id!,
                                        ),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting ||
                                      snapshot.data != true) {
                                    return const SizedBox.shrink();
                                  }
                                  return Container(
                                    width: 8.sp,
                                    height: 8.sp,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.green,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Icon(typeIcon, size: 16.sp),
                      SizedBox(width: 12.w),
                    ],
                  ),
                  if (hasDescription) ...[
                    SizedBox(height: 8.h),
                    Builder(
                      builder: (context) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isExpanded = _expandedCards.contains(
                              habit.id,
                            );
                            final span = TextSpan(
                              text: habit.description,
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
                                  habit.description,
                                  maxLines:
                                      isExpanded ? null : maxDescriptionLines,
                                  overflow:
                                      isExpanded
                                          ? TextOverflow.visible
                                          : TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                                if (isOverflowing) ...[
                                  SizedBox(height: 4.h),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isExpanded) {
                                          _expandedCards.remove(habit.id);
                                        } else {
                                          _expandedCards.add(habit.id!);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(4.r),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4.w,
                                        vertical: 2.h,
                                      ),
                                      child: Text(
                                        isExpanded
                                            ? '▲ Show less'
                                            : '▼ Show more',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    ),
                    SizedBox(height: 12.h),
                  ] else ...[
                    SizedBox(height: 8.h),
                  ],
                  // Progress bar for multipler habits with goals
                  if (habit.type.startsWith('multipler') &&
                      habit.goal != null &&
                      habit.goal! > 0) ...[
                    FutureBuilder<double>(
                      future: _dbHelper.getTodaysProgress(habit.id!),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        final currentProgress = snapshot.data ?? 0.0;
                        final goal = habit.goal!.toDouble();
                        final progressValue = (currentProgress / goal).clamp(
                          0.0,
                          1.0,
                        );

                        // Format numbers: show decimal only if not .0
                        String formatNumber(double num) {
                          return num % 1 == 0
                              ? num.toInt().toString()
                              : num.toStringAsFixed(1);
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress: ${formatNumber(currentProgress)}/${formatNumber(goal)}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            LinearProgressIndicator(
                              value: progressValue,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progressValue >= 1.0
                                    ? Colors.green
                                    : Theme.of(context).colorScheme.primary,
                              ),
                              minHeight: 6.h,
                            ),
                            SizedBox(height: 12.h),
                          ],
                        );
                      },
                    ),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (habit.score > 0)
                              Text('Score: +${habit.score.toStringAsFixed(2)}'),
                            if (habit.penalty > 0)
                              Text(
                                'Penalty: -${habit.penalty.toStringAsFixed(2)}',
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.circle_outlined, size: 24.sp),
                        onPressed: () {
                          _handleHabitCompletion(habit);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleHabitCompletion(Habit habit) {
    final bool hasScore = habit.score > 0;
    final bool hasPenalty = habit.penalty > 0;

    // Per habit 'single' con solo score o solo penalty, mostra dialog semplice
    if (habit.type.startsWith('single')) {
      if (hasScore && hasPenalty) {
        // Se ha entrambi score e penalty, mostra il popup di conferma
        _showCompleteTaskDialog(habit);
      } else if (hasScore) {
        // Solo score, mostra dialog semplice con data
        _showSingleHabitSimpleDialog(habit, habit.score);
      } else if (hasPenalty) {
        // Solo penalty, mostra dialog semplice con data
        _showSingleHabitSimpleDialog(habit, -habit.penalty);
      }
    } else if (habit.type.startsWith('multipler')) {
      // Per multipler mantieni il comportamento attuale
      _showCompleteTaskDialog(habit);
    }
  }

  void _showCompleteTaskDialog(Habit habit) {
    final bool hasScore = habit.score > 0;
    final bool hasPenalty = habit.penalty > 0;

    if (habit.type.startsWith('single')) {
      if (hasScore && hasPenalty) {
        _showSingleHabitChoiceDialog(habit);
      } else if (hasScore) {
        _addPoints(
          habit.id!,
          habit.score,
          DateTime.now().millisecondsSinceEpoch,
        );
      } else if (hasPenalty) {
        _addPoints(habit.id!, -habit.penalty);
      }
    } else if (habit.type.startsWith('multipler')) {
      _showMultiplerRedemptionDialog(habit);
    } else {
      _dialogService.showResultDialog(
        context,
        habit.title,
        'Unsupported habit type',
      );
    }
  }

  Future<void> _showSingleHabitChoiceDialog(Habit habit) async {
    DateTime selectedDate = DateTime.now();

    final message =
        'What would you like to do?\n\n'
        'Completing will add ${habit.score.toStringAsFixed(1)} points\n'
        'Failing will subtract ${habit.penalty.toStringAsFixed(1)} points';

    final List<Widget> choices = [
      ListTile(
        title: Text(
          'Complete (+${habit.score})',
          style: const TextStyle(color: Colors.green),
        ),
        onTap: () => Navigator.of(context).pop('complete'),
      ),
      ListTile(
        title: Text(
          'Failed (-${habit.penalty})',
          style: const TextStyle(color: Colors.red),
        ),
        onTap: () => Navigator.of(context).pop('fail'),
      ),
    ];

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Complete "${habit.title}"?'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    SizedBox(height: 16.h),
                    ...choices,
                    SizedBox(height: 16.h),
                    const Divider(),
                    SizedBox(height: 8.h),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate =
                            await HabitCompletionDatePickerService.showCompletionDatePicker(
                              context: context,
                              initialDate: selectedDate,
                            );
                        if (pickedDate != null) {
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (choice == 'complete') {
      _addPoints(habit.id!, habit.score, selectedDate.millisecondsSinceEpoch);
    } else if (choice == 'fail') {
      _addPoints(
        habit.id!,
        -habit.penalty,
        selectedDate.millisecondsSinceEpoch,
      );
    }
  }

  Future<void> _showMultiplerRedemptionDialog(Habit habit) async {
    DateTime selectedDate = DateTime.now();
    String multiplierValue = '1';

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Complete "${habit.title}"'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: multiplierValue,
                      decoration: const InputDecoration(
                        labelText: 'Multiplier',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        multiplierValue = value;
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a value';
                        }
                        final multiplier = double.tryParse(value);
                        if (multiplier == null || multiplier <= 0) {
                          return 'Please enter a valid positive number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16.h),
                    const Divider(),
                    SizedBox(height: 8.h),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate =
                            await HabitCompletionDatePickerService.showCompletionDatePicker(
                              context: context,
                              initialDate: selectedDate,
                            );
                        if (pickedDate != null) {
                          setState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.black,
                  ),
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      final multiplier = double.tryParse(multiplierValue) ?? 1;
      final totalScore = multiplier * habit.score;
      final totalPenalty = multiplier * habit.penalty;
      final bool hasScore = habit.score > 0;
      final bool hasPenalty = habit.penalty > 0;

      if (hasScore && hasPenalty) {
        final message =
            'What would you like to do?\n\n'
            'Completing will add ${totalScore.toStringAsFixed(1)} points\n'
            'Failing will subtract ${totalPenalty.toStringAsFixed(1)} points';

        final List<Widget> choices = [
          ListTile(
            title: Text(
              'Complete (+${totalScore.toStringAsFixed(1)})',
              style: const TextStyle(color: Colors.green),
            ),
            onTap: () => Navigator.of(context).pop('complete'),
          ),
          ListTile(
            title: Text(
              'Failed (-${totalPenalty.toStringAsFixed(1)})',
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () => Navigator.of(context).pop('fail'),
          ),
        ];

        final String? choice = await showDialog<String>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Action'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(message), SizedBox(height: 16.h), ...choices],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );

        if (choice == 'complete') {
          _addPoints(
            habit.id!,
            totalScore,
            selectedDate.millisecondsSinceEpoch,
          );
        } else if (choice == 'fail') {
          _addPoints(
            habit.id!,
            -totalPenalty,
            selectedDate.millisecondsSinceEpoch,
          );
        }
      } else if (hasScore) {
        _addPoints(habit.id!, totalScore, selectedDate.millisecondsSinceEpoch);
      } else if (hasPenalty) {
        _addPoints(
          habit.id!,
          -totalPenalty,
          selectedDate.millisecondsSinceEpoch,
        );
      }
    }
  }

  Future<void> _showSingleHabitSimpleDialog(Habit habit, double points) async {
    DateTime selectedDate = DateTime.now();

    final String action = points > 0 ? 'Complete' : 'Fail';
    final String pointsText =
        points > 0
            ? '+${points.toStringAsFixed(1)} points'
            : '${points.toStringAsFixed(1)} points';

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('${action} "${habit.title}"?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('This will give you $pointsText'),
                  SizedBox(height: 16.h),
                  InkWell(
                    onTap: () async {
                      final DateTime? pickedDate =
                          await HabitCompletionDatePickerService.showCompletionDatePicker(
                            context: context,
                            initialDate: selectedDate,
                          );
                      if (pickedDate != null) {
                        setState(() {
                          selectedDate = pickedDate;
                        });
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Date: ${DateFormat('dd/MM/yyyy').format(selectedDate)}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.white
                            : Colors.black,
                  ),
                  child: Text(action),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true) {
      _addPoints(habit.id!, points, selectedDate.millisecondsSinceEpoch);
    }
  }

  void _addPoints(int habitId, double points, [int? completionTime]) async {
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);

    // Get the habit to check if it's a single type and if strike bonus applies
    final habit = await _dbHelper.queryHabitById(habitId);
    if (habit == null) return;

    double finalPoints = points;
    bool strikeBonusAwarded = false;

    // Check if this habit should award strike bonus
    if (habit.type.startsWith('single') && habit.showStreak) {
      final shouldAwardStrike = await _dbHelper.shouldAwardStrikeBonus(habitId);
      if (shouldAwardStrike) {
        finalPoints = points * 2; // Double the points!
        strikeBonusAwarded = true;
      }
    } else if (habit.type.startsWith('multipler') &&
        habit.showStreakMultiplier) {
      final shouldAwardStrike = await _dbHelper
          .shouldAwardStrikeMultiplierBonus(habitId, points);
      if (shouldAwardStrike) {
        finalPoints =
            points + (habit.score * 2); // Add bonus of score * 2 for streak!
        strikeBonusAwarded = true;
      }
    }

    // Record habit completion with the base points (without bonus)
    await _dbHelper.insertHabitCompletion(habitId, points, completionTime);

    // Update the completion key to force UI refresh
    setState(() {
      _habitCompletionKeys[habitId] = (_habitCompletionKeys[habitId] ?? 0) + 1;
    });

    // Create a point object
    final point = Point(
      referenceId: habitId,
      type: 'habit',
      points: finalPoints,
      insertTime: DateTime.now().millisecondsSinceEpoch,
    );

    // Save the points
    pointsProvider.savePoints(point);

    // Build the appropriate message
    String message;
    if (strikeBonusAwarded) {
      final bonusText =
          habit.type.startsWith('single') ? 'doubled!' : 'multiplier x2 bonus!';
      if (finalPoints >= 0) {
        message =
            '🔥 STRIKE! +${finalPoints.toStringAsFixed(1)} points ($bonusText)';
      } else {
        message =
            '🔥 STRIKE! ${finalPoints.toStringAsFixed(1)} points ($bonusText)';
      }
    } else {
      message =
          finalPoints >= 0
              ? 'Good job! +${finalPoints.toStringAsFixed(1)} points'
              : 'Better luck next time! ${finalPoints.toStringAsFixed(1)} points';
    }

    SnackbarService.showSnackbar(
      context,
      message,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'UNDO',
        textColor: Colors.red,
        onPressed: () {
          // Remove the points
          pointsProvider.removePointsByEntity(point);

          // Show confirmation
          String undoMessage;
          if (strikeBonusAwarded) {
            undoMessage =
                finalPoints >= 0
                    ? 'Strike bonus undone. -${finalPoints.toStringAsFixed(1)} points'
                    : 'Strike penalty undone. +${(-finalPoints).toStringAsFixed(1)} points';
          } else {
            undoMessage =
                finalPoints >= 0
                    ? 'Habit completion undone. -${finalPoints.toStringAsFixed(1)} points'
                    : 'Habit failure undone. +${(-finalPoints).toStringAsFixed(1)} points';
          }

          SnackbarService.showSnackbar(
            context,
            undoMessage,
            duration: const Duration(seconds: 2),
          );
        },
      ),
    );
  }
}
