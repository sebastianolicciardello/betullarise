import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:betullarise/database/rewards_database_helper.dart';
import 'package:betullarise/features/rewards/rewards_detail_page.dart';
import 'package:betullarise/model/reward.dart';
import 'package:betullarise/provider/points_provider.dart';
import 'package:betullarise/model/point.dart';
import 'package:provider/provider.dart';
import 'package:betullarise/services/ui/dialog_service.dart';
import 'package:betullarise/services/ui/snackbar_service.dart';
import 'dart:ui' as ui;

class RewardsPage extends StatefulWidget {
  final IRewardsDatabaseHelper? dbHelper;
  const RewardsPage({super.key, this.dbHelper});

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late final IRewardsDatabaseHelper _dbHelper;
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
    _dbHelper = widget.dbHelper ?? RewardsDatabaseHelper.instance;
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
    SnackbarService.showSnackbar(
      context,
      'Points updated! $changeText points',
      duration: const Duration(seconds: 4),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      action: SnackBarAction(
        label: 'UNDO',
        textColor: Colors.red,
        onPressed: () {
          // Rimuove l'entry dei punti salvata per annullare la modifica
          pointsProvider.removePointsByEntity(point);

          // Mostra conferma dell'annullamento
          SnackbarService.showSnackbar(
            context,
            'Manual point modification undone. ${pointsDifference >= 0 ? '-' : '+'}${pointsDifference.toStringAsFixed(1)} points',
            duration: const Duration(seconds: 2),
          );
        },
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
                  padding: EdgeInsets.only(top: 16.h, bottom: 80.h),
                  children: [
                    // Points Display and Manual Edit Button
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _showEditPointsDialog,
                            icon: Icon(Icons.edit, size: 18.sp),
                            label: Text('Modify Points', style: TextStyle(fontSize: 14.sp)),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search rewards...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                        ),
                      ),
                    ),

                    // Rewards List
                    if (_filteredRewards.isEmpty && _isSearching) ...[
                      SizedBox(height: 64.h),
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
                              'No rewards found for "${_searchController.text}"',
                              style: TextStyle(fontSize: 18.sp),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_rewards.isEmpty) ...[
                      SizedBox(height: 64.h),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              size: 64.sp,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'No rewards created',
                              style: TextStyle(fontSize: 18.sp),
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
        child: Icon(Icons.add, size: 24.sp),
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
    final bool hasDescription = reward.description.trim().isNotEmpty;
    const int maxDescriptionLines = 2;
    const double minCardHeight = 56;
    const double normalCardHeight = 120;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.r),
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
                    child: Text(
                      reward.title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
                        final span = TextSpan(
                          text: reward.description,
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
                              reward.description,
                              maxLines: maxDescriptionLines,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 14.sp),
                            ),
                            if (isOverflowing)
                              Padding(
                                padding: EdgeInsets.only(top: 2.h),
                                child: Icon(
                                  Icons.more_horiz,
                                  size: 18.sp,
                                  color: Colors.grey,
                                ),
                              ),
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
                    child: Text('Redeem', style: TextStyle(fontSize: 14.sp)),
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

    SnackbarService.showSnackbar(
      context,
      'Reward redeemed! -${points.toStringAsFixed(1)} points',
      duration: const Duration(seconds: 4),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      action: SnackBarAction(
        label: 'UNDO',
        textColor: Colors.red,
        onPressed: () {
          // Remove the points entry
          pointsProvider.removePointsByEntity(point);

          // Show confirmation
          SnackbarService.showSnackbar(
            context,
            'Reward redemption undone. +${points.toStringAsFixed(1)} points',
            duration: const Duration(seconds: 2),
          );
        },
      ),
    );
  }
}
