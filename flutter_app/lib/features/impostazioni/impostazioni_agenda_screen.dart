// Impostazioni dell'agenda aziendale.
//
// I dati vivono in `impostazioni_agenda/{aziendaId}` e sono letti/scritti con
// `getImpostazioniAgenda()` e `salvaImpostazioniAgenda()`. Il modello, la
// validazione e i messaggi di errore sono puri, così restano verificabili
// senza Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/services/sp_service.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Costanti e funzioni pure (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Fuso orario predefinito dell'agenda.
const String fusoOrarioPredefinitoAgenda = 'Europe/Rome';

/// Canali disponibili per l'invio al cliente.
const List<String> canaliClienteAgenda = ['whatsapp', 'email', 'entrambi'];

/// Etichette italiane dei canali di invio al cliente.
const Map<String, String> etichetteCanaliClienteAgenda = {
  'whatsapp': 'WhatsApp',
  'email': 'Email',
  'entrambi': 'WhatsApp ed email',
};

/// Testo predefinito del messaggio al cliente.
///
/// Usa i segnaposto `{{data}}`, `{{ora}}`, `{{luogo}}`, `{{azienda}}` e
/// `{{riferimento}}`, sostituiti al momento dell'invio.
const String templateClientePredefinitoAgenda =
    'Buongiorno {{azienda}},\n'
    'le confermiamo l\'appuntamento del {{data}} alle {{ora}} presso '
    '{{luogo}}.\n'
    'Riferimento: {{riferimento}}.\n'
    'A presto.';

/// L'orario segue il formato `HH:MM` (24 ore)?
bool orarioValidoAgenda(String? orario) {
  final testo = (orario ?? '').trim();
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(testo);
}

/// Converte un intero strettamente positivo; `null` se non valido.
int? interoPositivoAgenda(String? testo) {
  final valore = int.tryParse((testo ?? '').trim());
  return (valore == null || valore <= 0) ? null : valore;
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio.
String messaggioErroreImpostazioniAgenda(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per cambiare l\'agenda. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Impostazioni agenda non disponibili. Riprova.';
    }
  }
  return 'Impostazioni agenda non disponibili. Controlla la connessione e '
      'riprova.';
}

// ---------------------------------------------------------------------------
// Modello delle impostazioni
// ---------------------------------------------------------------------------

/// Impostazioni dell'agenda aziendale, con i default del servizio.
@immutable
class ImpostazioniAgenda {
  const ImpostazioniAgenda({
    this.fusoOrario = fusoOrarioPredefinitoAgenda,
    this.anticipoMin = 1440,
    this.orarioInvioCliente = '18:00',
    this.canaleCliente = 'whatsapp',
    this.templateCliente = templateClientePredefinitoAgenda,
    this.slotDurataMin = 60,
    this.slotFinestraGiorni = 14,
    this.slotScadenzaGiorni = 7,
    this.allegatiMaxKb = 5120,
    this.allegatiMax = 10,
    this.mapsAttivo = true,
  });

  /// Impostazioni predefinite, usate quando il documento non esiste.
  static const ImpostazioniAgenda predefinite = ImpostazioniAgenda();

  /// Costruisce le impostazioni da un documento Firestore (anche `null`).
  ///
  /// I campi gestiti dal servizio passano da `normalizzaImpostazioniAgenda`,
  /// che garantisce valori validi; il template cliente è gestito qui perché
  /// non fa parte della normalizzazione.
  factory ImpostazioniAgenda.daMappa(Map<String, dynamic>? dati) {
    final valori = dati ?? const <String, dynamic>{};
    final normalizzate = normalizzaImpostazioniAgenda(valori);
    final template = (valori['template_cliente'] ??
            valori['templateCliente'] ??
            '')
        .toString()
        .trim();
    final canale = normalizzate['canale_cliente']?.toString() ?? 'whatsapp';

    return ImpostazioniAgenda(
      fusoOrario: normalizzate['fuso_orario'] as String,
      anticipoMin: normalizzate['anticipo_min'] as int,
      orarioInvioCliente: normalizzate['orario_invio_cliente'] as String,
      canaleCliente:
          canaliClienteAgenda.contains(canale) ? canale : 'whatsapp',
      templateCliente:
          template.isEmpty ? templateClientePredefinitoAgenda : template,
      slotDurataMin: normalizzate['slot_durata_min'] as int,
      slotFinestraGiorni: normalizzate['slot_finestra_giorni'] as int,
      slotScadenzaGiorni: normalizzate['slot_scadenza_giorni'] as int,
      allegatiMaxKb: normalizzate['allegati_max_kb'] as int,
      allegatiMax: normalizzate['allegati_max'] as int,
      mapsAttivo: normalizzate['maps_attivo'] as bool,
    );
  }

  final String fusoOrario;
  final int anticipoMin;
  final String orarioInvioCliente;
  final String canaleCliente;
  final String templateCliente;
  final int slotDurataMin;
  final int slotFinestraGiorni;
  final int slotScadenzaGiorni;
  final int allegatiMaxKb;
  final int allegatiMax;
  final bool mapsAttivo;

  /// Copia con i campi indicati sostituiti.
  ImpostazioniAgenda copiaCon({
    String? fusoOrario,
    int? anticipoMin,
    String? orarioInvioCliente,
    String? canaleCliente,
    String? templateCliente,
    int? slotDurataMin,
    int? slotFinestraGiorni,
    int? slotScadenzaGiorni,
    int? allegatiMaxKb,
    int? allegatiMax,
    bool? mapsAttivo,
  }) {
    return ImpostazioniAgenda(
      fusoOrario: fusoOrario ?? this.fusoOrario,
      anticipoMin: anticipoMin ?? this.anticipoMin,
      orarioInvioCliente: orarioInvioCliente ?? this.orarioInvioCliente,
      canaleCliente: canaleCliente ?? this.canaleCliente,
      templateCliente: templateCliente ?? this.templateCliente,
      slotDurataMin: slotDurataMin ?? this.slotDurataMin,
      slotFinestraGiorni: slotFinestraGiorni ?? this.slotFinestraGiorni,
      slotScadenzaGiorni: slotScadenzaGiorni ?? this.slotScadenzaGiorni,
      allegatiMaxKb: allegatiMaxKb ?? this.allegatiMaxKb,
      allegatiMax: allegatiMax ?? this.allegatiMax,
      mapsAttivo: mapsAttivo ?? this.mapsAttivo,
    );
  }

  /// Mappa da scrivere su Firestore con merge (chiavi snake_case).
  Map<String, dynamic> aMappa() {
    return {
      'fuso_orario': fusoOrario.trim(),
      'anticipo_min': anticipoMin,
      'orario_invio_cliente': orarioInvioCliente.trim(),
      'canale_cliente': canaleCliente,
      'template_cliente': templateCliente.trim(),
      'slot_durata_min': slotDurataMin,
      'slot_finestra_giorni': slotFinestraGiorni,
      'slot_scadenza_giorni': slotScadenzaGiorni,
      'allegati_max_kb': allegatiMaxKb,
      'allegati_max': allegatiMax,
      'maps_attivo': mapsAttivo,
    };
  }
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata `/impostazioni/agenda`: orari, template e slot dell'agenda.
class ImpostazioniAgendaScreen extends ConsumerStatefulWidget {
  const ImpostazioniAgendaScreen({super.key});

  @override
  ConsumerState<ImpostazioniAgendaScreen> createState() =>
      _ImpostazioniAgendaScreenState();
}

class _ImpostazioniAgendaScreenState
    extends ConsumerState<ImpostazioniAgendaScreen> {
  ImpostazioniAgenda _impostazioni = ImpostazioniAgenda.predefinite;
  bool _caricamento = true;
  bool _salvataggio = false;
  Object? _errore;
  String? _erroreSalvataggio;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e legge le impostazioni dell'agenda.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
      _erroreSalvataggio = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final dati = await servizio.getImpostazioniAgenda();
      if (!mounted) return;
      setState(() {
        _impostazioni = ImpostazioniAgenda.daMappa(dati);
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

  /// Salva le impostazioni validate dal corpo e mostra la conferma.
  Future<void> _salva(ImpostazioniAgenda impostazioni) async {
    setState(() {
      _impostazioni = impostazioni;
      _salvataggio = true;
      _erroreSalvataggio = null;
    });
    try {
      await ref
          .read(spServiceProvider)
          .salvaImpostazioniAgenda(impostazioni.aMappa());
      if (!mounted) return;
      setState(() => _salvataggio = false);
      _avviso('Impostazioni agenda salvate');
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _salvataggio = false;
        _erroreSalvataggio = messaggioErroreImpostazioniAgenda(errore);
      });
      _avviso(messaggioErroreImpostazioniAgenda(errore));
    }
  }

  void _avviso(String testo) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(testo)));
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

        return Padding(
          padding: EdgeInsets.all(orizzontale),
          child: CorpoImpostazioniAgenda(
            impostazioni: _impostazioni,
            caricamento: _caricamento,
            salvataggio: _salvataggio,
            errore: _errore,
            messaggioErroreSalvataggio: _erroreSalvataggio,
            onRiprova: _carica,
            onSalva: _salva,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Contenuto della schermata, senza provider: usato anche dai widget test.
class CorpoImpostazioniAgenda extends StatefulWidget {
  const CorpoImpostazioniAgenda({
    super.key,
    required this.impostazioni,
    required this.onSalva,
    required this.onRiprova,
    this.caricamento = false,
    this.salvataggio = false,
    this.errore,
    this.messaggioErroreSalvataggio,
  });

  final ImpostazioniAgenda impostazioni;

  /// Riceve le impostazioni solo dopo la validazione dei campi.
  final void Function(ImpostazioniAgenda) onSalva;
  final VoidCallback onRiprova;
  final bool caricamento;
  final bool salvataggio;
  final Object? errore;

  /// Messaggio di errore del salvataggio, già in italiano.
  final String? messaggioErroreSalvataggio;

  @override
  State<CorpoImpostazioniAgenda> createState() =>
      _CorpoImpostazioniAgendaState();
}

class _CorpoImpostazioniAgendaState extends State<CorpoImpostazioniAgenda> {
  late final TextEditingController _fuso;
  late final TextEditingController _anticipo;
  late final TextEditingController _orario;
  late final TextEditingController _template;
  late final TextEditingController _slotDurata;
  late final TextEditingController _slotFinestra;
  late final TextEditingController _slotScadenza;
  late final TextEditingController _allegatiKb;
  late final TextEditingController _allegatiNum;

  late String _canale;
  late bool _maps;
  String? _erroreValidazione;

  @override
  void initState() {
    super.initState();
    final dati = widget.impostazioni;
    _fuso = TextEditingController(text: dati.fusoOrario);
    _anticipo = TextEditingController(text: '${dati.anticipoMin}');
    _orario = TextEditingController(text: dati.orarioInvioCliente);
    _template = TextEditingController(text: dati.templateCliente);
    _slotDurata = TextEditingController(text: '${dati.slotDurataMin}');
    _slotFinestra = TextEditingController(text: '${dati.slotFinestraGiorni}');
    _slotScadenza = TextEditingController(text: '${dati.slotScadenzaGiorni}');
    _allegatiKb = TextEditingController(text: '${dati.allegatiMaxKb}');
    _allegatiNum = TextEditingController(text: '${dati.allegatiMax}');
    _canale = dati.canaleCliente;
    _maps = dati.mapsAttivo;
  }

  @override
  void didUpdateWidget(CorpoImpostazioniAgenda vecchio) {
    super.didUpdateWidget(vecchio);
    final dati = widget.impostazioni;
    _sincronizza(_fuso, dati.fusoOrario);
    _sincronizza(_anticipo, '${dati.anticipoMin}');
    _sincronizza(_orario, dati.orarioInvioCliente);
    _sincronizza(_template, dati.templateCliente);
    _sincronizza(_slotDurata, '${dati.slotDurataMin}');
    _sincronizza(_slotFinestra, '${dati.slotFinestraGiorni}');
    _sincronizza(_slotScadenza, '${dati.slotScadenzaGiorni}');
    _sincronizza(_allegatiKb, '${dati.allegatiMaxKb}');
    _sincronizza(_allegatiNum, '${dati.allegatiMax}');
    _canale = dati.canaleCliente;
    _maps = dati.mapsAttivo;
  }

  /// Aggiorna il controller solo se il testo è davvero cambiato, così il
  /// cursore non salta mentre l'utente scrive.
  void _sincronizza(TextEditingController controller, String valore) {
    if (controller.text == valore) return;
    controller.value = TextEditingValue(
      text: valore,
      selection: TextSelection.collapsed(offset: valore.length),
    );
  }

  @override
  void dispose() {
    _fuso.dispose();
    _anticipo.dispose();
    _orario.dispose();
    _template.dispose();
    _slotDurata.dispose();
    _slotFinestra.dispose();
    _slotScadenza.dispose();
    _allegatiKb.dispose();
    _allegatiNum.dispose();
    super.dispose();
  }

  /// Apre il selettore dell'ora e riporta il risultato nel campo.
  Future<void> _scegliOra() async {
    final base = orarioValidoAgenda(_orario.text)
        ? _orario.text.trim()
        : widget.impostazioni.orarioInvioCliente;
    final parti = base.split(':');
    final scelta = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parti[0]) ?? 18,
        minute: int.tryParse(parti[1]) ?? 0,
      ),
      helpText: 'Scegli l\'orario di invio',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (scelta == null) return;
    final ora = scelta.hour.toString().padLeft(2, '0');
    final minuti = scelta.minute.toString().padLeft(2, '0');
    setState(() => _orario.text = '$ora:$minuti');
  }

  /// Controlla i campi e, se validi, passa le impostazioni a `onSalva`.
  void _salva() {
    final fuso = _fuso.text.trim();
    if (fuso.isEmpty) {
      setState(() => _erroreValidazione = 'Indica il fuso orario.');
      return;
    }
    if (!orarioValidoAgenda(_orario.text)) {
      setState(
        () => _erroreValidazione =
            'Inserisci l\'orario di invio nel formato HH:MM.',
      );
      return;
    }

    final anticipo = interoPositivoAgenda(_anticipo.text);
    if (anticipo == null) {
      setState(
        () => _erroreValidazione =
            'L\'anticipo del promemoria deve essere un numero maggiore di zero.',
      );
      return;
    }
    final slotDurata = interoPositivoAgenda(_slotDurata.text);
    if (slotDurata == null) {
      setState(
        () => _erroreValidazione =
            'La durata degli slot deve essere un numero maggiore di zero.',
      );
      return;
    }
    final slotFinestra = interoPositivoAgenda(_slotFinestra.text);
    if (slotFinestra == null) {
      setState(
        () => _erroreValidazione =
            'La finestra degli slot deve essere un numero maggiore di zero.',
      );
      return;
    }
    final slotScadenza = interoPositivoAgenda(_slotScadenza.text);
    if (slotScadenza == null) {
      setState(
        () => _erroreValidazione =
            'La scadenza dei link deve essere un numero maggiore di zero.',
      );
      return;
    }
    final allegatiKb = interoPositivoAgenda(_allegatiKb.text);
    if (allegatiKb == null) {
      setState(
        () => _erroreValidazione =
            'Il peso massimo degli allegati deve essere maggiore di zero.',
      );
      return;
    }
    final allegatiNum = interoPositivoAgenda(_allegatiNum.text);
    if (allegatiNum == null) {
      setState(
        () => _erroreValidazione =
            'Il numero massimo di allegati deve essere maggiore di zero.',
      );
      return;
    }

    setState(() => _erroreValidazione = null);
    widget.onSalva(
      widget.impostazioni.copiaCon(
        fusoOrario: fuso,
        anticipoMin: anticipo,
        orarioInvioCliente: _orario.text.trim(),
        canaleCliente: _canale,
        templateCliente: _template.text,
        slotDurataMin: slotDurata,
        slotFinestraGiorni: slotFinestra,
        slotScadenzaGiorni: slotScadenza,
        allegatiMaxKb: allegatiKb,
        allegatiMax: allegatiNum,
        mapsAttivo: _maps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caricamento) {
      return const Center(
        key: Key('agenda-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (widget.errore != null) {
      return StatoCentrato(
        key: const Key('agenda-errore-caricamento'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Agenda non disponibile',
        sottotitolo: messaggioErroreImpostazioniAgenda(widget.errore!),
        azione: OutlinedButton.icon(
          key: const Key('agenda-riprova'),
          onPressed: widget.onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final tema = Theme.of(context);
    final messaggioErrore =
        _erroreValidazione ?? widget.messaggioErroreSalvataggio;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (messaggioErrore != null) ...[
                AvvisoErrore(
                  key: const Key('agenda-errore'),
                  testo: messaggioErrore,
                ),
                const SizedBox(height: AppSpazi.s),
              ],
              _SezioneCard(
                chiave: const Key('agenda-sezione-agenda'),
                titolo: 'Agenda',
                icona: Icons.event_available_outlined,
                figli: [
                  TextField(
                    key: const Key('agenda-fuso'),
                    controller: _fuso,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Fuso orario',
                      hintText: fusoOrarioPredefinitoAgenda,
                      helperText: 'Formato IANA, ad esempio Europe/Rome.',
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  TextField(
                    key: const Key('agenda-anticipo'),
                    controller: _anticipo,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Anticipo promemoria (minuti)',
                      helperText: 'Quanti minuti prima avvisare il commerciale.',
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  TextField(
                    key: const Key('agenda-orario-invio'),
                    controller: _orario,
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Orario invio al cliente',
                      hintText: 'HH:MM',
                      helperText: 'Orario in cui parte il messaggio al cliente.',
                      suffixIcon: IconButton(
                        tooltip: 'Scegli orario',
                        onPressed: _scegliOra,
                        icon: const Icon(Icons.schedule),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  DropdownButtonFormField<String>(
                    key: const Key('agenda-canale'),
                    initialValue: _canale,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Canale cliente',
                    ),
                    items: [
                      for (final canale in canaliClienteAgenda)
                        DropdownMenuItem(
                          value: canale,
                          child: Text(
                            etichetteCanaliClienteAgenda[canale] ?? canale,
                          ),
                        ),
                    ],
                    onChanged: (valore) {
                      if (valore != null) setState(() => _canale = valore);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _SezioneCard(
                chiave: const Key('agenda-sezione-template'),
                titolo: 'Template cliente',
                icona: Icons.sms_outlined,
                figli: [
                  Text(
                    'Segnaposto disponibili: {{data}}, {{ora}}, {{luogo}}, '
                    '{{azienda}}, {{riferimento}}.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  TextField(
                    key: const Key('agenda-template'),
                    controller: _template,
                    minLines: 5,
                    maxLines: 10,
                    keyboardType: TextInputType.multiline,
                    decoration: const InputDecoration(
                      labelText: 'Messaggio al cliente',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _SezioneCard(
                chiave: const Key('agenda-sezione-slot'),
                titolo: 'Slot',
                icona: Icons.schedule_outlined,
                figli: [
                  TextField(
                    key: const Key('agenda-slot-durata'),
                    controller: _slotDurata,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Durata slot (minuti)',
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  TextField(
                    key: const Key('agenda-slot-finestra'),
                    controller: _slotFinestra,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Finestra prenotabile (giorni)',
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  TextField(
                    key: const Key('agenda-slot-scadenza'),
                    controller: _slotScadenza,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Scadenza link (giorni)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _SezioneCard(
                chiave: const Key('agenda-sezione-allegati'),
                titolo: 'Allegati',
                icona: Icons.attach_file,
                figli: [
                  TextField(
                    key: const Key('agenda-allegati-kb'),
                    controller: _allegatiKb,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Peso massimo per allegato (KB)',
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  TextField(
                    key: const Key('agenda-allegati-num'),
                    controller: _allegatiNum,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Numero massimo di allegati',
                    ),
                  ),
                  const SizedBox(height: AppSpazi.xs),
                  SwitchListTile(
                    key: const Key('agenda-maps'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Apri la posizione in Maps'),
                    subtitle: const Text(
                      'Nel messaggio al cliente aggiungi il collegamento '
                      'alla mappa dell\'appuntamento.',
                    ),
                    value: _maps,
                    onChanged: (valore) => setState(() => _maps = valore),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.l),
              FilledButton.icon(
                key: const Key('agenda-salva'),
                onPressed: widget.salvataggio ? null : _salva,
                icon: widget.salvataggio
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.salvataggio ? 'Salvataggio…' : 'Salva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card di una sezione con intestazione (icona + titolo).
class _SezioneCard extends StatelessWidget {
  const _SezioneCard({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.figli,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: chiave,
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, size: 20, color: tema.colorScheme.primary),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  child: Text(titolo, style: tema.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.s),
            ...figli,
          ],
        ),
      ),
    );
  }
}
