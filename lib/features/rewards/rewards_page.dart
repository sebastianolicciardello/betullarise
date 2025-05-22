import 'package:flutter/material.dart';
import 'package:betullarise/database/rewards_database_helper.dart';
import 'package:betullarise/features/rewards/rewards_detail_page.dart';
import 'package:betullarise/model/reward.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/services/ui/dialog_service.dart';

class RewardsPage extends StatefulWidget {
  const RewardsPage({super.key});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final RewardsDatabaseHelper _dbHelper = RewardsDatabaseHelper.instance;
  final DialogService _dialogService = DialogService();
  List<Reward> _rewards = [];
  List<Reward> _filteredRewards = [];
  bool _isLoading = true;
  bool _isSearching = false;
  double _currentPoints = 0;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadRewards();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _filterRewards(_searchController.text);
  }

  void _filterRewards(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredRewards = List.from(_rewards);
        _isSearching = false;
      });
      return;
    }

    final lowerCaseQuery = query.toLowerCase();
    final filtered =
        _rewards.where((reward) {
          return reward.title.toLowerCase().contains(lowerCaseQuery) ||
              reward.description.toLowerCase().contains(lowerCaseQuery);
        }).toList();

    setState(() {
      _filteredRewards = filtered;
      _isSearching = true;
    });
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
      _filteredRewards = List.from(rewards);
      _isLoading = false;
    });
  }

  Future<void> _showEditPointsDialog() async {
    final String? result = await _dialogService.showInputDialog(
      context,
      'Modify Points',
      message: 'Current points: ${_currentPoints.toStringAsFixed(1)}',
      initialValue: _currentPoints.toStringAsFixed(1),
      labelText: 'New Points Value',
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a value';
        }
        final newPoints = double.tryParse(value);
        if (newPoints == null) {
          return 'Please enter a valid number';
        }
        return null;
      },
      confirmText: 'Next',
    );

    if (result != null) {
      final newPoints = double.tryParse(result);
      if (newPoints != null && context.mounted) {
        _showConfirmPointsChangeDialog(newPoints);
      }
    }
  }

  Future<void> _showConfirmPointsChangeDialog(double newPoints) async {
    final double difference = newPoints - _currentPoints;
    final String changeText =
        difference >= 0
            ? '+${difference.toStringAsFixed(1)}'
            : difference.toStringAsFixed(1);

    final message =
        'Current points: ${_currentPoints.toStringAsFixed(1)}\n'
        'New points: ${newPoints.toStringAsFixed(1)}\n\n'
        'Change: $changeText points\n\n'
        'Are you sure you want to change the points?';

    final bool? confirmed = await _dialogService.showConfirmDialog(
      context,
      'Confirm Points Change',
      message,
      confirmText: 'Confirm',
      confirmColor: Theme.of(context).colorScheme.primary,
    );

    if (confirmed == true && context.mounted) {
      _updatePointsValue(difference);
    }
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
              : RefreshIndicator(
                onRefresh: _loadRewards,
                child: ListView(
                  padding: const EdgeInsets.only(top: 16, bottom: 80),
                  children: [
                    // Points Display and Manual Edit Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
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

                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search rewards...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Rewards List
                    if (_filteredRewards.isEmpty && _isSearching) ...[
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
                              'No rewards found for "${_searchController.text}"',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_rewards.isEmpty) ...[
                      const SizedBox(height: 64),
                      Center(
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
                      ),
                    ] else ...[
                      ..._filteredRewards.map(_buildRewardCard),
                    ],
                  ],
                ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: canAfford ? Theme.of(context).colorScheme.primary : Colors.red,
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
                    'Cost: ${reward.points.toStringAsFixed(2)} points',
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
                      backgroundColor: Theme.of(context).colorScheme.surface,
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

  Future<void> _showRedeemRewardDialog(Reward reward) async {
    if (reward.type == 'single') {
      final bool canAfford = _currentPoints >= reward.points;
      final message =
          'This will deduct ${reward.points.toStringAsFixed(1)} points from your balance.\n\n'
          'Current balance: ${_currentPoints.toStringAsFixed(1)} points\n'
          'New balance: ${(_currentPoints - reward.points).toStringAsFixed(1)} points'
          '${!canAfford ? '\n\nWarning: This will put your points balance in negative.' : ''}';

      final bool? confirmed = await _dialogService.showConfirmDialog(
        context,
        'Redeem "${reward.title}"?',
        message,
        confirmText: 'Confirm Redeem',
        confirmColor:
            canAfford ? Theme.of(context).colorScheme.primary : Colors.red,
      );

      if (confirmed == true) {
        _redeemPoints(reward.id!, reward.points);
      }
    } else if (reward.type == 'multipler') {
      _showMultiplerRedemptionDialog(reward);
    }
  }

  Future<void> _showMultiplerRedemptionDialog(Reward reward) async {
    if (!mounted) return;

    final String? result = await _dialogService.showInputDialog(
      context,
      'Redeem "${reward.title}"',
      labelText: 'Quantity',
      message: 'Enter the quantity you want to redeem',
      initialValue: '1',
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a quantity';
        }
        final quantity = double.tryParse(value);
        if (quantity == null || quantity <= 0) {
          return 'Please enter a valid quantity';
        }
        return null;
      },
    );

    if (result != null && mounted) {
      final quantity = double.tryParse(result) ?? 1;
      final totalPoints = quantity * reward.points;
      final bool canAfford = _currentPoints >= totalPoints;

      final message =
          'Cost: ${totalPoints.toStringAsFixed(1)} points\n\n'
          'Current balance: ${_currentPoints.toStringAsFixed(1)} points\n'
          'New balance: ${(_currentPoints - totalPoints).toStringAsFixed(1)} points'
          '${!canAfford ? '\n\nWarning: This will put your points balance in negative.' : ''}';

      final bool? confirmed = await _dialogService.showConfirmDialog(
        context,
        'Confirm Redemption',
        message,
        confirmText: 'Confirm Redeem',
        confirmColor:
            canAfford ? Theme.of(context).colorScheme.primary : Colors.red,
      );

      if (confirmed == true) {
        _redeemPoints(reward.id!, totalPoints);
      }
    }
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
