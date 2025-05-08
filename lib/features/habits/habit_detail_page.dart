import 'package:flutter/material.dart';
import 'package:betullarise/model/habit.dart';
import 'package:betullarise/database/habits_database_helper.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

class HabitDetailPage extends StatefulWidget {
  final Habit? habit;

  const HabitDetailPage({super.key, this.habit});

  @override
  State<HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<HabitDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _penaltyController = TextEditingController();
  final _scoreController = TextEditingController();

  String _selectedType = 'single'; // Default type
  bool _includeScore = true;
  bool _includePenalty = false;

  final HabitsDatabaseHelper _dbHelper = HabitsDatabaseHelper.instance;
  final DialogService _dialogService = DialogService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.habit != null) {
      _titleController.text = widget.habit!.title;
      _descriptionController.text = widget.habit!.description;
      _penaltyController.text = widget.habit!.penalty.toString();
      _scoreController.text = widget.habit!.score.toString();

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
    } else {
      // Set default values for new habit
      _scoreController.text = '1.0';
      _penaltyController.text = '1.0';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable at least Score or Penalty'),
        ),
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

      final habit = Habit(
        id: widget.habit?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        score: score,
        penalty: penalty,
        type: _determineHabitType(),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting habit: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.habit != null;

    return Scaffold(
      appBar: AppBar(
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
                            return 'Please enter a title';
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
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Habit Type',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Single'),
                              value: 'single',
                              groupValue: _selectedType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value!;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: const Text('Multipler'),
                              value: 'multipler',
                              groupValue: _selectedType,
                              onChanged: (value) {
                                setState(() {
                                  _selectedType = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Points',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Compact Score Row
                      Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                inactiveThumbColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.5),
                                inactiveTrackColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(0x1A),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Score',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _scoreController,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(),
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
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
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
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                inactiveThumbColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(0x80),
                                inactiveTrackColor: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(0x1A),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                flex: 2,
                                child: Text(
                                  'Penalty',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _penaltyController,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  enabled: _includePenalty,
                                  validator: (value) {
                                    if (!_includePenalty) return null;
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    try {
                                      final penalty = double.parse(value);
                                      if (penalty <= 0) {
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
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveHabit,
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
                            isEditing ? 'Update Habit' : 'Save Habit',
                            style: const TextStyle(fontSize: 16),
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
