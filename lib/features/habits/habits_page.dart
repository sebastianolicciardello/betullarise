import 'package:flutter/material.dart';
import 'package:betullarise/database/habits_database_helper.dart';
import 'package:betullarise/features/habits/habit_detail_page.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _loadHabits,
                child: ListView(
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search habits...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Habits List
                    if (_filteredHabits.isEmpty && _isSearching) ...[
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
                              'No habits found for "${_searchController.text}"',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_habits.isEmpty) ...[
                      const SizedBox(height: 64),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.loop_rounded,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No habits created',
                              style: TextStyle(fontSize: 18),
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
        child: const Icon(Icons.add),
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

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary,
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      habit.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(typeIcon, size: 16),
                  const SizedBox(width: 12),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                habit.description,
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
                      if (habit.score > 0)
                        Text('Score: +${habit.score.toStringAsFixed(2)}'),
                      if (habit.penalty > 0)
                        Text('Penalty: -${habit.penalty.toStringAsFixed(2)}'),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.circle_outlined),
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
  }

  void _handleHabitCompletion(Habit habit) {
    final bool hasScore = habit.score > 0;
    final bool hasPenalty = habit.penalty > 0;

    // Per habit 'single' con solo score o solo penalty, esegui direttamente
    if (habit.type.startsWith('single')) {
      if (hasScore && hasPenalty) {
        // Se ha entrambi score e penalty, mostra il popup di conferma
        _showCompleteTaskDialog(habit);
      } else if (hasScore) {
        // Solo score, esegui direttamente
        _addPoints(habit.id!, habit.score);
      } else if (hasPenalty) {
        // Solo penalty, esegui direttamente
        _addPoints(habit.id!, -habit.penalty);
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
        _addPoints(habit.id!, habit.score);
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
        return AlertDialog(
          title: Text('Complete "${habit.title}"?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(message), const SizedBox(height: 16), ...choices],
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
      _addPoints(habit.id!, habit.score);
    } else if (choice == 'fail') {
      _addPoints(habit.id!, -habit.penalty);
    }
  }

  Future<void> _showMultiplerRedemptionDialog(Habit habit) async {
    final String? result = await _dialogService.showInputDialog(
      context,
      'Complete "${habit.title}"',
      message: 'Enter the multiplier value',
      initialValue: '1',
      labelText: 'Multiplier',
      keyboardType: TextInputType.numberWithOptions(decimal: true),
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
    );

    if (result != null && mounted) {
      final multiplier = double.tryParse(result) ?? 1;
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
                  children: [
                    Text(message),
                    const SizedBox(height: 16),
                    ...choices,
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

        if (choice == 'complete') {
          _addPoints(habit.id!, totalScore);
        } else if (choice == 'fail') {
          _addPoints(habit.id!, -totalPenalty);
        }
      } else if (hasScore) {
        _addPoints(habit.id!, totalScore);
      } else if (hasPenalty) {
        _addPoints(habit.id!, -totalPenalty);
      }
    }
  }

  void _addPoints(int habitId, double points) {
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);

    // Create a point object
    final point = Point(
      referenceId: habitId,
      type: 'habit',
      points: points,
      insertTime: DateTime.now().millisecondsSinceEpoch,
    );

    // Save the points
    pointsProvider.savePoints(point);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          points >= 0
              ? 'Good job! +${points.toStringAsFixed(1)} points'
              : 'Better luck next time! ${points.toStringAsFixed(1)} points',
        ),
        duration: const Duration(
          seconds: 4,
        ), // Extended duration for undo action
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.red,
          onPressed: () {
            // Remove the points
            pointsProvider.removePointsByEntity(point);

            // Show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  points >= 0
                      ? 'Habit completion undone. -${points.toStringAsFixed(1)} points'
                      : 'Habit failure undone. +${(-points).toStringAsFixed(1)} points',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}
