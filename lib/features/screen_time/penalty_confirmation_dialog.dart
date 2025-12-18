import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../model/daily_screen_usage.dart';
import '../../model/screen_time_rule.dart';
import '../../provider/screen_time_provider.dart';
import '../../provider/points_provider.dart';
import '../../services/screen_time_calculation_service.dart';

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
      title: Text('Penalità ${widget.rule.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Data: ${widget.usage.date}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tempo utilizzato: ${widget.usage.totalUsageMinutes} minuti',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Limite: ${widget.rule.dailyTimeLimitMinutes} minuti',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Minuti superati: $exceededMinutes',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Penalità calcolata: ${penalty.toStringAsFixed(2)} punti',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Vuoi applicare questa penalità al tuo punteggio?',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isApplying ? null : () => _onSkip(context),
          child: const Text('Salta'),
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
                  : const Text('Applica Penalità'),
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

      // Applica la penalità passando il points provider
      final success = await calculationService.applyPenaltyToPoints(
        pointsProvider,
        widget.usage,
      );

      if (success && mounted) {
        // Aggiorna la lista dei giorni non confermati
        await screenTimeProvider.checkForUnconfirmedDays();

        // Chiudi il dialog
        Navigator.of(context).pop(true);

        // Mostra messaggio di successo
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Penalità di ${widget.usage.calculatedPenalty.toStringAsFixed(2)} punti applicata!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nell\'applicazione della penalità'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  void _onSkip(BuildContext context) {
    // Chiudi il dialog senza applicare la penalità
    Navigator.of(context).pop(false);
  }
}
