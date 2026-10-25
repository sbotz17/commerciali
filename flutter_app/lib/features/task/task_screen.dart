import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/task_item.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/sp_service.dart';
import '../../state/azienda_providers.dart';
import 'task_form_screen.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: filtri, raggruppamento, formati e messaggi (verificabili
// senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Titoli delle sezioni della lista, nell'ordine in cui vengono mostrate.
const List<String> periodiTask = [
  'In ritardo',
  'Oggi',
  'Questa settimana',
  'Più avanti',
  'Senza scadenza',
  'Completati',
];

/// Task visibili con i filtri della schermata.
///
/// [testo] cerca nel titolo senza distinzione tra maiuscole e minuscole,
/// [operatoreId] (se non vuoto) limita all'operatore assegnato e
/// [soloAperti] tiene solo i task con stato `aperto`. Il risultato è ordinato
/// per scadenza con [ordinaTask].
List<TaskItem> filtraTaskVisibili(
  List<TaskItem> task, {
  bool soloAperti = false,
  String operatoreId = '',
  String testo = '',
}) {
  final cerca = testo.trim().toLowerCase();
  final operatore = operatoreId.trim();

  final filtrati = task.where((t) {
    if (soloAperti && t.stato != 'aperto') return false;
    if (operatore.isNotEmpty && (t.operatoreId ?? '') != operatore) {
      return false;
    }
    if (cerca.isNotEmpty) {
      final titolo = (t.titolo ?? '').toLowerCase();
      if (!titolo.contains(cerca)) return false;
    }
    return true;
  }).toList();

  return ordinaTask(filtrati);
}

/// Raggruppa i task per periodo rispetto a [oggi] (default: adesso).
///
/// Le chiavi sono sempre tutte presenti, nell'ordine di [periodiTask], anche
/// quando la sezione è vuota. Regole:
/// - stato `completato` → solo `Completati`;
/// - data di scadenza assente o non valida → `Senza scadenza`;
/// - data prima di oggi → `In ritardo`;
/// - data di oggi → `Oggi`;
/// - data entro la domenica della settimana corrente → `Questa settimana`;
/// - data successiva → `Più avanti`.
///
/// Ogni gruppo è ordinato con [ordinaTask].
Map<String, List<TaskItem>> raggruppaTaskPerPeriodo(
  List<TaskItem> task, {
  DateTime? oggi,
}) {
  final riferimento = _soloGiorno(oggi ?? DateTime.now());
  final fineSettimana = riferimento.add(
    Duration(days: DateTime.daysPerWeek - riferimento.weekday),
  );

  final gruppi = <String, List<TaskItem>>{
    for (final periodo in periodiTask) periodo: <TaskItem>[],
  };

  for (final t in task) {
    if (t.stato == 'completato') {
      gruppi['Completati']!.add(t);
      continue;
    }
    final scadenza = _dataScadenza(t);
    if (scadenza == null) {
      gruppi['Senza scadenza']!.add(t);
    } else if (scadenza.isBefore(riferimento)) {
      gruppi['In ritardo']!.add(t);
    } else if (scadenza.isAtSameMomentAs(riferimento)) {
      gruppi['Oggi']!.add(t);
    } else if (!scadenza.isAfter(fineSettimana)) {
      gruppi['Questa settimana']!.add(t);
    } else {
      gruppi['Più avanti']!.add(t);
    }
  }

  return {
    for (final periodo in periodiTask) periodo: ordinaTask(gruppi[periodo]!),
  };
}

/// Scadenza leggibile in italiano (`gg/mm/aaaa`, con l'ora se presente).
String formattaScadenzaTask(TaskItem task) {
  final data = _dataScadenza(task);
  if (data == null) return 'Senza scadenza';
  final giorno = '${_dueCifre(data.day)}/${_dueCifre(data.month)}/${data.year}';
  final ora = (task.scadenzaOra ?? '').trim();
  return ora.isEmpty ? giorno : '$giorno · $ora';
}

/// Messaggio in italiano per gli errori di caricamento o di operazione.
String messaggioErroreTask(Object errore, {bool caricamento = false}) {
  final testo = errore.toString().toLowerCase();
  if (testo.contains('permission-denied')) {
    return 'Non hai i permessi per gestire i task. Contatta l\'amministratore.';
  }
  if (testo.contains('unavailable') || testo.contains('network')) {
    return 'Connessione assente. Controlla la rete e riprova.';
  }
  return caricamento
      ? 'Impossibile caricare i task. Riprova.'
      : 'Operazione non riuscita. Riprova.';
}

DateTime _soloGiorno(DateTime data) => DateTime(data.year, data.month, data.day);

String _dueCifre(int valore) => valore.toString().padLeft(2, '0');

/// Data di scadenza (`YYYY-MM-DD`) come [DateTime] a mezzanotte, `null` se
/// assente o non valida.
DateTime? _dataScadenza(TaskItem task) {
  final testo = task.scadenzaData?.trim() ?? '';
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(testo);
  if (match == null) return null;
  final anno = int.tryParse(match.group(1)!);
  final mese = int.tryParse(match.group(2)!);
  final giorno = int.tryParse(match.group(3)!);
  if (anno == null || mese == null || giorno == null) return null;
  final data = DateTime(anno, mese, giorno);
  if (data.year != anno || data.month != mese || data.day != giorno) return null;
  return data;
}

/// Nome utente per la tendina operatore, con fallback su username ed email.
String nomeOperatoreTask(UserProfile utente) {
  for (final valore in [utente.nome, utente.username, utente.email]) {
    final testo = valore?.trim() ?? '';
    if (testo.isNotEmpty) return testo;
  }
  return 'Utente';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Elenco dei task dell'azienda attiva, raggruppati per periodo.
class TaskScreen extends ConsumerStatefulWidget {
  const TaskScreen({super.key});

  @override
  ConsumerState<TaskScreen> createState() => _TaskScreenState();
}

class _TaskScreenState extends ConsumerState<TaskScreen> {
  final _ricerca = TextEditingController();

  List<TaskItem> _task = const [];
  List<UserProfile> _utenti = const [];
  bool _caricamento = true;
  Object? _errore;
  String? _erroreAzione;

  bool _soloAperti = false;
  bool _soloCompletati = false;
  String _operatore = '';
  String _testo = '';

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _ricerca.dispose();
    super.dispose();
  }

  /// Passa l'azienda attiva al servizio e ricarica task e utenti.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final risultati = await Future.wait([
        servizio.getTask(),
        servizio.getUtenti(),
      ]);
      if (!mounted) return;
      setState(() {
        _task = risultati[0] as List<TaskItem>;
        _utenti = risultati[1] as List<UserProfile>;
        _caricamento = false;
        _erroreAzione = null;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = errore;
        _caricamento = false;
      });
    }
  }

  SpService _servizio() {
    final servizio = ref.read(spServiceProvider);
    servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
    return servizio;
  }

  Future<void> _apriForm([TaskItem? task]) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(task: task)),
    );
    if (salvato == true) await _carica();
  }

  /// Segna completato un task aperto, oppure lo riapre se era completato.
  Future<void> _cambiaCompletamento(TaskItem task) async {
    final aprire = task.stato == 'completato';
    try {
      final servizio = _servizio();
      if (aprire) {
        // Passa tutti i campi: `aggiornaTask` riscrive l'intero documento.
        await servizio.aggiornaTask(task.id, {
          ...task.toMap(),
          'stato': 'aperto',
        });
        unawaited(servizio.registraAvvisiTask(task.id));
      } else {
        await servizio.completaTask(task.id);
        unawaited(servizio.annullaAvvisi(tipo: 'task', targetId: task.id));
      }
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      setState(() => _erroreAzione = messaggioErroreTask(errore));
    }
  }

  Future<void> _elimina(TaskItem task) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-elimina-task'),
        title: const Text('Eliminare il task?'),
        content: Text(
          'Il task "${(task.titolo ?? '').trim()}" verrà eliminato '
          'definitivamente. L\'operazione non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('task-elimina-conferma'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    try {
      await _servizio().eliminaTask(task.id);
      unawaited(
        _servizio().annullaAvvisi(tipo: 'task', targetId: task.id),
      );
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      setState(() => _erroreAzione = messaggioErroreTask(errore));
    }
  }

  /// Valore selezionato nel `SegmentedButton` dei filtri.
  String get _statoFiltro {
    if (_soloCompletati) return 'completati';
    if (_soloAperti) return 'aperti';
    return 'tutti';
  }

  Map<String, String> get _nomiOperatori => {
        for (final utente in _utenti) utente.id: nomeOperatoreTask(utente),
      };

  List<TaskItem> get _taskFiltrati {
    var visibili = filtraTaskVisibili(
      _task,
      soloAperti: _soloAperti,
      operatoreId: _operatore,
      testo: _testo,
    );
    if (_soloCompletati) {
      visibili = visibili.where((t) => t.stato == 'completato').toList();
    }
    return visibili;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _carica();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;
        final filtriAttivi = _soloAperti ||
            _soloCompletati ||
            _operatore.isNotEmpty ||
            _testo.trim().isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                orizzontale,
                orizzontale,
                0,
              ),
              child: _Intestazione(
                onNuovo: () => _apriForm(),
                onRicarica: _carica,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                AppSpazi.s,
                orizzontale,
                AppSpazi.s,
              ),
              child: _Filtri(
                stato: _statoFiltro,
                operatore: _operatore,
                utenti: _utenti,
                controllerRicerca: _ricerca,
                onStato: (valore) => setState(() {
                  _soloAperti = valore == 'aperti';
                  _soloCompletati = valore == 'completati';
                }),
                onOperatore: (valore) =>
                    setState(() => _operatore = valore ?? ''),
                onTesto: (valore) => setState(() => _testo = valore),
              ),
            ),
            if (_erroreAzione != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  orizzontale,
                  0,
                  orizzontale,
                  AppSpazi.s,
                ),
                child: AvvisoErrore(
                  key: const Key('task-errore-azione'),
                  testo: _erroreAzione!,
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  orizzontale,
                  0,
                  orizzontale,
                  orizzontale,
                ),
                child: _corpo(largo: largo, filtriAttivi: filtriAttivi),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _corpo({required bool largo, required bool filtriAttivi}) {
    if (_caricamento) {
      return const Center(
        child: CircularProgressIndicator(key: Key('task-caricamento')),
      );
    }

    if (_errore != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvvisoErrore(
                key: const Key('task-errore'),
                testo: messaggioErroreTask(_errore!, caricamento: true),
              ),
              const SizedBox(height: AppSpazi.m),
              FilledButton.icon(
                key: const Key('task-riprova'),
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    final visibili = _taskFiltrati;
    if (visibili.isEmpty) {
      return StatoCentrato(
        key: const Key('task-vuoto'),
        icona: filtriAttivi ? Icons.search_off : Icons.task_alt,
        titolo: filtriAttivi ? 'Nessun task trovato' : 'Nessun task',
        sottotitolo: filtriAttivi
            ? 'Prova a cambiare ricerca o filtri.'
            : 'Crea il primo task per organizzare il lavoro.',
        azione: filtriAttivi
            ? null
            : FilledButton.icon(
                key: const Key('task-vuoto-nuovo'),
                onPressed: () => _apriForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nuovo task'),
              ),
      );
    }

    final gruppi = raggruppaTaskPerPeriodo(visibili);
    final nomi = _nomiOperatori;
    final sezioni = <Widget>[];
    for (final periodo in periodiTask) {
      final gruppo = gruppi[periodo] ?? const <TaskItem>[];
      if (gruppo.isEmpty) continue;
      sezioni.add(
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpazi.s,
            bottom: AppSpazi.xs,
          ),
          child: Row(
            children: [
              Text(periodo, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(width: AppSpazi.xs),
              Text(
                '${gruppo.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
      for (final task in gruppo) {
        sezioni.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpazi.xs),
            child: _CardTask(
              task: task,
              nomeOperatore: nomi[task.operatoreId] ?? '',
              onCompleta: () => _cambiaCompletamento(task),
              onModifica: () => _apriForm(task),
              onElimina: () => _elimina(task),
            ),
          ),
        );
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: largo ? 900 : double.infinity),
        child: ListView(
          key: const Key('task-lista'),
          padding: EdgeInsets.zero,
          children: sezioni,
        ),
      ),
    );
  }
}

/// Intestazione con titolo e pulsante "Nuovo task".
class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.onNuovo, required this.onRicarica});

  final VoidCallback onNuovo;
  final VoidCallback onRicarica;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Task', style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        IconButton(
          key: const Key('task-ricarica'),
          onPressed: onRicarica,
          tooltip: 'Aggiorna',
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: AppSpazi.xs),
        FilledButton.icon(
          key: const Key('task-nuovo'),
          onPressed: onNuovo,
          icon: const Icon(Icons.add),
          label: const Text('Nuovo task'),
        ),
      ],
    );
  }
}

/// Filtri: stato, operatore e ricerca per titolo.
class _Filtri extends StatelessWidget {
  const _Filtri({
    required this.stato,
    required this.operatore,
    required this.utenti,
    required this.controllerRicerca,
    required this.onStato,
    required this.onOperatore,
    required this.onTesto,
  });

  final String stato;
  final String operatore;
  final List<UserProfile> utenti;
  final TextEditingController controllerRicerca;
  final ValueChanged<String> onStato;
  final ValueChanged<String?> onOperatore;
  final ValueChanged<String> onTesto;

  @override
  Widget build(BuildContext context) {
    final valoreOperatore = utenti.any((u) => u.id == operatore)
        ? operatore
        : '';

    return Wrap(
      spacing: AppSpazi.s,
      runSpacing: AppSpazi.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<String>(
          key: const Key('task-filtro-stato'),
          segments: const [
            ButtonSegment(value: 'tutti', label: Text('Tutti')),
            ButtonSegment(value: 'aperti', label: Text('Aperti')),
            ButtonSegment(value: 'completati', label: Text('Completati')),
          ],
          selected: {stato},
          showSelectedIcon: false,
          onSelectionChanged: (selezione) => onStato(selezione.first),
        ),
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            key: const Key('task-filtro-operatore'),
            initialValue: valoreOperatore,
            decoration: const InputDecoration(
              labelText: 'Utente',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Tutti gli utenti'),
              ),
              for (final utente in utenti)
                DropdownMenuItem<String>(
                  value: utente.id,
                  child: Text(nomeOperatoreTask(utente)),
                ),
            ],
            onChanged: onOperatore,
          ),
        ),
        SizedBox(
          width: 260,
          child: TextField(
            key: const Key('task-ricerca'),
            controller: controllerRicerca,
            textInputAction: TextInputAction.search,
            decoration: const InputDecoration(
              labelText: 'Cerca',
              hintText: 'Titolo del task',
              isDense: true,
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: onTesto,
          ),
        ),
      ],
    );
  }
}

/// Riga di un task: spunta, titolo, riferimenti, scadenza e menu azioni.
class _CardTask extends StatelessWidget {
  const _CardTask({
    required this.task,
    required this.nomeOperatore,
    required this.onCompleta,
    required this.onModifica,
    required this.onElimina,
  });

  final TaskItem task;
  final String nomeOperatore;
  final VoidCallback onCompleta;
  final VoidCallback onModifica;
  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final completato = task.stato == 'completato';
    final urgente = task.priorita == 'urgente';
    final titolo = (task.titolo ?? '').trim();
    final cliente = (task.clienteNome ?? '').trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpazi.xxs,
          AppSpazi.xxs,
          0,
          AppSpazi.xxs,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              key: Key('task-completa-${task.id}'),
              value: completato,
              onChanged: (_) => onCompleta(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpazi.s),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo.isEmpty ? '(senza titolo)' : titolo,
                      style: tema.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration:
                            completato ? TextDecoration.lineThrough : null,
                        color: completato
                            ? tema.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppSpazi.xxs),
                    Wrap(
                      spacing: AppSpazi.s,
                      runSpacing: AppSpazi.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (cliente.isNotEmpty)
                          _Dettaglio(
                            icona: Icons.business_outlined,
                            testo: cliente,
                          ),
                        if (nomeOperatore.isNotEmpty)
                          _Dettaglio(
                            icona: Icons.person_outline,
                            testo: nomeOperatore,
                          ),
                        _Dettaglio(
                          icona: Icons.event_outlined,
                          testo: formattaScadenzaTask(task),
                        ),
                        if (urgente)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpazi.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: tema.colorScheme.errorContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRaggi.chip),
                            ),
                            child: Text(
                              'Urgente',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              key: Key('task-menu-${task.id}'),
              tooltip: 'Azioni',
              onSelected: (azione) {
                if (azione == 'modifica') onModifica();
                if (azione == 'elimina') onElimina();
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'modifica',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifica'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'elimina',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline),
                    title: Text('Elimina'),
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

/// Icona e testo di un dettaglio del task.
class _Dettaglio extends StatelessWidget {
  const _Dettaglio({required this.icona, required this.testo});

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = tema.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icona, size: 14, color: colore),
        const SizedBox(width: AppSpazi.xxs),
        Text(
          testo,
          style: tema.textTheme.bodySmall?.copyWith(color: colore),
        ),
      ],
    );
  }
}
