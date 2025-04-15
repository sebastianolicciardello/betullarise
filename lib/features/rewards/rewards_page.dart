import 'package:flutter/material.dart';
import 'package:betullarise/database/rewards_database_helper.dart';
import 'package:betullarise/features/rewards/rewards_detail_page.dart';
import 'package:betullarise/model/reward.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:provider/provider.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final RewardsDatabaseHelper _dbHelper = RewardsDatabaseHelper.instance;
  List<Reward> _rewards = [];
  bool _isLoading = true;
  double _currentPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() {
      _isLoading = true;
    });

    final rewards = await _dbHelper.getAllRewards();

    // Sort rewards by title
    rewards.sort((a, b) => a.title.compareTo(b.title));

    setState(() {
      _rewards = rewards;
      _isLoading = false;
    });
  }

  void _showEditPointsDialog() {
    final TextEditingController pointsController = TextEditingController(
      text: _currentPoints.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modify Points'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current points: ${_currentPoints.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(
                  labelText: 'New Points Value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newPointsText = pointsController.text.trim();
                final newPoints = double.tryParse(newPointsText);

                if (newPoints == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid number'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Close the first dialog
                Navigator.pop(context);

                // Show confirmation dialog
                _showConfirmPointsChangeDialog(newPoints);
              },
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Next'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmPointsChangeDialog(double newPoints) {
    final double difference = newPoints - _currentPoints;
    final String changeText =
        difference >= 0
            ? '+${difference.toStringAsFixed(1)}'
            : difference.toStringAsFixed(1);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Points Change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Current points: ${_currentPoints.toStringAsFixed(1)}'),
              Text(
                'New points: ${newPoints.toStringAsFixed(1)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Change: $changeText points',
                style: TextStyle(
                  color:
                      difference >= 0
                          ? Theme.of(context).primaryColor
                          : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Are you sure you want to change the points?'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                _updatePointsValue(difference);
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  void _updatePointsValue(double pointsDifference) {
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);

    // Creazione dell'entry per la modifica manuale dei punti
    final point = Point(
      referenceId:
          0, // Usato 0 come riferimento speciale per la modifica manuale
      type: 'manual_adjustment',
      points: pointsDifference,
      insertTime: DateTime.now().millisecondsSinceEpoch,
    );

    // Salva l'entry
    pointsProvider.savePoints(point);

    final changeText =
        pointsDifference >= 0
            ? '+${pointsDifference.toStringAsFixed(1)}'
            : pointsDifference.toStringAsFixed(1);

    // Mostra uno SnackBar con l'azione UNDO per annullare la modifica
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Points updated! $changeText points'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(
          seconds: 4,
        ), // Durata estesa per poter premere UNDO
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.red,
          onPressed: () {
            // Rimuove l'entry dei punti salvata per annullare la modifica
            pointsProvider.removePointsByEntity(point);

            // Mostra conferma dell'annullamento
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Manual point modification undone. ${pointsDifference >= 0 ? '-' : '+'}${pointsDifference.toStringAsFixed(1)} points',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<PointsProvider>(
        builder: (context, pointsProvider, child) {
          _currentPoints = pointsProvider.totalPoints;

          return _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  // Points Display and Manual Edit Button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showEditPointsDialog,
                          icon: const Icon(Icons.edit),
                          label: const Text('Modify Points'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.surface,
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider between points section and rewards list
                  const Divider(height: 1),

                  // Rewards List
                  Expanded(
                    child:
                        _rewards.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.card_giftcard,
                                    size: 64,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No rewards created',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                ],
                              ),
                            )
                            : RefreshIndicator(
                              onRefresh: _loadRewards,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _rewards.length,
                                itemBuilder: (context, index) {
                                  return _buildRewardCard(_rewards[index]);
                                },
                              ),
                            ),
                  ),
                ],
              );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RewardDetailPage()),
          );
          if (result == true) {
            _loadRewards();
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

  Widget _buildRewardCard(Reward reward) {
    IconData typeIcon;

    if (reward.type == 'single') {
      typeIcon = Icons.redeem;
    } else if (reward.type == 'multipler') {
      typeIcon = Icons.dashboard_customize;
    } else {
      typeIcon = Icons.card_giftcard;
    }

    final bool canAfford = _currentPoints >= reward.points;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color:
              canAfford ? Theme.of(context).colorScheme.primary : Colors.grey,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RewardDetailPage(reward: reward),
            ),
          );
          if (result == true) {
            _loadRewards();
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
                      reward.title,
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
                reward.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cost: ${reward.points.toStringAsFixed(1)} points',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: canAfford ? Colors.green : Colors.red,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      _showRedeemRewardDialog(reward);
                    },
                    style: ElevatedButton.styleFrom(
                      side: BorderSide(
                        color:
                            canAfford
                                ? Theme.of(context).colorScheme.primary
                                : Colors.red,
                      ),
                      backgroundColor:
                          canAfford
                              ? Theme.of(context).colorScheme.surface
                              : Colors.grey,
                    ),
                    child: const Text('Redeem'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRedeemRewardDialog(Reward reward) {
    if (reward.type == 'single') {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          final bool canAfford = _currentPoints >= reward.points;
          return AlertDialog(
            title: Text('Redeem "${reward.title}"?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This will deduct ${reward.points.toStringAsFixed(1)} points from your balance.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Current balance: ${_currentPoints.toStringAsFixed(1)} points',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'New balance: ${(_currentPoints - reward.points).toStringAsFixed(1)} points',
                  style: TextStyle(
                    color:
                        canAfford
                            ? Theme.of(context).colorScheme.primary
                            : Colors.red,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _redeemPoints(reward.id!, reward.points);
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Confirm Redeem'),
              ),
            ],
          );
        },
      );
    } else if (reward.type == 'multipler') {
      _showMultiplerRedemptionDialog(reward);
    }
  }

  void _showMultiplerRedemptionDialog(Reward reward) {
    final TextEditingController multiplerController = TextEditingController(
      text: '1',
    );

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final double multiplier =
                double.tryParse(multiplerController.text) ?? 1;
            final double totalPoints = multiplier * reward.points;
            final bool canAfford = _currentPoints >= totalPoints;

            return AlertDialog(
              title: Text('Redeem "${reward.title}"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: multiplerController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cost: ${totalPoints.toStringAsFixed(1)} points',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          canAfford
                              ? Theme.of(context).colorScheme.primary
                              : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Current balance: ${_currentPoints.toStringAsFixed(1)} points',
                  ),
                  Text(
                    'New balance: ${(_currentPoints - totalPoints).toStringAsFixed(1)} points',
                    style: TextStyle(
                      color:
                          canAfford
                              ? Theme.of(context).colorScheme.primary
                              : Colors.red,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    _redeemPoints(reward.id!, totalPoints);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor:
                        canAfford
                            ? Theme.of(context).colorScheme.surface
                            : Colors.grey,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Confirm Redeem'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _redeemPoints(int rewardId, double points) {
    final pointsProvider = Provider.of<PointsProvider>(context, listen: false);

    // Create a negative points entry to reduce total points
    final point = Point(
      referenceId: rewardId,
      type: 'reward',
      points: -points, // Negative points since we're redeeming
      insertTime: DateTime.now().millisecondsSinceEpoch,
    );

    // Save the points
    pointsProvider.savePoints(point);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Reward redeemed! -${points.toStringAsFixed(1)} points'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(
          seconds: 4,
        ), // Extended duration for undo action
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.red,
          onPressed: () {
            // Remove the points entry
            pointsProvider.removePointsByEntity(point);

            // Show confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Reward redemption undone. +${points.toStringAsFixed(1)} points',
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
