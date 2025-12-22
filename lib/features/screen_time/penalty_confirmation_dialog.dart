import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/daily_screen_usage.dart';
import '../../model/screen_time_rule.dart';
import '../../provider/screen_time_provider.dart';
import '../../provider/points_provider.dart';
import '../../services/screen_time_calculation_service.dart';
import '../../services/ui/snackbar_service.dart';

class PenaltyConfirmationDialog extends StatefulWidget {
  final DailyScreenUsage usage;
  final ScreenTimeRule rule;

  const PenaltyConfirmationDialog({
    super.key,
    required this.usage,
    required this.rule,
  });

  @override
  State<PenaltyConfirmationDialog> createState() =>
      _PenaltyConfirmationDialogState();
}

class _PenaltyConfirmationDialogState extends State<PenaltyConfirmationDialog> {
  bool _isApplying = false;

  @override
  Widget build(BuildContext context) {
    final exceededMinutes = widget.usage.exceededMinutes;
    final penalty = widget.usage.calculatedPenalty;

    return AlertDialog(
      title: Text('Penalty for ${widget.rule.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Date: ${widget.usage.date}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Time used: ${widget.usage.totalUsageMinutes} minutes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Limit: ${widget.rule.dailyTimeLimitMinutes} minutes',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Minutes exceeded: $exceededMinutes',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Calculated penalty: ${penalty.toStringAsFixed(2)} points',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Do you want to apply this penalty to your score?',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isApplying ? null : () => _onSkip(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          onPressed: _isApplying ? null : () => _onApply(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child:
              _isApplying
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Text('Apply Penalty'),
        ),
      ],
    );
  }

  Future<void> _onApply(BuildContext context) async {
    setState(() => _isApplying = true);

    try {
      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );
      final pointsProvider = Provider.of<PointsProvider>(
        context,
        listen: false,
      );
      final calculationService = ScreenTimeCalculationService();

      // Apply the penalty passing the points provider
      final success = await calculationService.applyPenaltyToPoints(
        pointsProvider,
        widget.usage,
      );

      if (success) {
        // Update the list of unconfirmed days
        await screenTimeProvider.checkForUnconfirmedDays();

        if (context.mounted) {
          // Close the dialog
          Navigator.of(context).pop(true);

          // Show success message
          SnackbarService.showSuccessSnackbar(
            context,
            'Penalty of ${widget.usage.calculatedPenalty.toStringAsFixed(2)} points applied!',
          );
        }
      } else if (context.mounted) {
        SnackbarService.showErrorSnackbar(
          context,
          'Error applying the penalty',
        );
      }
    } catch (e) {
      if (context.mounted) {
        SnackbarService.showErrorSnackbar(context, 'Error: $e');
      }
    } finally {
      if (context.mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  void _onSkip(BuildContext context) {
    // Close the dialog without applying the penalty
    Navigator.of(context).pop(false);
  }
}
