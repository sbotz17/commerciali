import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/cliente.dart';
import '../../data/models/preventivo.dart';
import '../../state/azienda_providers.dart';
import '../catalogo/catalogo_screen.dart' show formattaPrezzo;
import '../preventivi/preventivi_screen.dart'
    show
        BadgeStatoPreventivo,
        clienteVisualizzatoPreventivo,
        numeroVisualizzatoPreventivo;

// ---------------------------------------------------------------------------
// Funzioni pure: conteggi, valore aperto e ultimi preventivi (verificabili
// senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Conteggi della dashboard per l'azienda attiva.
class StatisticheDashboard {
  const StatisticheDashboard({
    required this.totalePreventivi,
    required this.bozze,
    required this.inviati,
    required this.accettati,
    required this.rifiutati,
    required this.valoreAperto,
  });

  /// Numero complessivo dei preventivi, tutti gli stati compresi.
  final int totalePreventivi;

  final int bozze;
  final int inviati;
  final int accettati;
  final int rifiutati;

  /// Somma di `totaleIva` dei preventivi ancora aperti (bozze + inviati).
  final double valoreAperto;
}

/// Calcola i conteggi per stato e il valore aperto dei [preventivi].
///
/// Gli stati sono confrontati in minuscolo e senza spazi, così dati scritti
/// a mano (`Bozza`, ` inviato `) restano coerenti. Gli stati sconosciuti
/// entrano solo nel totale, mai nel valore aperto.
StatisticheDashboard calcolaStatistiche(List<Preventivo> preventivi) {
  var bozze = 0;
  var inviati = 0;
  var accettati = 0;
  var rifiutati = 0;
  var valoreAperto = 0.0;

  for (final preventivo in preventivi) {
    final stato = preventivo.stato.trim().toLowerCase();
    switch (stato) {
      case 'bozza':
        bozze++;
        valoreAperto += preventivo.totaleIva.toDouble();
      case 'inviato':
        inviati++;
        valoreAperto += preventivo.totaleIva.toDouble();
      case 'accettato':
        accettati++;
      case 'rifiutato':
        rifiutati++;
    }
  }

  return StatisticheDashboard(
    totalePreventivi: preventivi.length,
    bozze: bozze,
    inviati: inviati,
    accettati: accettati,
    rifiutati: rifiutati,
    valoreAperto: valoreAperto,
  );
}

/// I [quanti] preventivi più recenti, ordinati per `created_at` discendente.
///
/// L'ordinamento è ripetuto in memoria (come fa `SpService.getPreventivi`)
/// così la funzione resta verificabile e indipendente dall'ordine ricevuto.
List<Preventivo> ultimiPreventivi(
  List<Preventivo> preventivi, {
  int quanti = 5,
}) {
  final ordinati = [...preventivi]
    ..sort((a, b) => (b.createdAt ?? '').compareTo(a.createdAt ?? ''));
  return ordinati.take(quanti).toList();
}

/// Testo del numero di clienti in anagrafica (singolare/plurale).
String testoNumeroClienti(int numero) {
  if (numero == 1) return '1 cliente in anagrafica';
  return '$numero clienti in anagrafica';
}

/// Messaggio in italiano per gli errori di caricamento della dashboard.
String messaggioErroreDashboard(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per vedere la dashboard. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Operazione non riuscita. Riprova.';
    }
  }
  return 'Operazione non riuscita. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Dashboard dell'azienda attiva: conteggi dei preventivi, valore aperto,
/// ultimi cinque preventivi e azioni rapide.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  List<Preventivo> _preventivi = const [];
  int _numeroClienti = 0;
  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _caricaDashboard();
  }

  /// Passa l'azienda attiva al servizio e carica preventivi e clienti.
  Future<void> _caricaDashboard() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final risultati = await Future.wait<Object>([
        servizio.getPreventivi(),
        servizio.getClienti(),
      ]);
      if (!mounted) return;
      setState(() {
        _preventivi = risultati[0] as List<Preventivo>;
        _numeroClienti = (risultati[1] as List<Cliente>).length;
        _caricamento = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = errore;
        _caricamento = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _caricaDashboard();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;

        return CorpoDashboard(
          preventivi: _preventivi,
          statistiche: calcolaStatistiche(_preventivi),
          numeroClienti: _numeroClienti,
          caricamento: _caricamento,
          errore: _errore,
          largo: largo,
          onRiprova: _caricaDashboard,
          onNuovoPreventivo: () => context.go('/preventivi/nuovo'),
          onNuovoCliente: () => context.go('/clienti'),
          onBandi: () => context.go('/bandi'),
          onCatalogo: () => context.go('/catalogo'),
          onApriPreventivo: (preventivo) =>
              context.go('/preventivi/${preventivo.id}'),
        );
      },
    );
  }
}

/// Corpo della dashboard: stati caricamento/errore e contenuto responsive.
///
/// È pubblico e senza provider per poter essere verificato con un widget test
/// senza Firebase.
class CorpoDashboard extends StatelessWidget {
  const CorpoDashboard({
    super.key,
    required this.preventivi,
    required this.statistiche,
    required this.numeroClienti,
    required this.caricamento,
    required this.onRiprova,
    required this.onNuovoPreventivo,
    required this.onNuovoCliente,
    required this.onBandi,
    required this.onCatalogo,
    this.errore,
    this.largo = false,
    this.onApriPreventivo,
  });

  final List<Preventivo> preventivi;
  final StatisticheDashboard statistiche;
  final int numeroClienti;
  final bool caricamento;
  final Object? errore;
  final bool largo;
  final VoidCallback onRiprova;
  final VoidCallback onNuovoPreventivo;
  final VoidCallback onNuovoCliente;
  final VoidCallback onBandi;
  final VoidCallback onCatalogo;
  final ValueChanged<Preventivo>? onApriPreventivo;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('dashboard-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Dashboard non disponibile',
        sottotitolo: messaggioErroreDashboard(errore!),
        azione: OutlinedButton.icon(
          key: const Key('dashboard-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final orizzontale = largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

    return SingleChildScrollView(
      padding: EdgeInsets.all(orizzontale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _GrigliaStatistiche(statistiche: statistiche, largo: largo),
          const SizedBox(height: AppSpazi.gapCard),
          _SezioneUltimiPreventivi(
            preventivi: ultimiPreventivi(preventivi),
            largo: largo,
            onNuovoPreventivo: onNuovoPreventivo,
            onApriPreventivo: onApriPreventivo,
          ),
          const SizedBox(height: AppSpazi.gapCard),
          _AzioniRapide(
            numeroClienti: numeroClienti,
            largo: largo,
            onNuovoPreventivo: onNuovoPreventivo,
            onNuovoCliente: onNuovoCliente,
            onBandi: onBandi,
            onCatalogo: onCatalogo,
          ),
        ],
      ),
    );
  }
}

/// Scheda di una statistica: icona, valore e etichetta.
class _VoceStatistica {
  const _VoceStatistica({
    required this.chiave,
    required this.etichetta,
    required this.valore,
    required this.icona,
    required this.colore,
  });

  final String chiave;
  final String etichetta;
  final String valore;
  final IconData icona;
  final Color colore;
}

/// Griglia delle statistiche: 2 colonne su telefono, 4 da 600 px in su.
class _GrigliaStatistiche extends StatelessWidget {
  const _GrigliaStatistiche({required this.statistiche, required this.largo});

  final StatisticheDashboard statistiche;
  final bool largo;

  @override
  Widget build(BuildContext context) {
    final voci = <_VoceStatistica>[
      _VoceStatistica(
        chiave: 'totale',
        etichetta: 'Totale preventivi',
        valore: '${statistiche.totalePreventivi}',
        icona: Icons.description_outlined,
        colore: AppColors.primario,
      ),
      _VoceStatistica(
        chiave: 'bozze',
        etichetta: 'Bozze',
        valore: '${statistiche.bozze}',
        icona: Icons.edit_note_outlined,
        colore: const Color(0xFF64748B),
      ),
      _VoceStatistica(
        chiave: 'inviati',
        etichetta: 'Inviati',
        valore: '${statistiche.inviati}',
        icona: Icons.send_outlined,
        colore: AppColors.primario,
      ),
      _VoceStatistica(
        chiave: 'accettati',
        etichetta: 'Accettati',
        valore: '${statistiche.accettati}',
        icona: Icons.check_circle_outline,
        colore: AppColors.accettato,
      ),
      _VoceStatistica(
        chiave: 'rifiutati',
        etichetta: 'Rifiutati',
        valore: '${statistiche.rifiutati}',
        icona: Icons.cancel_outlined,
        colore: AppColors.errore,
      ),
      _VoceStatistica(
        chiave: 'valore-aperto',
        etichetta: 'Valore aperto',
        valore: formattaPrezzo(statistiche.valoreAperto),
        icona: Icons.euro_outlined,
        colore: AppColors.attesa,
      ),
    ];

    return GridView.builder(
      key: const Key('dashboard-statistiche'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: voci.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: largo ? 4 : 2,
        crossAxisSpacing: AppSpazi.s,
        mainAxisSpacing: AppSpazi.s,
        mainAxisExtent: 104,
      ),
      itemBuilder: (context, indice) => _SchedaStatistica(voce: voci[indice]),
    );
  }
}

/// Singola card statistica.
class _SchedaStatistica extends StatelessWidget {
  const _SchedaStatistica({required this.voce});

  final _VoceStatistica voce;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: Key('dashboard-stat-${voce.chiave}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(voce.icona, size: 20, color: voce.colore),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    voce.valore,
                    maxLines: 1,
                    style: tema.textTheme.titleLarge,
                  ),
                ),
                Text(
                  voce.etichetta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Ultimi cinque preventivi con numero, cliente, stato e totale.
class _SezioneUltimiPreventivi extends StatelessWidget {
  const _SezioneUltimiPreventivi({
    required this.preventivi,
    required this.largo,
    required this.onNuovoPreventivo,
    this.onApriPreventivo,
  });

  final List<Preventivo> preventivi;
  final bool largo;
  final VoidCallback onNuovoPreventivo;
  final ValueChanged<Preventivo>? onApriPreventivo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: const Key('dashboard-ultimi-preventivi'),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpazi.m,
              AppSpazi.m,
              AppSpazi.m,
              AppSpazi.xs,
            ),
            child: Text('Ultimi 5 preventivi', style: tema.textTheme.titleMedium),
          ),
          if (preventivi.isEmpty)
            SizedBox(
              height: 260,
              child: StatoCentrato(
                icona: Icons.description_outlined,
                titolo: 'Nessun preventivo',
                sottotitolo:
                    'Crea il primo preventivo per vederlo comparire qui.',
                azione: FilledButton.icon(
                  key: const Key('dashboard-nuovo-preventivo-vuoto'),
                  onPressed: onNuovoPreventivo,
                  icon: const Icon(Icons.note_add_outlined),
                  label: const Text('Nuovo preventivo'),
                ),
              ),
            )
          else ...[
            if (largo) _IntestazioneTabella(),
            for (final preventivo in preventivi)
              _RigaPreventivoDashboard(
                preventivo: preventivo,
                largo: largo,
                onTap: onApriPreventivo == null
                    ? null
                    : () => onApriPreventivo!(preventivo),
              ),
          ],
          const SizedBox(height: AppSpazi.xs),
        ],
      ),
    );
  }
}

/// Intestazione delle quattro colonne su desktop.
class _IntestazioneTabella extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final stile = tema.textTheme.labelSmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpazi.m,
        vertical: AppSpazi.xs,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('Numero', style: stile)),
          Expanded(flex: 3, child: Text('Cliente', style: stile)),
          Expanded(flex: 2, child: Text('Stato', style: stile)),
          Expanded(
            flex: 2,
            child: Text('Totale', style: stile, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// Riga di un preventivo: card su telefono, riga tabellare su desktop.
class _RigaPreventivoDashboard extends StatelessWidget {
  const _RigaPreventivoDashboard({
    required this.preventivo,
    required this.largo,
    this.onTap,
  });

  final Preventivo preventivo;
  final bool largo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return InkWell(
      key: ValueKey('dashboard-preventivo-${preventivo.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpazi.m,
          vertical: AppSpazi.xs,
        ),
        child: largo
            ? Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      numeroVisualizzatoPreventivo(preventivo),
                      style: tema.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      clienteVisualizzatoPreventivo(preventivo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BadgeStatoPreventivo(stato: preventivo.stato),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      formattaPrezzo(preventivo.totaleIva),
                      textAlign: TextAlign.right,
                      style: tema.textTheme.titleSmall,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          numeroVisualizzatoPreventivo(preventivo),
                          style: tema.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpazi.xxs),
                        Text(
                          clienteVisualizzatoPreventivo(preventivo),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpazi.s),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BadgeStatoPreventivo(stato: preventivo.stato),
                      const SizedBox(height: AppSpazi.xxs),
                      Text(
                        formattaPrezzo(preventivo.totaleIva),
                        style: tema.textTheme.titleSmall,
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

/// Azioni rapide: le quattro destinazioni principali della dashboard.
class _AzioniRapide extends StatelessWidget {
  const _AzioniRapide({
    required this.numeroClienti,
    required this.largo,
    required this.onNuovoPreventivo,
    required this.onNuovoCliente,
    required this.onBandi,
    required this.onCatalogo,
  });

  final int numeroClienti;
  final bool largo;
  final VoidCallback onNuovoPreventivo;
  final VoidCallback onNuovoCliente;
  final VoidCallback onBandi;
  final VoidCallback onCatalogo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final azioni = <_AzioneRapida>[
      _AzioneRapida(
        chiave: 'nuovo-preventivo',
        etichetta: 'Nuovo preventivo',
        icona: Icons.note_add_outlined,
        onTap: onNuovoPreventivo,
      ),
      _AzioneRapida(
        chiave: 'nuovo-cliente',
        etichetta: 'Nuovo cliente',
        icona: Icons.person_add_alt_1_outlined,
        onTap: onNuovoCliente,
      ),
      _AzioneRapida(
        chiave: 'bandi',
        etichetta: 'Bandi',
        icona: Icons.campaign_outlined,
        onTap: onBandi,
      ),
      _AzioneRapida(
        chiave: 'catalogo',
        etichetta: 'Catalogo',
        icona: Icons.inventory_2_outlined,
        onTap: onCatalogo,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Azioni rapide', style: tema.textTheme.titleMedium),
        const SizedBox(height: AppSpazi.xxs),
        Text(
          testoNumeroClienti(numeroClienti),
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpazi.s),
        GridView.builder(
          key: const Key('dashboard-azioni-rapide'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: azioni.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: largo ? 4 : 2,
            crossAxisSpacing: AppSpazi.s,
            mainAxisSpacing: AppSpazi.s,
            mainAxisExtent: 88,
          ),
          itemBuilder: (context, indice) {
            final azione = azioni[indice];
            return Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: Key('dashboard-azione-${azione.chiave}'),
                onTap: azione.onTap,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpazi.xs),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(azione.icona, color: AppColors.primario),
                      const SizedBox(height: AppSpazi.xxs),
                      Text(
                        azione.etichetta,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Dati di una azione rapida.
class _AzioneRapida {
  const _AzioneRapida({
    required this.chiave,
    required this.etichetta,
    required this.icona,
    required this.onTap,
  });

  final String chiave;
  final String etichetta;
  final IconData icona;
  final VoidCallback onTap;
}
