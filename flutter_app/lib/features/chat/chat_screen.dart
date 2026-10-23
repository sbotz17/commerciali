// Elenco delle conversazioni di chat dell'azienda attiva.
//
// La schermata carica stanze e utenti, resta aggiornata con
// `chatStanzeStream` e permette di aprire una chat diretta o creare un gruppo.
// I dialoghi riusano gli utenti attivi dell'azienda, escluso l'utente corrente.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/stanza_chat.dart';
import '../../data/models/user_profile.dart';
import '../../data/services/sp_service.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import 'chat_thread_screen.dart';

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Nome leggibile di un utente, con fallback su username, email e uid.
String _nomeUtente(UserProfile utente) {
  for (final valore in [utente.nome, utente.username, utente.email]) {
    final testo = valore?.trim() ?? '';
    if (testo.isNotEmpty) return testo;
  }
  return utente.uid;
}

/// Utenti selezionabili per una nuova conversazione.
///
/// Tiene solo i profili attivi (`attivo` diverso da `false`), esclude l'utente
/// corrente e ordina per nome senza distinzione tra maiuscole e minuscole,
/// usando l'uid come spareggio. La lista in ingresso non viene modificata.
List<UserProfile> utentiDisponibiliChat(
  List<UserProfile> utenti, {
  required String uidCorrente,
}) {
  final disponibili = utenti
      .where((utente) => utente.attivo != false && utente.uid != uidCorrente)
      .toList();

  disponibili.sort((a, b) {
    final confronto = _nomeUtente(
      a,
    ).toLowerCase().compareTo(_nomeUtente(b).toLowerCase());
    if (confronto != 0) return confronto;
    return a.uid.compareTo(b.uid);
  });

  return disponibili;
}

DateTime? _dataStanza(StanzaChat stanza) {
  for (final grezza in [
    stanza.ultimoMessaggioAt,
    stanza.updatedAt,
    stanza.createdAt,
  ]) {
    final testo = grezza?.trim() ?? '';
    if (testo.isEmpty) continue;
    final data = DateTime.tryParse(testo);
    if (data != null) return data.toLocal();
  }
  return null;
}

/// Data e ora italiane (`gg/mm/aaaa · HH:mm`) dell'ultimo messaggio.
///
/// Restituisce una stringa vuota quando la stanza non ha una data valida.
String formattaDataOraStanzaChat(StanzaChat stanza) {
  final data = _dataStanza(stanza);
  if (data == null) return '';
  return DateFormat('dd/MM/yyyy · HH:mm').format(data);
}

/// Anteprima dell'ultimo messaggio, oppure `Nessun messaggio`.
String anteprimaStanzaChat(StanzaChat stanza) {
  final testo = stanza.ultimoMessaggio?.trim() ?? '';
  return testo.isEmpty ? 'Nessun messaggio' : testo;
}

/// Messaggio in italiano per gli errori di creazione di una conversazione.
String messaggioErroreCreazioneChat(Object errore) {
  final testo = errore.toString().toLowerCase();
  if (testo.contains('permission-denied')) {
    return 'Non hai i permessi per creare conversazioni. '
        'Contatta l\'amministratore.';
  }
  if (testo.contains('unavailable') || testo.contains('network')) {
    return 'Connessione assente. Controlla la rete e riprova.';
  }
  return 'Impossibile creare la conversazione. Riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Elenco delle conversazioni dell'utente corrente.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  List<StanzaChat> _stanze = const [];
  List<UserProfile> _utenti = const [];
  StreamSubscription<List<StanzaChat>>? _sottoscrizione;

  bool _caricamento = true;
  bool _creazioneInCorso = false;
  Object? _errore;
  String? _erroreAzione;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _sottoscrizione?.cancel();
    super.dispose();
  }

  SpService _servizio() {
    final servizio = ref.read(spServiceProvider);
    servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
    return servizio;
  }

  /// Carica stanze e utenti, poi si aggiorna in tempo reale dallo stream.
  Future<void> _carica() async {
    await _sottoscrizione?.cancel();
    _sottoscrizione = null;
    if (!mounted) return;

    setState(() {
      _caricamento = true;
      _errore = null;
      _erroreAzione = null;
    });

    final servizio = _servizio();
    try {
      final risultati = await Future.wait([
        servizio.getChatStanze(),
        servizio.getUtenti(),
      ]);
      if (!mounted) return;
      setState(() {
        _stanze = risultati[0] as List<StanzaChat>;
        _utenti = risultati[1] as List<UserProfile>;
        _caricamento = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = errore;
        _caricamento = false;
      });
      return;
    }

    if (!mounted) return;
    _sottoscrizione = servizio.chatStanzeStream().listen(
      (stanze) {
        if (!mounted) return;
        setState(() {
          _stanze = stanze;
          _caricamento = false;
          _errore = null;
        });
      },
      onError: (Object errore) {
        if (!mounted) return;
        setState(() {
          _errore = errore;
          _caricamento = false;
        });
      },
    );
  }

  Map<String, String> get _nomiUtenti => {
        for (final utente in _utenti) utente.uid: _nomeUtente(utente),
      };

  void _apriThread(StanzaChat stanza) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatThreadScreen(stanza: stanza)),
    );
  }

  Future<void> _apriNuovaChat() async {
    if (_creazioneInCorso) return;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final disponibili = utentiDisponibiliChat(_utenti, uidCorrente: uid);

    final scelto = await showDialog<UserProfile>(
      context: context,
      builder: (context) => _DialogNuovaChat(utenti: disponibili),
    );
    if (scelto == null || !mounted) return;

    setState(() {
      _creazioneInCorso = true;
      _erroreAzione = null;
    });
    try {
      final stanza = await _servizio().creaChatDiretta(scelto.uid);
      await _carica();
      if (!mounted) return;
      _apriThread(stanza);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _erroreAzione = messaggioErroreCreazioneChat(errore));
    } finally {
      if (mounted) setState(() => _creazioneInCorso = false);
    }
  }

  Future<void> _apriNuovoGruppo() async {
    if (_creazioneInCorso) return;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
    final disponibili = utentiDisponibiliChat(_utenti, uidCorrente: uid);

    final dati = await showDialog<_DatiNuovoGruppo>(
      context: context,
      builder: (context) => _DialogNuovoGruppo(utenti: disponibili),
    );
    if (dati == null || !mounted) return;

    setState(() {
      _creazioneInCorso = true;
      _erroreAzione = null;
    });
    try {
      final stanza = await _servizio().creaGruppo(dati.nome, dati.partecipanti);
      await _carica();
      if (!mounted) return;
      _apriThread(stanza);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _erroreAzione = messaggioErroreCreazioneChat(errore));
    } finally {
      if (mounted) setState(() => _creazioneInCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _carica();
    });

    final uidCorrente =
        ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        final orizzontale =
            constraints.maxWidth >= AppBreakpoints.telefono
                ? AppSpazi.paginaDesktop
                : AppSpazi.paginaTelefono;

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
              child: _IntestazioneChat(
                creazioneInCorso: _creazioneInCorso,
                onRicarica: _carica,
                onNuovaChat: _apriNuovaChat,
                onNuovoGruppo: _apriNuovoGruppo,
              ),
            ),
            if (_erroreAzione != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  orizzontale,
                  AppSpazi.s,
                  orizzontale,
                  0,
                ),
                child: AvvisoErrore(
                  key: const Key('chat-errore-azione'),
                  testo: _erroreAzione!,
                ),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  orizzontale,
                  AppSpazi.s,
                  orizzontale,
                  orizzontale,
                ),
                child: CorpoChat(
                  stanze: _stanze,
                  uidCorrente: uidCorrente,
                  nomiUtenti: _nomiUtenti,
                  caricamento: _caricamento,
                  errore: _errore,
                  onRiprova: _carica,
                  onApri: _apriThread,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Corpo della schermata: caricamento, errore, vuoto oppure elenco.
///
/// È pubblico per i test widget: non richiede Firebase né provider.
class CorpoChat extends StatelessWidget {
  const CorpoChat({
    super.key,
    required this.stanze,
    required this.uidCorrente,
    required this.caricamento,
    this.nomiUtenti = const {},
    this.errore,
    this.onRiprova,
    this.onApri,
  });

  final List<StanzaChat> stanze;
  final String uidCorrente;
  final Map<String, String> nomiUtenti;
  final bool caricamento;
  final Object? errore;
  final VoidCallback? onRiprova;
  final ValueChanged<StanzaChat>? onApri;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        child: CircularProgressIndicator(key: Key('chat-caricamento')),
      );
    }

    if (errore != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvvisoErrore(
                key: const Key('chat-errore'),
                testo: messaggioErroreChat(errore!, caricamento: true),
              ),
              const SizedBox(height: AppSpazi.m),
              FilledButton.icon(
                key: const Key('chat-riprova'),
                onPressed: onRiprova,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (stanze.isEmpty) {
      return const StatoCentrato(
        key: Key('chat-vuoto'),
        icona: Icons.chat_bubble_outline,
        titolo: 'Nessuna conversazione',
        sottotitolo:
            'Avvia una chat diretta o crea un gruppo per iniziare a '
            'scambiare messaggi con i colleghi.',
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          key: const Key('chat-lista'),
          padding: EdgeInsets.zero,
          itemCount: stanze.length,
          separatorBuilder: (context, indice) =>
              const SizedBox(height: AppSpazi.xs),
          itemBuilder: (context, indice) {
            final stanza = stanze[indice];
            return _VoceChat(
              stanza: stanza,
              titolo: nomeStanzaChat(
                stanza,
                uidCorrente: uidCorrente,
                nomiUtenti: nomiUtenti,
              ),
              onApri: onApri,
            );
          },
        ),
      ),
    );
  }
}

/// Intestazione con titolo e azioni per nuova chat, nuovo gruppo e aggiorna.
class _IntestazioneChat extends StatelessWidget {
  const _IntestazioneChat({
    required this.creazioneInCorso,
    required this.onRicarica,
    required this.onNuovaChat,
    required this.onNuovoGruppo,
  });

  final bool creazioneInCorso;
  final VoidCallback onRicarica;
  final VoidCallback onNuovaChat;
  final VoidCallback onNuovoGruppo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final titolo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Chat', style: tema.textTheme.titleLarge),
        if (creazioneInCorso) ...[
          const SizedBox(width: AppSpazi.xs),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );

    final azioni = Wrap(
      spacing: AppSpazi.xs,
      runSpacing: AppSpazi.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          key: const Key('chat-ricarica'),
          onPressed: creazioneInCorso ? null : onRicarica,
          tooltip: 'Aggiorna',
          icon: const Icon(Icons.refresh),
        ),
        FilledButton.icon(
          key: const Key('chat-nuova'),
          onPressed: creazioneInCorso ? null : onNuovaChat,
          icon: const Icon(Icons.add_comment_outlined),
          label: const Text('Nuova chat'),
        ),
        OutlinedButton.icon(
          key: const Key('chat-nuovo-gruppo'),
          onPressed: creazioneInCorso ? null : onNuovoGruppo,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Nuovo gruppo'),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titolo,
              const SizedBox(height: AppSpazi.xs),
              azioni,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titolo),
            const SizedBox(width: AppSpazi.s),
            azioni,
          ],
        );
      },
    );
  }
}

/// Riga di una conversazione: icona del tipo, nome, anteprima e data/ora.
class _VoceChat extends StatelessWidget {
  const _VoceChat({
    required this.stanza,
    required this.titolo,
    this.onApri,
  });

  final StanzaChat stanza;
  final String titolo;
  final ValueChanged<StanzaChat>? onApri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gruppo = stanza.tipo == 'gruppo';
    final dataOra = formattaDataOraStanzaChat(stanza);

    return Card(
      key: Key('chat-stanza-${stanza.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onApri == null ? null : () => onApri!(stanza),
        child: Padding(
          padding: const EdgeInsets.all(AppSpazi.s),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRaggi.chip),
                ),
                child: Icon(
                  gruppo ? Icons.group_outlined : Icons.person_outline,
                  size: 24,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpazi.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titolo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (dataOra.isNotEmpty) ...[
                          const SizedBox(width: AppSpazi.xs),
                          Text(
                            dataOra,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      anteprimaStanzaChat(stanza),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpazi.xs),
              Icon(
                Icons.chevron_right,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialogo per scegliere l'utente di una nuova chat diretta.
class _DialogNuovaChat extends StatefulWidget {
  const _DialogNuovaChat({required this.utenti});

  final List<UserProfile> utenti;

  @override
  State<_DialogNuovaChat> createState() => _DialogNuovaChatState();
}

class _DialogNuovaChatState extends State<_DialogNuovaChat> {
  final _ricerca = TextEditingController();
  String _testo = '';

  @override
  void dispose() {
    _ricerca.dispose();
    super.dispose();
  }

  List<UserProfile> get _filtrati {
    final cerca = _testo.trim().toLowerCase();
    if (cerca.isEmpty) return widget.utenti;
    return widget.utenti.where((utente) {
      final valori = [utente.nome, utente.username, utente.email, utente.uid];
      return valori.any(
        (valore) => (valore ?? '').toLowerCase().contains(cerca),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtrati = _filtrati;

    return AlertDialog(
      key: const Key('chat-dialog-nuova'),
      title: const Text('Nuova chat'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            TextField(
              key: const Key('chat-ricerca-utenti'),
              controller: _ricerca,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Cerca',
                hintText: 'Nome o email',
                isDense: true,
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (valore) => setState(() => _testo = valore),
            ),
            const SizedBox(height: AppSpazi.s),
            Expanded(
              child: filtrati.isEmpty
                  ? const StatoCentrato(
                      key: Key('chat-nuova-vuoto'),
                      icona: Icons.person_search_outlined,
                      titolo: 'Nessun utente disponibile',
                      sottotitolo:
                          'Non ci sono altri utenti attivi da contattare.',
                    )
                  : ListView.builder(
                      key: const Key('chat-lista-utenti'),
                      padding: EdgeInsets.zero,
                      itemCount: filtrati.length,
                      itemBuilder: (context, indice) {
                        final utente = filtrati[indice];
                        final email = utente.email?.trim() ?? '';
                        return ListTile(
                          key: Key('chat-utente-${utente.uid}'),
                          leading: CircleAvatar(
                            child: Text(
                              _nomeUtente(utente)
                                  .characters
                                  .first
                                  .toUpperCase(),
                            ),
                          ),
                          title: Text(_nomeUtente(utente)),
                          subtitle: email.isEmpty ? null : Text(email),
                          onTap: () => Navigator.of(context).pop(utente),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
      ],
    );
  }
}

/// Dati scelti nel dialogo di creazione di un gruppo.
class _DatiNuovoGruppo {
  const _DatiNuovoGruppo({required this.nome, required this.partecipanti});

  final String nome;
  final List<String> partecipanti;
}

/// Dialogo con nome del gruppo e selezione multipla degli utenti attivi.
class _DialogNuovoGruppo extends StatefulWidget {
  const _DialogNuovoGruppo({required this.utenti});

  final List<UserProfile> utenti;

  @override
  State<_DialogNuovoGruppo> createState() => _DialogNuovoGruppoState();
}

class _DialogNuovoGruppoState extends State<_DialogNuovoGruppo> {
  final _nome = TextEditingController();
  final _selezionati = <String>{};

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  bool get _puoCreare =>
      _nome.text.trim().isNotEmpty && _selezionati.isNotEmpty;

  void _crea() {
    if (!_puoCreare) return;
    Navigator.of(context).pop(
      _DatiNuovoGruppo(
        nome: _nome.text.trim(),
        partecipanti: _selezionati.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('chat-dialog-nuovo-gruppo'),
      title: const Text('Nuovo gruppo'),
      content: SizedBox(
        width: 420,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('chat-gruppo-nome'),
              controller: _nome,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nome del gruppo',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpazi.s),
            Text(
              'Partecipanti',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpazi.xxs),
            Expanded(
              child: widget.utenti.isEmpty
                  ? const StatoCentrato(
                      key: Key('chat-gruppo-vuoto'),
                      icona: Icons.group_off_outlined,
                      titolo: 'Nessun utente disponibile',
                      sottotitolo:
                          'Non ci sono altri utenti attivi da aggiungere.',
                    )
                  : ListView.builder(
                      key: const Key('chat-gruppo-utenti'),
                      padding: EdgeInsets.zero,
                      itemCount: widget.utenti.length,
                      itemBuilder: (context, indice) {
                        final utente = widget.utenti[indice];
                        return CheckboxListTile(
                          key: Key('chat-gruppo-utente-${utente.uid}'),
                          value: _selezionati.contains(utente.uid),
                          title: Text(_nomeUtente(utente)),
                          subtitle: (utente.email?.trim() ?? '').isEmpty
                              ? null
                              : Text(utente.email!.trim()),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (selezionato) {
                            setState(() {
                              if (selezionato == true) {
                                _selezionati.add(utente.uid);
                              } else {
                                _selezionati.remove(utente.uid);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('chat-gruppo-crea'),
          onPressed: _puoCreare ? _crea : null,
          child: const Text('Crea gruppo'),
        ),
      ],
    );
  }
}
