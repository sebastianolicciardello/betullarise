import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

          return RefreshIndicator(
            onRefresh: () async {
              await screenTimeProvider.performInitialCheck();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner di permesso se non concesso
                  if (!screenTimeProvider.hasPermission)
                    _buildPermissionBanner(screenTimeProvider),
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
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.rule, size: 80.sp, color: Colors.grey),
            SizedBox(height: 24.h),
            Text(
              'Nessuna Regola Creata',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Crea la tua prima regola per monitorare il tempo trascorso nelle app.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            if (!screenTimeProvider.hasPermission)
              Text(
                'Nota: concedi il permesso per abilitare il monitoraggio automatico.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            SizedBox(height: 32.h),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Naviga alla pagina di creazione regola
                // Per ora, mostra un messaggio
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Funzione di creazione regola non ancora implementata',
                    ),
                  ),
                );
              },
              icon: Icon(Icons.add, size: 20.sp),
              label: Text('Crea Regola', style: TextStyle(fontSize: 16.sp)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                textStyle: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(ScreenTimeProvider screenTimeProvider) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Theme.of(context).colorScheme.primary),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.grey.shade700, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'Permesso richiesto per monitorare l\'uso delle app. Concedi il permesso per abilitare le regole.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14.sp),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () {
              if (context.mounted) {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: Text(
                        'Come concedere il permesso',
                        style: TextStyle(fontSize: 18.sp),
                      ),
                      content: Text(
                        'Per monitorare l\'uso delle app, devi concedere manualmente il permesso di accesso ai dati di utilizzo:\n\n'
                        '1. Apri Impostazioni del telefono\n'
                        '2. Vai su "App" o "Applicazioni"\n'
                        '3. Trova e seleziona "Betullarise"\n'
                        '4. Vai su "Permessi" o "Autorizzazioni"\n'
                        '5. Abilita "Accesso ai dati di utilizzo"\n\n'
                        'Dopo aver aver concesso il permesso, torna all\'app e ricarica.',
                        style: TextStyle(fontSize: 14.sp),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'Annulla',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                          onPressed: () async {
                            // Prova ad aprire le impostazioni
                            try {
                              await screenTimeProvider
                                  .requestUsageStatsPermission();
                            } catch (e) {
                              debugPrint('Error opening settings: $e');
                            }
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                          child: Text(
                            'Apri Impostazioni',
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                      ],
                    );
                  },
                );
              }
            },
            child: Text('Concedi', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
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
        SizedBox(height: 12.h),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: screenTimeProvider.rules.length,
          itemBuilder: (context, index) {
            final rule = screenTimeProvider.rules[index];
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Card(
                margin: EdgeInsets.symmetric(horizontal: 0, vertical: 4.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                child: RuleCard(rule: rule),
              ),
            );
          },
        ),
      ],
    );
  }
}
