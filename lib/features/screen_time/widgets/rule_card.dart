import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../model/screen_time_rule.dart';
import '../../../model/daily_screen_usage.dart';
import '../../../services/screen_time_calculation_service.dart';
import '../../../database/daily_screen_usage_database_helper.dart';
import '../../../provider/points_provider.dart';
import '../../../provider/screen_time_provider.dart';
import '../../../services/ui/snackbar_service.dart';

class RuleCard extends StatefulWidget {
  final ScreenTimeRule rule;
  final int? todayUsageMinutes; // Optional: current day's usage

  const RuleCard({super.key, required this.rule, this.todayUsageMinutes});

  @override
  State<RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<RuleCard> {
  double? _totalPenalty;
  bool _isApplying = false;
  Timer? _penaltyUpdateTimer;

  @override
  void initState() {
    super.initState();
    _loadStatistics();

    // Set up periodic updates every 10 minutes
    _penaltyUpdateTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (mounted) {
        _loadStatistics();
      }
    });
  }

  @override
  void didUpdateWidget(RuleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule != widget.rule) {
      _loadStatistics();
    }
  }

  @override
  void dispose() {
    _penaltyUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    if (widget.rule.id != null) {
      final calculationService = ScreenTimeCalculationService();
      final stats = await calculationService.getRuleStatistics(widget.rule.id!);

      if (mounted) {
        setState(() {
          _totalPenalty = stats['totalPenalty'];
        });
      }
    }
  }

  Future<void> _applyPenalty(
    BuildContext context,
    DailyScreenUsage usage,
  ) async {
    setState(() => _isApplying = true);
    try {
      final pointsProvider = Provider.of<PointsProvider>(
        context,
        listen: false,
      );
      final calculationService = ScreenTimeCalculationService();
      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );

      final success = await calculationService.applyPenaltyToPoints(
        pointsProvider,
        usage,
      );

      if (success && mounted) {
        await screenTimeProvider.checkForUnconfirmedDays();
        await _loadStatistics();
        if (mounted) {
          SnackbarService.showSuccessSnackbar(
            context,
            'Penalty applied: ${usage.calculatedPenalty.toStringAsFixed(2)} points',
          );
        }
      } else if (mounted) {
        SnackbarService.showErrorSnackbar(
          context,
          'Error applying the penalty',
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarService.showErrorSnackbar(context, 'Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _skipPenalty(
    BuildContext context,
    DailyScreenUsage usage,
  ) async {
    setState(() => _isApplying = true);
    try {
      final dbHelper = DailyScreenUsageDatabaseHelper.instance;
      await dbHelper.confirmPenalty(
        usage,
      ); // Mark as confirmed without applying points

      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );
      await screenTimeProvider.checkForUnconfirmedDays();

      if (mounted) {
        await _loadStatistics();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Penalty skipped, calculation enabled for today'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error skipping penalty: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ScreenTimeProvider>(
      builder: (context, screenTimeProvider, child) {
        final unconfirmedPenalties =
            screenTimeProvider.unconfirmedDays
                .where((u) => u.ruleId == widget.rule.id)
                .toList();

        // Check if penalty is confirmed for today
        final today = DateTime.now();
        final dateStr =
            '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final todayConfirmed = unconfirmedPenalties.any(
          (u) => u.date == dateStr && u.penaltyConfirmed,
        );

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.rule.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!widget.rule.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.zero,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        child: const Text(
                          'Disabled',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.rule.appPackages.length} app${widget.rule.appPackages.length != 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.rule.dailyTimeLimitMinutes} minutes per day',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (unconfirmedPenalties.isNotEmpty) ...[
                  for (final usage in unconfirmedPenalties) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Penalty: ${usage.calculatedPenalty.toStringAsFixed(2)} points (${usage.date})',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      _isApplying
                                          ? null
                                          : () => _applyPenalty(context, usage),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                    foregroundColor:
                                        Theme.of(context).colorScheme.onError,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child:
                                      _isApplying
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                          : const Text(
                                            'Apply Penalty',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      _isApplying
                                          ? null
                                          : () => _skipPenalty(context, usage),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.grey),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                  ),
                                  child: const Text(
                                    'Skip',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (todayConfirmed) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green.shade100,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'Completed for today',
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_totalPenalty != null &&
                    _totalPenalty! >= 0.05 &&
                    !todayConfirmed)
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 20,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Total penalties: ${_totalPenalty!.abs().toStringAsFixed(1)} points',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.error.withOpacity(0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (widget.todayUsageMinutes != null && !todayConfirmed) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 20,
                        color:
                            widget.todayUsageMinutes! >
                                    widget.rule.dailyTimeLimitMinutes
                                ? Theme.of(context).colorScheme.error
                                : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Today: ${widget.todayUsageMinutes!} minutes',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(
                            color:
                                widget.todayUsageMinutes! >
                                        widget.rule.dailyTimeLimitMinutes
                                    ? Theme.of(context).colorScheme.error
                                    : Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: (widget.todayUsageMinutes! /
                            widget.rule.dailyTimeLimitMinutes)
                        .clamp(0.0, 1.0),
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.todayUsageMinutes! >
                              widget.rule.dailyTimeLimitMinutes
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (widget.rule.appPackages.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children:
                        widget.rule.appPackages.take(3).map((package) {
                          return Chip(
                            label: Text(
                              _getAppNameFromPackage(package),
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor:
                                Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          );
                        }).toList(),
                  ),
                if (widget.rule.appPackages.length > 3)
                  Text(
                    '+${widget.rule.appPackages.length - 3} more',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getAppNameFromPackage(String package) {
    final packageMap = {
      'com.whatsapp': 'WhatsApp',
      'org.telegram.messenger': 'Telegram',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.google.android.youtube': 'YouTube',
      'com.spotify.music': 'Spotify',
      'com.twitter.android': 'Twitter',
      'com.tinder': 'Tinder',
      'com.netflix.mediaclient': 'Netflix',
      'com.google.android.gm': 'Gmail',
    };

    return packageMap[package] ?? package.split('.').last;
  }
}
