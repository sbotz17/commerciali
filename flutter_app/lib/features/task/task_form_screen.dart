import 'dart:async';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/models/cliente.dart';
import '../../data/models/task_item.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import '../visite/visite_screen.dart'
    show
        dataIsoVisita,
        formattaDataVisita,
        normalizzaOraVisita,
        parseDataItaliana;

// ---------------------------------------------------------------------------
// Funzioni pure: validazioni ed etichette (verificabili senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Validazione del titolo: obbligatorio.
String? validaTitoloTask(String? valore) {
  final titolo = valore?.trim() ?? '';
  if (titolo.isEmpty) return 'Inserisci il titolo del task';
  return null;
}

/// Validazione della scadenza: facoltativa, ma se presente deve essere una data
/// italiana valida (`gg/mm/aaaa`).
String? validaDataTask(String? valore) {
  final testo = valore?.trim() ?? '';
  if (testo.isEmpty) return null;
  if (parseDataItaliana(testo) == null) {
    return 'Inserisci una data valida (gg/mm/aaaa)';
  }
  return null;
}

/// Etichetta italiana della priorità per il form (`Normale` / `Urgente`).
///
/// Qualsiasi valore diverso da `urgente` (compreso vuoto o assente) ricade su
/// `Normale`, che è il default del modello [TaskItem].
String etichettaPrioritaTaskForm(String? priorita) {
  final valore = priorita?.trim().toLowerCase() ?? '';
  return valore == 'urgente' ? 'Urgente' : 'Normale';
}

/// Validazione dell'ora di scadenza: facoltativa, ma se presente `HH:MM`.
String? _validaOraTask(String? valore) {
  final testo = valore?.trim() ?? '';
  if (testo.isEmpty) return null;
  if (normalizzaOraVisita(testo) == null) {
    return 'Inserisci un\'ora valida (HH:MM)';
  }
  return null;
}

/// Data `gg/mm/aaaa` da una scadenza ISO `YYYY-MM-DD`; `null` se non valida.
String? _dataItalianaDaScadenza(String? iso) {
  final testo = iso?.trim() ?? '';
  final data = DateTime.tryParse(testo);
  if (data == null) return null;
  return formattaDataVisita(data);
}

/// Nome del cliente per la tendina, con fallback per i documenti senza nome.
String _nomeClienteTask(Cliente cliente) {
  final nome = cliente.nome?.trim() ?? '';
  return nome.isEmpty ? '(senza nome)' : nome;
}

/// Nome dell'utente per la tendina operatore, con fallback su username/email.
String _nomeUtenteTask(UserProfile utente) {
  for (final valore in [utente.nome, utente.username, utente.email]) {
    final testo = valore?.trim() ?? '';
    if (testo.isNotEmpty) return testo;
  }
  return 'Utente';
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio.
String _messaggioErroreTask(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per gestire i task. '
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
// Form
// ---------------------------------------------------------------------------

/// Form completo di un task, aperto a pagina intera (nuovo o modifica).
class TaskFormScreen extends ConsumerStatefulWidget {
  const TaskFormScreen({super.key, this.task});

  /// Task da modificare; `null` per crearne uno nuovo.
  final TaskItem? task;

  @override
  ConsumerState<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends ConsumerState<TaskFormScreen> {
  final _modulo = GlobalKey<FormState>();

  late final TextEditingController _titolo;
  late final TextEditingController _descrizione;
  late final TextEditingController _data;
  late final TextEditingController _ora;
  late final TextEditingController _note;

  late String _priorita;
  String? _operatoreId;
  String? _clienteId;

  List<Cliente> _clienti = const [];
  List<UserProfile> _utenti = const [];
  bool _caricamento = true;
  Object? _erroreDati;

  bool _salvando = false;
  String? _errore;

  bool get _modifica => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;

    _titolo = TextEditingController(text: task?.titolo ?? '');
    _descrizione = TextEditingController(text: task?.descrizione ?? '');
    _data = TextEditingController(
      text: _dataItalianaDaScadenza(task?.scadenzaData) ?? '',
    );
    _ora = TextEditingController(text: task?.scadenzaOra ?? '');
    _note = TextEditingController(text: task?.note ?? '');

    final priorita = (task?.priorita ?? 'normale').trim().toLowerCase();
    _priorita = priorita == 'urgente' ? 'urgente' : 'normale';
    _operatoreId = task?.operatoreId ?? _uidCorrente();
    _clienteId = task?.clienteId;

    _caricaDati();
  }

  @override
  void dispose() {
    _titolo.dispose();
    _descrizione.dispose();
    _data.dispose();
    _ora.dispose();
    _note.dispose();
    super.dispose();
  }

  /// Uid dell'utente autenticato, `null` se non disponibile.
  String? _uidCorrente() {
    try {
      return ref.read(firebaseAuthProvider).currentUser?.uid;
    } catch (_) {
      // Firebase non inizializzato (test, anteprima): nessun default.
      return null;
    }
  }

  /// Carica clienti e utenti in parallelo, impostando prima l'azienda attiva.
  ///
  /// Un errore non blocca il form: titolo, descrizione e scadenza restano
  /// modificabili e viene mostrato un avviso con "Riprova".
  Future<void> _caricaDati() async {
    setState(() {
      _caricamento = true;
      _erroreDati = null;
    });

    Future<List<Cliente>>? clientiFuturo;
    Future<List<UserProfile>>? utentiFuturo;
    Object? erroreAvvio;
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      clientiFuturo = servizio.getClienti();
      utentiFuturo = servizio.getUtenti();
    } catch (errore) {
      erroreAvvio = errore;
    }

    List<Cliente>? clienti;
    List<UserProfile>? utenti;
    Object? errore = erroreAvvio;
    if (clientiFuturo != null) {
      try {
        clienti = await clientiFuturo;
      } catch (e) {
        errore ??= e;
      }
    }
    if (utentiFuturo != null) {
      try {
        utenti = await utentiFuturo;
      } catch (e) {
        errore ??= e;
      }
    }

    if (!mounted) return;
    setState(() {
      if (clienti != null) _clienti = clienti;
      if (utenti != null) _utenti = utenti;
      _erroreDati = errore;
      _caricamento = false;
    });
  }

  Cliente? get _clienteSelezionato {
    for (final cliente in _clienti) {
      if (cliente.id == _clienteId) return cliente;
    }
    return null;
  }

  /// Voci della tendina cliente, compreso il cliente salvato se non è più in
  /// elenco (per non perdere il collegamento in modifica).
  Map<String, String> get _opzioniClienti {
    final opzioni = <String, String>{
      for (final cliente in _clienti) cliente.id: _nomeClienteTask(cliente),
    };
    final id = _clienteId;
    if (id != null && id.isNotEmpty && !opzioni.containsKey(id)) {
      final nome = widget.task?.clienteNome?.trim() ?? '';
      opzioni[id] = nome.isEmpty ? 'Cliente non disponibile' : nome;
    }
    return opzioni;
  }

  /// Voci della tendina operatore, con l'utente corrente se non è in elenco.
  Map<String, String> get _opzioniOperatori {
    final opzioni = <String, String>{
      for (final utente in _utenti) utente.uid: _nomeUtenteTask(utente),
    };
    final id = _operatoreId;
    if (id != null && id.isNotEmpty && !opzioni.containsKey(id)) {
      opzioni[id] = 'Utente corrente';
    }
    return opzioni;
  }

  Future<void> _scegliData() async {
    final iniziale = parseDataItaliana(_data.text) ?? DateTime.now();
    final scelta = await showDatePicker(
      context: context,
      initialDate: iniziale,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Scegli la scadenza',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      fieldLabelText: 'Scadenza',
    );
    if (scelta == null || !mounted) return;
    setState(() => _data.text = formattaDataVisita(scelta));
  }

  Future<void> _scegliOra() async {
    final normalizzata = normalizzaOraVisita(_ora.text);
    final parti = normalizzata?.split(':');
    final scelta = await showTimePicker(
      context: context,
      initialTime: parti == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(
              hour: int.tryParse(parti[0]) ?? 9,
              minute: int.tryParse(parti[1]) ?? 0,
            ),
      helpText: 'Scegli l\'orario',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      hourLabelText: 'Ore',
      minuteLabelText: 'Minuti',
      builder: (context, child) {
        final media = MediaQuery.of(context);
        if (media.alwaysUse24HourFormat) return child ?? const SizedBox();
        return MediaQuery(
          data: media.copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (scelta == null || !mounted) return;
    setState(() {
      _ora.text = '${scelta.hour.toString().padLeft(2, '0')}:'
          '${scelta.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _salva() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    final giorno = parseDataItaliana(_data.text);
    final task = widget.task;
    final cliente = _clienteSelezionato;

    final dati = <String, dynamic>{
      'titolo': _titolo.text,
      'descrizione': _descrizione.text,
      'scadenza_data': giorno == null ? null : dataIsoVisita(giorno),
      'scadenza_ora': normalizzaOraVisita(_ora.text),
      'operatore_id': _operatoreId,
      'priorita': _priorita,
      'stato': task?.stato ?? 'aperto',
      'cliente_id': _clienteId,
      'cliente_nome': cliente?.nome ??
          (cliente == null ? task?.clienteNome : null),
      'note': _note.text,
      // Campi non gestiti dal form: preservati in modifica.
      'appuntamento_id': task?.appuntamentoId,
      'completato_da': task?.completatoDa,
      'completato_at': task?.completatoAt,
    };

    setState(() => _salvando = true);
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final risultato = task != null
          ? await servizio.aggiornaTask(task.id, dati)
          : await servizio.inserisciTask(dati);
      final idRisposta = (risultato['id'] as String?)?.trim() ?? '';
      final id = idRisposta.isNotEmpty
          ? idRisposta
          : (task?.id.trim() ?? '');
      if (id.isNotEmpty) {
        // Gli avvisi sono best-effort: un errore non annulla il salvataggio.
        unawaited(servizio.rinnovaAvvisiTask(id));
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = _messaggioErroreTask(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final opzioniClienti = _opzioniClienti;
    final opzioniOperatori = _opzioniOperatori;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica task' : 'Nuovo task'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpazi.paginaTelefono),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _modulo,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_caricamento) ...[
                      const LinearProgressIndicator(
                        key: Key('task-caricamento'),
                      ),
                      const SizedBox(height: AppSpazi.m),
                    ],
                    if (_erroreDati != null) ...[
                      AvvisoErrore(
                        key: const Key('task-errore-dati'),
                        testo: _messaggioErroreTask(_erroreDati!),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('task-riprova'),
                          onPressed: _salvando ? null : _caricaDati,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Riprova'),
                        ),
                      ),
                      const SizedBox(height: AppSpazi.m),
                    ],
                    _SezioneTask(
                      titolo: 'Task',
                      figli: [
                        TextFormField(
                          key: const Key('task-titolo'),
                          controller: _titolo,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Titolo *',
                            hintText: 'Es. Richiamare il cliente',
                          ),
                          validator: validaTitoloTask,
                        ),
                        TextFormField(
                          key: const Key('task-descrizione'),
                          controller: _descrizione,
                          enabled: !_salvando,
                          minLines: 2,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            labelText: 'Descrizione',
                          ),
                        ),
                        TextFormField(
                          key: const Key('task-scadenza-data'),
                          controller: _data,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9/]'),
                            ),
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Scadenza (data)',
                            hintText: 'gg/mm/aaaa',
                            suffixIcon: IconButton(
                              key: const Key('task-scegli-data'),
                              tooltip: 'Scegli la data',
                              onPressed: _salvando ? null : _scegliData,
                              icon: const Icon(Icons.calendar_today_outlined),
                            ),
                          ),
                          validator: validaDataTask,
                        ),
                        TextFormField(
                          key: const Key('task-scadenza-ora'),
                          controller: _ora,
                          enabled: !_salvando,
                          textInputAction: TextInputAction.next,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9:]'),
                            ),
                            LengthLimitingTextInputFormatter(5),
                          ],
                          decoration: InputDecoration(
                            labelText: 'Scadenza (ora)',
                            hintText: 'HH:MM',
                            suffixIcon: IconButton(
                              key: const Key('task-scegli-ora'),
                              tooltip: 'Scegli l\'ora',
                              onPressed: _salvando ? null : _scegliOra,
                              icon: const Icon(Icons.schedule_outlined),
                            ),
                          ),
                          validator: _validaOraTask,
                        ),
                        DropdownButtonFormField<String>(
                          key: const Key('task-operatore'),
                          initialValue: _operatoreId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Utente',
                            hintText: 'Scegli un utente',
                            helperText: _caricamento
                                ? 'Caricamento utenti…'
                                : null,
                          ),
                          items: [
                            for (final voce in opzioniOperatori.entries)
                              DropdownMenuItem(
                                value: voce.key,
                                child: Text(
                                  voce.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _salvando || _caricamento
                              ? null
                              : (valore) =>
                                  setState(() => _operatoreId = valore),
                        ),
                        DropdownButtonFormField<String>(
                          key: const Key('task-priorita'),
                          initialValue: _priorita,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Priorità',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'normale',
                              child: Text('Normale'),
                            ),
                            DropdownMenuItem(
                              value: 'urgente',
                              child: Text('Urgente'),
                            ),
                          ],
                          onChanged: _salvando
                              ? null
                              : (valore) {
                                  if (valore == null) return;
                                  setState(() => _priorita = valore);
                                },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _SezioneTask(
                      titolo: 'Collegamenti e note',
                      figli: [
                        DropdownButtonFormField<String>(
                          key: const Key('task-cliente'),
                          initialValue: _clienteId ?? '',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Cliente',
                            helperText: _caricamento
                                ? 'Caricamento clienti…'
                                : null,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Nessun cliente'),
                            ),
                            for (final voce in opzioniClienti.entries)
                              DropdownMenuItem(
                                value: voce.key,
                                child: Text(
                                  voce.value,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _salvando || _caricamento
                              ? null
                              : (valore) => setState(() {
                                    _clienteId = (valore == null || valore.isEmpty)
                                        ? null
                                        : valore;
                                  }),
                        ),
                        TextFormField(
                          key: const Key('task-note'),
                          controller: _note,
                          enabled: !_salvando,
                          minLines: 3,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                          ),
                        ),
                      ],
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('task-errore'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-task'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-task'),
                            onPressed: _salvando ? null : _salva,
                            child: _salvando
                                ? const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: AppSpazi.s),
                                      Text('Salvataggio…'),
                                    ],
                                  )
                                : Text(
                                    _modifica ? 'Salva modifiche' : 'Crea task',
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Text(
                      'I campi contrassegnati con * sono obbligatori.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Card di sezione del form con titolo e campi su una o due colonne.
class _SezioneTask extends StatelessWidget {
  const _SezioneTask({required this.titolo, required this.figli});

  final String titolo;
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              titolo.toUpperCase(),
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            LayoutBuilder(
              builder: (context, constraints) {
                final doppia = constraints.maxWidth >= 520;
                final larghezza = doppia
                    ? (constraints.maxWidth - AppSpazi.s) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: AppSpazi.s,
                  runSpacing: AppSpazi.s,
                  children: [
                    for (final figlio in figli)
                      SizedBox(width: larghezza, child: figlio),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
