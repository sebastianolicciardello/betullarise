import 'package:flutter/material.dart';
import 'package:betullarise/database/habits_database_helper.dart';
import 'package:betullarise/features/habits/habit_detail_page.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:provider/provider.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final HabitsDatabaseHelper _dbHelper = HabitsDatabaseHelper.instance;
  List<Habit> _habits = [];
  List<Habit> _filteredHabits = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
                        Text('Score: +${habit.score.toStringAsFixed(1)}'),
                      if (habit.penalty > 0)
                        Text('Penalty: -${habit.penalty.toStringAsFixed(1)}'),
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

    showDialog(
      context: context,
      builder: (BuildContext context) {
        if (habit.type.startsWith('single')) {
          return AlertDialog(
            title: Text('Complete "${habit.title}"?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('What would you like to do?'),
                const SizedBox(height: 8),
                if (hasScore)
                  Text(
                    'Completing will add ${habit.score.toStringAsFixed(1)} points',
                  ),
                if (hasPenalty)
                  Text(
                    'Failing will subtract ${habit.penalty.toStringAsFixed(1)} points',
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              if (hasScore)
                TextButton(
                  onPressed: () {
                    _addPoints(habit.id!, habit.score);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                  child: Text('Complete (+${habit.score})'),
                ),
              if (hasPenalty)
                TextButton(
                  onPressed: () {
                    _addPoints(habit.id!, -habit.penalty);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Failed (-${habit.penalty})'),
                ),
            ],
          );
        } else if (habit.type.startsWith('multipler')) {
          return _buildMultiplerCompletionDialog(habit);
        } else {
          return AlertDialog(
            title: Text(habit.title),
            content: const Text('Unsupported habit type'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildMultiplerCompletionDialog(Habit habit) {
    final TextEditingController multiplerController = TextEditingController(
      text: '1',
    );
    final bool hasScore = habit.score > 0;
    final bool hasPenalty = habit.penalty > 0;

    return StatefulBuilder(
      builder: (context, setState) {
        final double multiplier =
            double.tryParse(multiplerController.text) ?? 1;
        final double totalScore = multiplier * habit.score;
        final double totalPenalty = multiplier * habit.penalty;

        return AlertDialog(
          title: Text(habit.title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: multiplerController,
                decoration: const InputDecoration(
                  labelText: 'Multiplier',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              if (hasScore) Text('Score: ${totalScore.toStringAsFixed(1)}'),
              if (hasPenalty)
                Text('Penalty: ${totalPenalty.toStringAsFixed(1)}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (hasScore)
              TextButton(
                onPressed: () {
                  _addPoints(habit.id!, totalScore);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.green),
                child: const Text('Complete'),
              ),
            if (hasPenalty)
              TextButton(
                onPressed: () {
                  _addPoints(habit.id!, -totalPenalty);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Failed'),
              ),
          ],
        );
      },
    );
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
