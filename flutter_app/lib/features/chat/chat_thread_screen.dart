// Conversazione di una stanza di chat.
//
// La schermata mostra i messaggi della sottocollezione
// `chat_stanze/{id}/messaggi` in tempo reale con `messaggiStream`, invia con
// `inviaMessaggio` e segna la stanza come letta all'apertura. Il raggruppamento
// per giorno e il formato dell'ora sono funzioni pure, così restano
// verificabili senza Firebase né widget.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/messaggio_chat.dart';
import '../../data/models/stanza_chat.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Messaggi di uno stesso giorno, nell'ordine cronologico di arrivo.
class GruppoMessaggiGiorno {
  GruppoMessaggiGiorno({this.giorno, List<MessaggioChat> messaggi = const []})
    : messaggi = List.of(messaggi);

  /// Mezzanotte locale del giorno, oppure `null` per i messaggi senza data.
  final DateTime? giorno;

  /// Messaggi del gruppo, in ordine cronologico.
  final List<MessaggioChat> messaggi;
}

DateTime? _dataMessaggio(MessaggioChat messaggio) {
  final grezza = messaggio.createdAt?.trim() ?? '';
  if (grezza.isEmpty) return null;
  return DateTime.tryParse(grezza)?.toLocal();
}

int _confrontaMessaggi(MessaggioChat a, MessaggioChat b) {
  final dataA = _dataMessaggio(a);
  final dataB = _dataMessaggio(b);
  if (dataA == null && dataB == null) return a.id.compareTo(b.id);
  if (dataA == null) return -1;
  if (dataB == null) return 1;
  final confronto = dataA.compareTo(dataB);
  if (confronto != 0) return confronto;
  return a.id.compareTo(b.id);
}

bool _stessoGiorno(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == null && b == null;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Raggruppa i messaggi per giorno locale, in ordine cronologico crescente.
///
/// I messaggi senza `createdAt` valido finiscono in un gruppo con
/// [GruppoMessaggiGiorno.giorno] `null`, all'inizio. La lista ricevuta non
/// viene modificata.
List<GruppoMessaggiGiorno> raggruppaMessaggiPerGiorno(
  List<MessaggioChat> messaggi,
) {
  final ordinati = List<MessaggioChat>.of(messaggi)..sort(_confrontaMessaggi);
  final gruppi = <GruppoMessaggiGiorno>[];

  for (final messaggio in ordinati) {
    final data = _dataMessaggio(messaggio);
    final giorno = data == null
        ? null
        : DateTime(data.year, data.month, data.day);
    if (gruppi.isEmpty || !_stessoGiorno(gruppi.last.giorno, giorno)) {
      gruppi.add(GruppoMessaggiGiorno(giorno: giorno, messaggi: [messaggio]));
    } else {
      gruppi.last.messaggi.add(messaggio);
    }
  }

  return gruppi;
}

/// Orario `HH:mm` locale del messaggio; stringa vuota se la data non è valida.
String oraMessaggio(MessaggioChat messaggio) {
  final data = _dataMessaggio(messaggio);
  if (data == null) return '';
  return DateFormat('HH:mm').format(data);
}

/// Intestazione italiana del giorno: `Oggi`, `Ieri`, `gg/mm/aaaa` oppure
/// `Senza data`.
String etichettaGiornoChat(DateTime? giorno, {DateTime? adesso}) {
  if (giorno == null) return 'Senza data';

  final g = giorno.toLocal();
  final riferimento = (adesso ?? DateTime.now()).toLocal();
  final soloGiorno = DateTime(g.year, g.month, g.day);
  final soloOggi = DateTime(
    riferimento.year,
    riferimento.month,
    riferimento.day,
  );
  final differenza = soloOggi.difference(soloGiorno).inDays;

  if (differenza == 0) return 'Oggi';
  if (differenza == 1) return 'Ieri';
  return DateFormat('dd/MM/yyyy').format(g);
}

/// Messaggio in italiano per gli errori di caricamento o invio.
String messaggioErroreChat(Object errore, {bool caricamento = false}) {
  final testo = errore.toString().toLowerCase();
  if (testo.contains('permission-denied')) {
    return 'Non hai i permessi per questa conversazione. '
        'Contatta l\'amministratore.';
  }
  if (testo.contains('unavailable') || testo.contains('network')) {
    return 'Connessione assente. Controlla la rete e riprova.';
  }
  return caricamento
      ? 'Impossibile caricare i messaggi. Riprova.'
      : 'Invio non riuscito. Riprova.';
}

/// Uid dei partecipanti alla stanza che devono ricevere la notifica di un
/// nuovo messaggio: tutti tranne [mittenteUid], senza duplicati e senza uid
/// vuoti. L'ordine è quello di [StanzaChat.partecipantiUids].
List<String> destinatariNotificaChat(
  StanzaChat stanza, {
  required String mittenteUid,
}) {
  final mittente = mittenteUid.trim();
  final visti = <String>{};
  final destinatari = <String>[];

  for (final grezzo in stanza.partecipantiUids) {
    final uid = grezzo.trim();
    if (uid.isEmpty) continue;
    if (uid == mittente) continue;
    if (!visti.add(uid)) continue;
    destinatari.add(uid);
  }

  return destinatari;
}

/// Nome leggibile di un utente per il titolo della stanza.
String _nomeUtente(UserProfile utente) {
  for (final valore in [utente.nome, utente.username, utente.email]) {
    final testo = valore?.trim() ?? '';
    if (testo.isNotEmpty) return testo;
  }
  return utente.uid;
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Conversazione della stanza [stanza], con elenco messaggi e composer.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.stanza});

  /// Stanza di chat da aprire.
  final StanzaChat stanza;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  late Stream<List<MessaggioChat>> _flusso;
  Map<String, String> _nomiUtenti = const {};
  String? _ultimoMessaggioVisto;
  int _numeroMessaggi = 0;
  bool _invioInCorso = false;

  @override
  void initState() {
    super.initState();
    _flusso = ref.read(spServiceProvider).messaggiStream(widget.stanza.id);
    _segnaLetta();
    _caricaNomiUtenti();
  }

  @override
  void didUpdateWidget(covariant ChatThreadScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stanza.id != widget.stanza.id) {
      _flusso = ref.read(spServiceProvider).messaggiStream(widget.stanza.id);
      _nomiUtenti = const {};
      _ultimoMessaggioVisto = null;
      _numeroMessaggi = 0;
      _segnaLetta();
      _caricaNomiUtenti();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Carica i nomi per il titolo delle stanze dirette; in caso di errore il
  /// titolo resta sull'uid finché `nomeStanzaChat` non trova un nome.
  Future<void> _caricaNomiUtenti() async {
    try {
      final utenti = await ref.read(spServiceProvider).getUtenti();
      if (!mounted) return;
      setState(() {
        _nomiUtenti = {
          for (final utente in utenti) utente.uid: _nomeUtente(utente),
        };
      });
    } catch (_) {
      if (!mounted) return;
      // I nomi restano assenti: il titolo usa l'uid o il nome del gruppo.
    }
  }

  /// Segna la stanza come letta all'apertura, senza bloccare la schermata.
  Future<void> _segnaLetta() async {
    try {
      await ref.read(spServiceProvider).segnaChatLetta(widget.stanza.id);
    } catch (_) {
      // La lettura non deve impedire di vedere o scrivere i messaggi.
      return;
    }
  }

  void _riprova() {
    setState(() {
      _flusso = ref.read(spServiceProvider).messaggiStream(widget.stanza.id);
      _ultimoMessaggioVisto = null;
      _numeroMessaggi = 0;
    });
  }

  /// Sposta la lista in fondo quando arrivano messaggi nuovi.
  void _programmaScroll(List<MessaggioChat> messaggi) {
    final ultimo = messaggi.isEmpty ? null : messaggi.last.id;
    if (ultimo == _ultimoMessaggioVisto && messaggi.length == _numeroMessaggi) {
      return;
    }

    final primoCaricamento = _ultimoMessaggioVisto == null;
    _ultimoMessaggioVisto = ultimo;
    _numeroMessaggi = messaggi.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final fondo = _scrollController.position.maxScrollExtent;
      if (primoCaricamento) {
        _scrollController.jumpTo(fondo);
      } else {
        _scrollController.animateTo(
          fondo,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Notifica i partecipanti della stanza dopo un invio riuscito.
  ///
  /// La notifica è un effetto collaterale: ogni errore viene ignorato per non
  /// bloccare l'invio del messaggio.
  Future<void> _notificaDestinatari() async {
    if (!mounted) return;
    try {
      final mittenteUid =
          ref.read(firebaseAuthProvider).currentUser?.uid ?? '';
      if (mittenteUid.isEmpty) return;

      final destinatari = destinatariNotificaChat(
        widget.stanza,
        mittenteUid: mittenteUid,
      );
      if (destinatari.isEmpty) return;

      final servizio = ref.read(spServiceProvider);
      for (final destinatario in destinatari) {
        try {
          await servizio.creaNotifica(
            utenteUid: destinatario,
            tipo: 'chat',
            titolo: 'Nuovo messaggio',
            testo: 'Hai ricevuto un nuovo messaggio in chat',
            targetTipo: 'chat',
            targetId: widget.stanza.id,
          );
        } catch (_) {
          // Errore ignorato: non deve influire sull'invio del messaggio.
        }
      }
    } catch (_) {
      // Errore ignorato: non deve influire sull'invio del messaggio.
    }
  }

  Future<void> _invia() async {
    final testo = _controller.text.trim();
    if (testo.isEmpty || _invioInCorso) return;

    setState(() => _invioInCorso = true);
    try {
      await ref.read(spServiceProvider).inviaMessaggio(widget.stanza.id, testo);
      if (!mounted) return;
      _controller.clear();
      setState(() => _invioInCorso = false);
      await _notificaDestinatari();
    } catch (errore) {
      if (!mounted) return;
      setState(() => _invioInCorso = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(messaggioErroreChat(errore))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uidCorrente = ref.watch(firebaseAuthProvider).currentUser?.uid ?? '';
    final titolo = nomeStanzaChat(
      widget.stanza,
      uidCorrente: uidCorrente,
      nomiUtenti: _nomiUtenti,
    );

    return Scaffold(
      appBar: AppBar(title: Text(titolo, overflow: TextOverflow.ellipsis)),
      body: Column(
        children: [
          Expanded(child: _corpoMessaggi(uidCorrente)),
          _composer(),
        ],
      ),
    );
  }

  Widget _corpoMessaggi(String uidCorrente) {
    return StreamBuilder<List<MessaggioChat>>(
      stream: _flusso,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _statoErrore(
            messaggioErroreChat(snapshot.error!, caricamento: true),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(key: Key('chat-caricamento')),
          );
        }

        final messaggi = snapshot.data ?? const <MessaggioChat>[];
        if (messaggi.isEmpty) {
          return const StatoCentrato(
            key: Key('chat-vuoto'),
            icona: Icons.chat_bubble_outline,
            titolo: 'Nessun messaggio',
            sottotitolo:
                'Scrivi il primo messaggio per iniziare la conversazione.',
          );
        }

        _programmaScroll(messaggi);
        final gruppi = raggruppaMessaggiPerGiorno(messaggi);

        return ListView(
          key: const Key('chat-lista-messaggi'),
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpazi.m,
            AppSpazi.s,
            AppSpazi.m,
            AppSpazi.m,
          ),
          children: [
            for (final gruppo in gruppi) ...[
              _IntestazioneGiorno(giorno: gruppo.giorno),
              for (final messaggio in gruppo.messaggi)
                _BollaMessaggio(
                  messaggio: messaggio,
                  proprio: messaggio.mittenteUid == uidCorrente,
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _statoErrore(String testo) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpazi.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvvisoErrore(key: const Key('chat-errore'), testo: testo),
              const SizedBox(height: AppSpazi.m),
              FilledButton.icon(
                key: const Key('chat-riprova'),
                onPressed: _riprova,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    final tema = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          border: Border(
            top: BorderSide(color: tema.colorScheme.outlineVariant),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpazi.xs,
          AppSpazi.xs,
          AppSpazi.xs,
          AppSpazi.xs,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Immagini disponibili dopo la configurazione R2',
                  child: IconButton(
                    key: const Key('chat-immagine'),
                    onPressed: null,
                    icon: const Icon(Icons.image_outlined),
                    tooltip: null,
                  ),
                ),
                const SizedBox(width: AppSpazi.xxs),
                Expanded(
                  child: TextField(
                    key: const Key('chat-messaggio'),
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un messaggio',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _controller,
                  builder: (context, valore, _) {
                    final puoInviare =
                        valore.text.trim().isNotEmpty && !_invioInCorso;
                    return IconButton.filled(
                      key: const Key('chat-invia'),
                      tooltip: 'Invia',
                      onPressed: puoInviare ? _invia : null,
                      icon: _invioInCorso
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Separatore centrato con l'etichetta del giorno.
class _IntestazioneGiorno extends StatelessWidget {
  const _IntestazioneGiorno({required this.giorno});

  final DateTime? giorno;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpazi.s),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpazi.s,
            vertical: AppSpazi.xxs,
          ),
          decoration: BoxDecoration(
            color: tema.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRaggi.chip),
          ),
          child: Text(
            etichettaGiornoChat(giorno),
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Bolla di un messaggio: propria a destra, altrui a sinistra.
class _BollaMessaggio extends StatelessWidget {
  const _BollaMessaggio({required this.messaggio, required this.proprio});

  final MessaggioChat messaggio;
  final bool proprio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final eliminato = messaggio.eliminato;
    final immagine = !eliminato && messaggio.tipo == 'immagine';

    final testo = eliminato
        ? 'Messaggio eliminato'
        : immagine
        ? 'Immagine'
        : (messaggio.testo?.trim() ?? '');

    final onSfondo = !proprio
        ? tema.colorScheme.onSurface
        : tema.colorScheme.onPrimaryContainer;

    return Align(
      alignment: proprio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: Key('chat-bolla-${messaggio.id}'),
        constraints: const BoxConstraints(maxWidth: 520),
        margin: EdgeInsets.only(
          bottom: AppSpazi.xs,
          left: proprio ? AppSpazi.xl : 0,
          right: proprio ? 0 : AppSpazi.xl,
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpazi.s,
          AppSpazi.xs,
          AppSpazi.s,
          AppSpazi.xxs,
        ),
        decoration: BoxDecoration(
          color: proprio
              ? tema.colorScheme.primaryContainer
              : tema.colorScheme.surface,
          border: proprio
              ? null
              : Border.all(color: tema.colorScheme.outlineVariant),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppRaggi.card),
            topRight: const Radius.circular(AppRaggi.card),
            bottomLeft: Radius.circular(proprio ? AppRaggi.card : 4),
            bottomRight: Radius.circular(proprio ? 4 : AppRaggi.card),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: proprio
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              testo,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: eliminato ? tema.colorScheme.onSurfaceVariant : onSfondo,
                fontStyle: eliminato ? FontStyle.italic : null,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              oraMessaggio(messaggio),
              style: tema.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
