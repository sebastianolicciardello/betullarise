import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../model/daily_screen_usage.dart';
import '../../provider/screen_time_provider.dart';
import 'penalty_confirmation_dialog.dart';
import 'widgets/rule_card.dart';
import 'widgets/loading_indicator.dart';

class ScreenTimePage extends StatefulWidget {
  const ScreenTimePage({super.key});

  @override
  State<ScreenTimePage> createState() => _ScreenTimePageState();
}

class _ScreenTimePageState extends State<ScreenTimePage> {
  @override
  void initState() {
    super.initState();
    // Esegui il controllo iniziale quando la pagina si apre
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialCheck();
    });
  }

  Future<void> _performInitialCheck() async {
    try {
      debugPrint('ScreenTimePage: Starting initial check...');
      final screenTimeProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );
      await screenTimeProvider.performInitialCheck();
      debugPrint('ScreenTimePage: Initial check completed');

      // Se ci sono giorni non confermati, mostra il primo dialog
      if (screenTimeProvider.unconfirmedDays.isNotEmpty && mounted) {
        debugPrint('ScreenTimePage: Showing penalty confirmation dialog');
        _showPenaltyConfirmationDialog(
          screenTimeProvider.unconfirmedDays.first,
        );
      } else {
        debugPrint('ScreenTimePage: No unconfirmed days');
      }
    } catch (e) {
      debugPrint('ScreenTimePage: Error in _performInitialCheck: $e');
      // Non mostrare dialog di errore per evitare loop
    }
  }

  void _showPenaltyConfirmationDialog(DailyScreenUsage usage) async {
    final screenTimeProvider = Provider.of<ScreenTimeProvider>(
      context,
      listen: false,
    );

    // Trova la regola corrispondente
    final rule = screenTimeProvider.getRuleById(usage.ruleId);
    if (rule == null) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Non permettere di chiudere toccando fuori
      builder: (context) => PenaltyConfirmationDialog(usage: usage, rule: rule),
    );

    // Se l'utente ha confermato o saltato, controlla se ci sono altri giorni
    if (result != null && mounted) {
      final updatedProvider = Provider.of<ScreenTimeProvider>(
        context,
        listen: false,
      );
      if (updatedProvider.unconfirmedDays.isNotEmpty) {
        // Mostra il prossimo giorno non confermato
        _showPenaltyConfirmationDialog(updatedProvider.unconfirmedDays.first);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ScreenTimeProvider>(
        builder: (context, screenTimeProvider, child) {
          if (screenTimeProvider.isLoading) {
            return const LoadingIndicator(
              message: 'Caricamento regole screen time...',
            );
          }

          if (!screenTimeProvider.hasPermission) {
            return _buildPermissionRequiredView(screenTimeProvider);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await screenTimeProvider.performInitialCheck();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lista delle regole attive
                  if (screenTimeProvider.rules.isEmpty)
                    _buildEmptyState(screenTimeProvider)
                  else
                    _buildRulesList(screenTimeProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(ScreenTimeProvider screenTimeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: Colors.orange),
            const SizedBox(height: 24),
            Text(
              'Permesso Richiesto',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Per utilizzare la funzionalità Screen Time, l\'app ha bisogno del permesso di accesso alle statistiche di utilizzo delle app.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Questo permesso è necessario per monitorare il tempo trascorso nelle applicazioni.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Come concedere il permesso'),
                      content: const Text(
                        'Per monitorare l\'uso delle app, devi concedere manualmente il permesso di accesso ai dati di utilizzo:\n\n'
                        '1. Apri Impostazioni del telefono\n'
                        '2. Vai su "App" o "Applicazioni"\n'
                        '3. Trova e seleziona "Betullarise"\n'
                        '4. Vai su "Permessi" o "Autorizzazioni"\n'
                        '5. Abilita "Accesso ai dati di utilizzo"\n\n'
                        'Dopo aver concesso il permesso, torna all\'app.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Annulla'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.of(context).pop(); // Chiudi dialog
                            // Ricontrolla i permessi
                            final screenTimeProvider =
                                Provider.of<ScreenTimeProvider>(
                                  context,
                                  listen: false,
                                );
                            final hasPermission =
                                await screenTimeProvider
                                    .checkUsageStatsPermission();
                            debugPrint(
                              'Permission check result: $hasPermission',
                            );

                            // Mostra feedback all'utente
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    hasPermission
                                        ? '✅ Permesso concesso! Ora puoi creare regole.'
                                        : '❌ Permesso non ancora concesso. Riprova dopo averlo abilitato.',
                                  ),
                                  backgroundColor:
                                      hasPermission ? Colors.green : Colors.red,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          },
                          child: const Text('Ho concesso il permesso'),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.info),
              label: const Text('Come concedere il permesso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesList(ScreenTimeProvider screenTimeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Regole Attive',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: screenTimeProvider.rules.length,
          itemBuilder: (context, index) {
            final rule = screenTimeProvider.rules[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RuleCard(rule: rule),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPermissionRequiredView(ScreenTimeProvider screenTimeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              'Permesso Richiesto',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Per monitorare l\'uso delle app, l\'app ha bisogno del permesso di accesso alle statistiche di utilizzo.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await screenTimeProvider.requestUsageStatsPermission();
              },
              child: const Text('Richiedi Permesso'),
            ),
          ],
        ),
      ),
    );
  }
}
