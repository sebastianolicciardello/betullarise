import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../model/screen_time_rule.dart';
import '../../../model/daily_screen_usage.dart';
import '../../../services/screen_time_calculation_service.dart';
import '../../../database/daily_screen_usage_database_helper.dart';
import '../../../provider/points_provider.dart';
import '../../../provider/screen_time_provider.dart';

class RuleCard extends StatefulWidget {
  final ScreenTimeRule rule;
  final int? todayUsageMinutes; // Optional: current day's usage

  const RuleCard({super.key, required this.rule, this.todayUsageMinutes});

  @override
  State<RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<RuleCard> {
  double? _totalPenalty;
  List<DailyScreenUsage> _unconfirmedPenalties = [];
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadPenalties();
  }

  Future<void> _loadPenalties() async {
    if (widget.rule.id != null) {
      final calculationService = ScreenTimeCalculationService();
      final stats = await calculationService.getRuleStatistics(widget.rule.id!);
      final unconfirmed = await calculationService.getUnconfirmedDays();
      final unconfirmedForRule =
          unconfirmed.where((u) => u.ruleId == widget.rule.id).toList();

      if (mounted) {
        setState(() {
          _totalPenalty = stats['totalPenalty'];
          _unconfirmedPenalties = unconfirmedForRule;
        });
      }
    }
  }

  Future<void> _applyPenalty(DailyScreenUsage usage) async {
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
        await _loadPenalties();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Penalty applied: ${usage.calculatedPenalty.toStringAsFixed(2)} points',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error applying penalty: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<void> _skipPenalty(DailyScreenUsage usage) async {
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
        await _loadPenalties();
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
    return Card(
      elevation: 2,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!widget.rule.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(12),
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
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
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
            if (_unconfirmedPenalties.isNotEmpty) ...[
              for (final usage in _unconfirmedPenalties) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unconfirmed penalty: ${usage.date}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Exceeded: ${usage.exceededMinutes} min, Penalty: ${usage.calculatedPenalty.toStringAsFixed(2)} points',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.red[700]),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  _isApplying
                                      ? null
                                      : () => _applyPenalty(usage),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
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
                                      : () => _skipPenalty(usage),
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
            Row(
              children: [
                Icon(Icons.warning, size: 20, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _totalPenalty != null
                        ? 'Total penalties: ${_totalPenalty!.abs().toStringAsFixed(1)} points'
                        : 'Loading penalties...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.todayUsageMinutes != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 20,
                    color:
                        widget.todayUsageMinutes! >
                                widget.rule.dailyTimeLimitMinutes
                            ? Colors.red
                            : Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Today: ${widget.todayUsageMinutes!} minutes',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            widget.todayUsageMinutes! >
                                    widget.rule.dailyTimeLimitMinutes
                                ? Colors.red
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
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.todayUsageMinutes! > widget.rule.dailyTimeLimitMinutes
                      ? Colors.red
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
