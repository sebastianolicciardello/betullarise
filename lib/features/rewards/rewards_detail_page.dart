import 'package:flutter/material.dart';
import 'package:betullarise/model/reward.dart';
import 'package:betullarise/database/rewards_database_helper.dart';

class RewardDetailPage extends StatefulWidget {
  final Reward? reward;

  const RewardDetailPage({super.key, this.reward});

  @override
  State<RewardDetailPage> createState() => _RewardDetailPageState();
}

class _RewardDetailPageState extends State<RewardDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pointsController = TextEditingController();

  String _selectedType = 'single'; // Default type
  final RewardsDatabaseHelper _dbHelper = RewardsDatabaseHelper.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.reward != null) {
      _titleController.text = widget.reward!.title;
      _descriptionController.text = widget.reward!.description;
      _pointsController.text = widget.reward!.points.toString();

      // Determine reward type
      _selectedType = widget.reward!.type;
    } else {
      // Set default values for new reward
      _pointsController.text = '1.0';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _saveReward() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final double points = double.parse(_pointsController.text);

      final reward = Reward(
        id: widget.reward?.id,
        title: _titleController.text,
        description: _descriptionController.text,
        points: points,
        type: _selectedType,
        insertTime: widget.reward?.insertTime ?? now,
        updateTime: now,
      );

      if (widget.reward == null) {
        await _dbHelper.insertReward(reward);
      } else {
        await _dbHelper.updateReward(reward);
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

  Future<void> _deleteReward() async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Reward'),
            content: Text(
              'Are you sure you want to delete "${_titleController.text}"?\n\n'
              'This will NOT affect any points previously redeemed with this reward.',
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

    if (shouldDelete != true || widget.reward?.id == null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _dbHelper.deleteReward(widget.reward!.id!);

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
          SnackBar(content: Text('Error deleting reward: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.reward != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Reward' : 'New Reward'),
        actions:
            isEditing
                ? [
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: _deleteReward,
                    tooltip: 'Delete Reward',
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
                        'Reward Type',
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _pointsController,
                        decoration: const InputDecoration(
                          labelText: 'Points Cost',
                          border: OutlineInputBorder(),
                          helperText: 'Points required to redeem this reward',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter points';
                          }
                          try {
                            final points = double.parse(value);
                            if (points <= 0) {
                              return 'Points must be greater than 0';
                            }
                          } catch (e) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saveReward,
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
                            isEditing ? 'Update Reward' : 'Save Reward',
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
