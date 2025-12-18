import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../provider/screen_time_provider.dart';

class DailyUsageSummary extends StatelessWidget {
  const DailyUsageSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ScreenTimeProvider>(
      builder: (context, screenTimeProvider, child) {
        if (screenTimeProvider.isLoading) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.today,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Oggi',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSummaryRow(
                  context,
                  'Regole attive',
                  '${screenTimeProvider.rules.where((rule) => rule.isActive).length}',
                  Icons.rule,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  context,
                  'Giorni non confermati',
                  '${screenTimeProvider.unconfirmedDays.length}',
                  Icons.pending_actions,
                  color:
                      screenTimeProvider.unconfirmedDays.isNotEmpty
                          ? Colors.orange
                          : Colors.green,
                ),
                const SizedBox(height: 8),
                _buildSummaryRow(
                  context,
                  'Permesso statistiche',
                  screenTimeProvider.hasPermission ? 'Concesso' : 'Negato',
                  screenTimeProvider.hasPermission
                      ? Icons.check_circle
                      : Icons.error,
                  color:
                      screenTimeProvider.hasPermission
                          ? Colors.green
                          : Colors.red,
                ),
                if (screenTimeProvider.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            screenTimeProvider.errorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: color ?? Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
