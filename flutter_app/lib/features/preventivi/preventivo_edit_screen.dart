// Editor del preventivo (F12b-1) con salvataggio su Firestore (F12b-2a),
// caricamento per id e revisioni (F12b-2b).
//
// Contiene i dati generali (cliente, stato), le note, lo sconto generale e le
// righe modificabili, con il riepilogo dei totali. Il pulsante "Salva
// preventivo" crea o aggiorna il documento tramite `SpService`; con
// `preventivoId` il documento viene letto da Firestore all'avvio e, se è
// revisionabile, si può creare una nuova revisione.
//
// I totali usano le funzioni pure del modello (`totaleRiga`, `calcolaTotali`)
// per restare identici alla vecchia app.

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/cliente.dart';
import '../../data/models/preventivo.dart';
import '../../data/models/prodotto.dart';
import '../../data/panieri.dart';
import '../../data/services/preventivo_pdf.dart';
import '../../state/azienda_providers.dart';
import '../catalogo/catalogo_screen.dart'
    show etichettaPaniere, formattaPrezzo, prezzoDaTesto;
import 'preventivi_screen.dart'
    show etichettaStatoPreventivo, numeroVisualizzatoPreventivo;

// ---------------------------------------------------------------------------
// Funzioni pure: formati, stati, opzioni e totali (verificabili senza
// Firebase né UI)
// ---------------------------------------------------------------------------

/// Stati selezionabili a mano nell'editor.
///
/// `revisionato` è escluso: nasce solo dalla creazione di una revisione.
const Map<String, String> statiSelezionabiliPreventivo = {
  'bozza': 'Bozza',
  'inviato': 'Inviato',
  'accettato': 'Accettato',
  'rifiutato': 'Rifiutato',
};

/// Numero scritto per l'editor: virgola decimale italiana, senza decimali inutili.
///
/// Es. `2` → `"2"`, `1.5` → `"1,5"`, `null` → `""`.
String testoNumeroPreventivo(num? valore) {
  if (valore == null) return '';
  final doppio = valore.toDouble();
  if (doppio == doppio.roundToDouble()) return doppio.toInt().toString();
  return NumberFormat('#,##0.##', 'it_IT').format(doppio);
}

/// Converte il testo di un campo numerico in numero, `0` se vuoto o non valido.
///
/// Accetta la virgola decimale italiana (riusa `prezzoDaTesto` del catalogo).
double numeroPreventivoDaTesto(String? valore) => prezzoDaTesto(valore) ?? 0;

/// Costruisce una [PreventivoRiga] dai campi dell'editor.
///
/// Lo sconto di riga è in percentuale: il valore assoluto (`scontoVal`) viene
/// calcolato come `prezzo * qty * scontoPerc / 100` per restare coerente con
/// `totaleRiga` del modello. L'IVA vuota ricade sul default 22%.
PreventivoRiga rigaPreventivoDaCampi({
  String? prodottoId,
  String? codice,
  String? um,
  String? nome,
  String? quantita,
  String? prezzo,
  String? scontoPerc,
  String? ivaPerc,
  String? paniereId,
  String? paniereNome,
}) {
  final prezzoUnitario = numeroPreventivoDaTesto(prezzo);
  final qty = numeroPreventivoDaTesto(quantita);
  final sconto = numeroPreventivoDaTesto(scontoPerc).clamp(0.0, 100.0);
  // IVA vuota = default 22%; uno zero esplicito resta zero (IVA esente).
  final testoIva = (ivaPerc ?? '').trim();
  final iva = testoIva.isEmpty ? 22.0 : numeroPreventivoDaTesto(testoIva);
  final scontoVal = prezzoUnitario * qty * sconto / 100;
  final testoNome = (nome ?? '').trim();

  return PreventivoRiga(
    prodottoId: prodottoId,
    codice: codice,
    um: um,
    nome: testoNome.isEmpty ? null : testoNome,
    prezzo: prezzoUnitario,
    qty: qty,
    scontoPerc: sconto,
    scontoVal: scontoVal,
    ivaPerc: iva,
    paniereId: paniereId,
    paniereNome: paniereNome,
  );
}

/// Riga compilata con un prodotto del catalogo.
///
/// Imposta id prodotto, nome e prezzo del [prodotto], unità `pz`, e azzera
/// codice e paniere. Quantità, sconto e IVA restano quelli della [riga] di
/// partenza.
PreventivoRiga rigaConProdotto(PreventivoRiga riga, Prodotto prodotto) {
  return rigaPreventivoDaCampi(
    prodottoId: prodotto.id,
    codice: null,
    um: 'pz',
    paniereId: null,
    paniereNome: null,
    nome: prodotto.nome ?? '',
    prezzo: prodotto.prezzo == null
        ? ''
        : testoNumeroPreventivo(prodotto.prezzo),
    quantita: testoNumeroPreventivo(riga.qty),
    scontoPerc: testoNumeroPreventivo(riga.scontoPerc),
    ivaPerc: testoNumeroPreventivo(riga.ivaPerc),
  );
}

/// Etichetta del paniere per una riga figlia dell'editor.
///
/// Ritorna `Paniere: <nome>` quando la riga ha un [PreventivoRiga.paniereNome],
/// altrimenti `null` (riga normale). Gli spazi attorno al nome vengono
/// ignorati: un nome fatto di soli spazi vale come assente.
String? etichettaPaniereRiga(PreventivoRiga riga) {
  final nome = (riga.paniereNome ?? '').trim();
  if (nome.isEmpty) return null;
  return 'Paniere: $nome';
}

/// Sconto globale in euro a partire dalla percentuale e dal subtotale righe.
double scontoGlobaleEuroDaPercentuale(double subtotale, double percentuale) {
  return subtotale * percentuale.clamp(0.0, 100.0) / 100;
}

/// Totali dell'editor: sconto generale in percentuale convertito in euro e
/// passato a `calcolaTotali`, come fa la vecchia app.
PreventivoTotali totaliEditorPreventivo(
  List<PreventivoRiga> righe, {
  String? scontoGenerale,
}) {
  final subtotale = righe.fold<double>(0, (somma, r) => somma + totaleRiga(r));
  final percentuale = numeroPreventivoDaTesto(scontoGenerale);
  return calcolaTotali(
    righe,
    scontoGlobaleEuro: scontoGlobaleEuroDaPercentuale(subtotale, percentuale),
  );
}

/// Nome del cliente da salvare nel campo denormalizzato `cliente_nome`.
///
/// Usa il nome del cliente selezionato se è tra i [clienti] caricati; altrimenti
/// ricade su [fallback] (es. il `clienteNome` del preventivo in modifica), così
/// il dato esistente non viene perso quando l'elenco clienti non è disponibile.
String nomeClientePreventivoDaSelezione(
  List<Cliente> clienti,
  String? clienteId, {
  String? fallback,
}) {
  final id = (clienteId ?? '').trim();
  if (id.isNotEmpty) {
    for (final cliente in clienti) {
      if (cliente.id != id) continue;
      final nome = cliente.nome?.trim() ?? '';
      if (nome.isNotEmpty) return nome;
      break;
    }
  }
  return (fallback ?? '').trim();
}

/// Payload del preventivo con i campi Firestore (snake_case, come la vecchia
/// app): dati generali, righe e totali calcolati dalle righe stesse.
///
/// [sconto] è la percentuale dello sconto generale. I totali usano
/// `calcolaTotali`, quindi coincidono con quelli mostrati nel riepilogo.
Map<String, dynamic> payloadPreventivoDaEditor({
  String? clienteId,
  String? clienteNome,
  String stato = 'bozza',
  String? note,
  num sconto = 0,
  List<PreventivoRiga> righe = const [],
}) {
  final percentuale = sconto.toDouble();
  final subtotale = righe.fold<double>(0, (somma, r) => somma + totaleRiga(r));
  final totali = calcolaTotali(
    righe,
    scontoGlobaleEuro: scontoGlobaleEuroDaPercentuale(subtotale, percentuale),
  );
  final idCliente = (clienteId ?? '').trim();
  final statoNormalizzato = stato.trim().toLowerCase();

  return {
    'cliente_id': idCliente.isEmpty ? null : idCliente,
    'cliente_nome': (clienteNome ?? '').trim(),
    'stato': statoNormalizzato.isEmpty ? 'bozza' : statoNormalizzato,
    'note': (note ?? '').trim(),
    'sconto': percentuale,
    'righe': [for (final riga in righe) riga.toMap()],
    'subtotale': totali.subtotale,
    'imp_sconto': totali.impSconto,
    'imponibile': totali.imponibile,
    'iva': totali.iva,
    'totale_iva': totali.totaleIva,
  };
}

/// Adatta il payload snake_case alle chiavi attese da `SpService`
/// (`inserisciPreventivo`/`aggiornaPreventivo` leggono camelCase, come la
/// vecchia app) senza duplicare la costruzione dei dati.
Map<String, dynamic> datiServizioPreventivo(Map<String, dynamic> payload) {
  return {
    'clienteId': payload['cliente_id'],
    'clienteNome': payload['cliente_nome'],
    'stato': payload['stato'],
    'note': payload['note'],
    'sconto': payload['sconto'],
    'righe': payload['righe'],
    'subtotale': payload['subtotale'],
    'impSconto': payload['imp_sconto'],
    'imponibile': payload['imponibile'],
    'iva': payload['iva'],
    'totaleIva': payload['totale_iva'],
  };
}

/// Messaggio in italiano per gli errori di salvataggio del preventivo.
String messaggioErroreSalvataggioPreventivo(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per salvare il preventivo. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente: il preventivo non è stato salvato. '
            'Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Salvataggio non riuscito. Riprova.';
    }
  }
  return 'Salvataggio non riuscito. Controlla la connessione e riprova.';
}

/// Nome del cliente per la tendina, con fallback per i documenti senza nome.
String nomeVisualizzatoClientePreventivo(Cliente cliente) {
  final nome = cliente.nome?.trim() ?? '';
  return nome.isEmpty ? '(senza nome)' : nome;
}

/// Opzioni della tendina cliente (`id` → nome).
///
/// Se [idSelezionato] non è più tra i [clienti] caricati (cliente eliminato o
/// non ancora caricato) viene aggiunto con [nomeSelezionato] per non perdere
/// il dato del preventivo in modifica.
Map<String, String> opzioniClientiPreventivo(
  List<Cliente> clienti, {
  String? idSelezionato,
  String? nomeSelezionato,
}) {
  final opzioni = <String, String>{
    for (final cliente in clienti)
      cliente.id: nomeVisualizzatoClientePreventivo(cliente),
  };
  final id = (idSelezionato ?? '').trim();
  if (id.isNotEmpty && !opzioni.containsKey(id)) {
    final nome = (nomeSelezionato ?? '').trim();
    opzioni[id] = nome.isEmpty ? '(cliente non disponibile)' : nome;
  }
  return opzioni;
}

/// Opzioni della tendina stato, includendo [corrente] se non è tra quelle
/// standard (es. `revisionato`) per non alterare i dati esistenti.
Map<String, String> opzioniStatoPreventivo(String corrente) {
  final opzioni = Map<String, String>.of(statiSelezionabiliPreventivo);
  final chiave = corrente.trim().toLowerCase();
  if (chiave.isNotEmpty && !opzioni.containsKey(chiave)) {
    opzioni[chiave] = etichettaStatoPreventivo(chiave);
  }
  return opzioni;
}

/// Se da [stato] si può creare una revisione.
///
/// Replica `puoRevisionare` della vecchia app (`js/app.js`): solo i preventivi
/// inviati, accettati o rifiutati si revisionano. Bozza e revisionato no.
bool puoCreareRevisione(String stato) {
  const revisionabili = {'inviato', 'accettato', 'rifiutato'};
  return revisionabili.contains(stato.trim().toLowerCase());
}

/// Messaggio in italiano per un preventivo che non si riesce a caricare.
///
/// [errore] `null` significa documento inesistente (`getPreventivo` ha
/// restituito `null`).
String messaggioErroreCaricamentoPreventivo(Object? errore) {
  if (errore == null) {
    return 'Il preventivo non esiste o non è più disponibile.';
  }
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per leggere il preventivo. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente: il preventivo non è disponibile. '
            'Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Preventivo non disponibile. Riprova.';
    }
  }
  return 'Preventivo non disponibile. Controlla la connessione e riprova.';
}

/// Messaggio in italiano per gli errori di caricamento dei clienti nell'editor.
String messaggioErroreClientiPreventivo(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per leggere i clienti. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente: i clienti non sono disponibili. '
            'Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Clienti non disponibili. Riprova.';
    }
  }
  return 'Clienti non disponibili. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Editor di un preventivo: dati generali, righe e riepilogo totali.
///
/// Con [iniziale] valorizzato mostra numero e revisione del documento.
/// Con [preventivoId] (rotta `/preventivi/:id`) legge il documento da Firestore
/// all'avvio, con stati di caricamento ed errore. Senza entrambi prepara un
/// preventivo nuovo (nessuna riga iniziale).
class PreventivoEditScreen extends ConsumerStatefulWidget {
  const PreventivoEditScreen({super.key, this.iniziale, this.preventivoId});

  /// Preventivo da modificare; `null` per crearne uno nuovo.
  final Preventivo? iniziale;

  /// Id del preventivo da caricare da Firestore (rotta `/preventivi/:id`).
  ///
  /// Ignorato se [iniziale] è valorizzato.
  final String? preventivoId;

  @override
  ConsumerState<PreventivoEditScreen> createState() =>
      _PreventivoEditScreenState();
}

class _PreventivoEditScreenState extends ConsumerState<PreventivoEditScreen> {
  final _note = TextEditingController();
  final _scontoGenerale = TextEditingController();

  final List<_RigaPreventivo> _righe = [];

  List<Cliente> _clienti = const [];
  bool _caricandoClienti = true;
  Object? _erroreClienti;

  /// Prodotti dell'azienda attiva, usati per inserire righe dal catalogo.
  List<Prodotto> _prodotti = const [];
  bool _caricandoProdotti = true;
  Object? _erroreProdotti;

  String? _clienteId;
  String _stato = 'bozza';

  /// Documento aperto in modifica (`null` per un preventivo nuovo).
  Preventivo? _preventivo;

  /// Caricamento del preventivo da `preventivoId` in corso.
  bool _caricandoPreventivo = false;

  /// Errore di caricamento; `null` con [_nonTrovato] significa documento
  /// inesistente.
  Object? _errorePreventivo;
  bool _nonTrovato = false;

  /// Salvataggio in corso: disabilita il pulsante e mostra il caricamento.
  bool _salvataggio = false;

  /// Errore dell'ultimo salvataggio, mostrato sotto il pulsante.
  Object? _erroreSalvataggio;

  /// Creazione di una revisione in corso.
  bool _revisione = false;

  /// Errore dell'ultima creazione di revisione.
  Object? _erroreRevisione;

  /// Generazione e condivisione del PDF in corso.
  bool _generazionePdf = false;

  @override
  void initState() {
    super.initState();
    final iniziale = widget.iniziale;
    if (iniziale != null) {
      _popolaCampi(iniziale);
    } else {
      _stato = 'bozza';
      final id = (widget.preventivoId ?? '').trim();
      if (id.isNotEmpty) {
        _caricandoPreventivo = true;
        _caricaPreventivo();
      }
    }
    _caricaClienti();
    _caricaProdotti();
  }

  @override
  void dispose() {
    _note.dispose();
    _scontoGenerale.dispose();
    for (final riga in _righe) {
      riga.dispose();
    }
    super.dispose();
  }

  /// Copia i campi del [preventivo] nei controller dell'editor.
  ///
  /// Chiamata all'avvio, quando l'elenco righe è ancora vuoto; chi la usa
  /// dentro `setState` non deve chiamare `setState` a sua volta.
  void _popolaCampi(Preventivo preventivo) {
    _preventivo = preventivo;
    _clienteId = preventivo.clienteId;
    _stato = preventivo.stato.trim().toLowerCase();
    if (_stato.isEmpty) _stato = 'bozza';
    _note.text = preventivo.note ?? '';
    _scontoGenerale.text = testoNumeroPreventivo(preventivo.sconto);
    _righe.clear();
    for (final riga in preventivo.righe) {
      _righe.add(_RigaPreventivo(riga: riga));
    }
  }

  /// Carica da Firestore il preventivo `widget.preventivoId`.
  ///
  /// Chi la chiama imposta prima `_caricandoPreventivo` (initState o
  /// "Riprova"); un id inesistente o un errore (permessi, rete) diventano lo
  /// stato di errore con "Riprova".
  Future<void> _caricaPreventivo() async {
    final id = (widget.preventivoId ?? '').trim();
    if (id.isEmpty) return;

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final preventivo = await servizio.getPreventivo(id);
      if (!mounted) return;
      setState(() {
        if (preventivo == null) {
          _nonTrovato = true;
        } else {
          _popolaCampi(preventivo);
        }
        _caricandoPreventivo = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errorePreventivo = errore;
        _caricandoPreventivo = false;
      });
    }
  }

  /// Ripete il caricamento del preventivo dopo un errore.
  void _riprovaCaricamentoPreventivo() {
    setState(() {
      _caricandoPreventivo = true;
      _errorePreventivo = null;
      _nonTrovato = false;
    });
    _caricaPreventivo();
  }

  /// Carica i clienti dell'azienda attiva; l'editor resta usabile anche se la
  /// lettura fallisce (es. permessi o rete assente).
  Future<void> _caricaClienti() async {
    setState(() {
      _caricandoClienti = true;
      _erroreClienti = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final clienti = await servizio.getClienti();
      if (!mounted) return;
      setState(() {
        _clienti = clienti;
        _caricandoClienti = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _erroreClienti = errore;
        _caricandoClienti = false;
      });
    }
  }

  /// Carica i prodotti dell'azienda attiva per l'inserimento dal catalogo.
  ///
  /// Come per i clienti, un errore (permessi o rete) non blocca l'editor: la
  /// sezione righe mostra "Catalogo non disponibile" con "Riprova".
  Future<void> _caricaProdotti() async {
    setState(() {
      _caricandoProdotti = true;
      _erroreProdotti = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final prodotti = await servizio.getProdotti();
      if (!mounted) return;
      setState(() {
        _prodotti = prodotti;
        _caricandoProdotti = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _erroreProdotti = errore;
        _caricandoProdotti = false;
      });
    }
  }

  void _aggiungiRiga() {
    setState(() => _righe.add(_RigaPreventivo()));
  }

  void _rimuoviRiga(_RigaPreventivo riga) {
    setState(() => _righe.remove(riga));
    // I controller vengono liberati dopo il rebuild che rimuove i campi.
    WidgetsBinding.instance.addPostFrameCallback((_) => riga.dispose());
  }

  /// Apre la scelta di un prodotto dal catalogo e lo inserisce nelle righe.
  Future<void> _apriCatalogoProdotti() async {
    final scelto = await showModalBottomSheet<Prodotto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CatalogoProdottiSheet(prodotti: _prodotti),
    );
    if (scelto == null || !mounted) return;
    _inserisciProdottoNelPreventivo(scelto);
  }

  /// Apre il catalogo per compilare la [riga] scelta.
  ///
  /// Se il prodotto è un paniere, la riga viene sostituita dal padre e dai
  /// figli (riusa `inserisciPaniere`); altrimenti la riga viene compilata con
  /// nome, prezzo e unità del prodotto. In entrambi i casi avvisa se qualche
  /// sotto-prodotto non è più disponibile.
  Future<void> _apriCatalogoPerRiga(_RigaPreventivo riga) async {
    final scelto = await showModalBottomSheet<Prodotto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CatalogoProdottiSheet(prodotti: _prodotti),
    );
    if (scelto == null || !mounted) return;

    final figli = figliDelPaniere(scelto, _prodotti);
    final mancanti = figliMancanti(scelto, _prodotti);

    if (figli.isEmpty) {
      setState(() => riga.applicaProdotto(scelto));
    } else {
      final modello = [
        for (final altra in _righe)
          if (!identical(altra, riga)) altra.toRiga(),
      ];
      final nuove = inserisciPaniere(
        padre: scelto,
        figli: figli,
        righe: modello,
      );

      final vecchie = List<_RigaPreventivo>.of(_righe);
      setState(() {
        _righe
          ..clear()
          ..addAll([for (final nuova in nuove) _RigaPreventivo(riga: nuova)]);
      });
      // I vecchi controller vengono liberati dopo il frame che li ha rimossi.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final vecchia in vecchie) {
          vecchia.dispose();
        }
      });
    }

    if (mancanti.isNotEmpty) {
      final sostantivo = mancanti.length == 1
          ? 'sotto-prodotto'
          : 'sotto-prodotti';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${mancanti.length} $sostantivo non sono più disponibili '
            'e ${mancanti.length == 1 ? 'è stato' : 'sono stati'} saltati.',
          ),
        ),
      );
    }
  }

  /// Inserisce il [padre] e i suoi figli nelle righe dell'editor.
  ///
  /// La logica di paniere è nelle funzioni pure di `data/panieri.dart`; qui si
  /// ricostruiscono i controller delle righe e si avvisa se alcuni figli non
  /// sono più disponibili.
  void _inserisciProdottoNelPreventivo(Prodotto padre) {
    final figli = figliDelPaniere(padre, _prodotti);
    final mancanti = figliMancanti(padre, _prodotti);
    final modello = [for (final riga in _righe) riga.toRiga()];
    final nuove = inserisciPaniere(padre: padre, figli: figli, righe: modello);

    final vecchie = List<_RigaPreventivo>.of(_righe);
    setState(() {
      _righe
        ..clear()
        ..addAll([for (final riga in nuove) _RigaPreventivo(riga: riga)]);
    });
    // I vecchi controller vengono liberati dopo il frame che li ha rimossi.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final riga in vecchie) {
        riga.dispose();
      }
    });

    if (mancanti.isNotEmpty) {
      final sostantivo = mancanti.length == 1
          ? 'sotto-prodotto'
          : 'sotto-prodotti';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${mancanti.length} $sostantivo non sono più disponibili '
            'e ${mancanti.length == 1 ? 'è stato' : 'sono stati'} saltati.',
          ),
        ),
      );
    }
  }

  /// Crea o aggiorna il preventivo e torna all'elenco.
  ///
  /// Imposta prima l'azienda attiva su `SpService` (come le altre schermate),
  /// poi chiama `inserisciPreventivo` per i nuovi documenti o
  /// `aggiornaPreventivo` per quelli esistenti. In caso di errore resta sulla
  /// schermata e mostra il messaggio in italiano.
  Future<void> _salva() async {
    if (_salvataggio) return;

    setState(() {
      _salvataggio = true;
      _erroreSalvataggio = null;
    });

    final iniziale = _preventivo;
    final righe = [for (final riga in _righe) riga.toRiga()];
    final payload = payloadPreventivoDaEditor(
      clienteId: _clienteId,
      clienteNome: nomeClientePreventivoDaSelezione(
        _clienti,
        _clienteId,
        fallback: iniziale?.clienteNome,
      ),
      stato: _stato,
      note: _note.text,
      sconto: numeroPreventivoDaTesto(_scontoGenerale.text),
      righe: righe,
    );

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final dati = datiServizioPreventivo(payload);
      final risultato = iniziale == null
          ? await servizio.inserisciPreventivo(dati)
          : await servizio.aggiornaPreventivo(iniziale.id, dati);
      if (!mounted) return;

      final numero =
          (risultato['numero'] as String?)?.trim() ??
          (iniziale?.numero ?? '').trim();
      final azione = iniziale == null ? 'creato' : 'salvato';
      final testo = numero.isEmpty
          ? 'Preventivo $azione.'
          : 'Preventivo $numero $azione.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(testo)));
      context.go('/preventivi');
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _salvataggio = false;
        _erroreSalvataggio = errore;
      });
    }
  }

  Future<void> _creaRevisione() async {
    final preventivo = _preventivo;
    if (preventivo == null || _revisione) return;
    setState(() {
      _revisione = true;
      _erroreRevisione = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final nuovo = await servizio.creaRevisione(preventivo);
      if (!mounted) return;
      final numero = (nuovo['numero'] as String?)?.trim() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            numero.isEmpty ? 'Revisione creata.' : 'Creata revisione $numero.',
          ),
        ),
      );
      context.go('/preventivi');
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _revisione = false;
        _erroreRevisione = errore;
      });
    }
  }

  /// Nome dell'azienda attiva per l'intestazione del PDF.
  ///
  /// Usa l'elenco aziende già caricato; con elenco non disponibile ricade sul
  /// default del servizio.
  String _nomeAziendaPerPdf() {
    final idAttivo = ref.read(aziendaAttivaProvider);
    final aziende = ref.read(aziendeUtenteProvider).asData?.value ?? const [];
    for (final azienda in aziende) {
      if (azienda.id != idAttivo) continue;
      final nome = azienda.nome.trim();
      if (nome.isNotEmpty) return nome;
      break;
    }
    return 'Closer';
  }

  /// Genera il PDF del preventivo e apre la condivisione di sistema.
  ///
  /// Disponibile solo per un preventivo già salvato (`_preventivo != null`);
  /// eventuali errori di generazione o condivisione diventano una SnackBar in
  /// italiano senza interrompere l'editor.
  Future<void> _esportaPdf() async {
    final preventivo = _preventivo;
    if (preventivo == null || _generazionePdf) return;

    setState(() => _generazionePdf = true);
    try {
      final byte = await generaPdfPreventivo(
        preventivo: preventivo,
        nomeAzienda: _nomeAziendaPerPdf(),
      );
      await Printing.sharePdf(
        bytes: byte,
        filename: '${nomeFilePdfPreventivo(preventivo)}.pdf',
      );
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErrorePdfPreventivo(errore))),
      );
    } finally {
      if (mounted) setState(() => _generazionePdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) {
        _caricaClienti();
        _caricaProdotti();
      }
    });

    if (_caricandoPreventivo) {
      return const Center(
        child: CircularProgressIndicator(key: Key('preventivo-caricamento')),
      );
    }
    if (_nonTrovato) {
      return const StatoCentrato(
        icona: Icons.search_off,
        titolo: 'Preventivo non trovato',
        sottotitolo:
            'Il preventivo non esiste o non hai i permessi per vederlo.',
      );
    }
    if (_errorePreventivo != null) {
      return StatoCentrato(
        icona: Icons.error_outline,
        titolo: 'Preventivo non caricato',
        sottotitolo: messaggioErroreCaricamentoPreventivo(_errorePreventivo),
        azione: FilledButton(
          onPressed: _riprovaCaricamentoPreventivo,
          child: const Text('Riprova'),
        ),
      );
    }

    final righe = _righe.map((riga) => riga.toRiga()).toList();
    final totali = totaliEditorPreventivo(
      righe,
      scontoGenerale: _scontoGenerale.text,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale = largo
            ? AppSpazi.paginaDesktop
            : AppSpazi.paginaTelefono;
        final tabella = constraints.maxWidth >= 860;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            orizzontale,
            orizzontale,
            orizzontale,
            orizzontale,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IntestazioneEditor(preventivo: _preventivo),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneCliente(),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneRighe(tabella: tabella),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneNoteSconto(),
                  const SizedBox(height: AppSpazi.m),
                  _RiepilogoTotali(totali: totali),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneSalvataggio(),
                  const SizedBox(height: AppSpazi.l),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- sezioni ----------

  /// Errore dell'ultimo salvataggio (se presente) e pulsante "Salva
  /// preventivo", disabilitato con spinner mentre il salvataggio è in corso.
  Widget _sezioneSalvataggio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_erroreSalvataggio != null) ...[
          AvvisoErrore(
            key: const Key('preventivo-salvataggio-errore'),
            testo: messaggioErroreSalvataggioPreventivo(_erroreSalvataggio!),
          ),
          const SizedBox(height: AppSpazi.s),
        ],
        if (_preventivo != null && puoCreareRevisione(_preventivo!.stato)) ...[
          OutlinedButton.icon(
            key: const Key('crea-revisione'),
            onPressed: _revisione ? null : _creaRevisione,
            icon: _revisione
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_all_outlined),
            label: Text(_revisione ? 'Creazione…' : 'Crea revisione'),
          ),
          if (_erroreRevisione != null) ...[
            const SizedBox(height: AppSpazi.s),
            AvvisoErrore(
              key: const Key('preventivo-revisione-errore'),
              testo: messaggioErroreSalvataggioPreventivo(_erroreRevisione!),
            ),
          ],
          const SizedBox(height: AppSpazi.s),
        ],
        if (_preventivo != null) ...[
          OutlinedButton.icon(
            key: const Key('preventivo-pdf'),
            onPressed: _generazionePdf ? null : _esportaPdf,
            icon: _generazionePdf
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_generazionePdf ? 'Preparazione PDF…' : 'PDF'),
          ),
          const SizedBox(height: AppSpazi.s),
        ],
        FilledButton.icon(
          key: const Key('salva-preventivo'),
          onPressed: _salvataggio ? null : _salva,
          icon: _salvataggio
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(_salvataggio ? 'Salvataggio…' : 'Salva preventivo'),
        ),
      ],
    );
  }

  Widget _sezioneCliente() {
    final opzioni = opzioniClientiPreventivo(
      _clienti,
      idSelezionato: _clienteId,
      nomeSelezionato: _preventivo?.clienteNome,
    );
    final abilitata = !_caricandoClienti && opzioni.isNotEmpty;
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TitoloSezione('Cliente e stato'),
            const SizedBox(height: AppSpazi.s),
            DropdownButtonFormField<String>(
              key: const Key('preventivo-cliente'),
              initialValue: _clienteId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Cliente',
                hintText: _caricandoClienti
                    ? 'Caricamento clienti…'
                    : 'Seleziona un cliente',
              ),
              items: [
                for (final voce in opzioni.entries)
                  DropdownMenuItem(
                    value: voce.key,
                    child: Text(
                      voce.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: abilitata
                  ? (valore) => setState(() => _clienteId = valore)
                  : null,
            ),
            if (_erroreClienti != null) ...[
              const SizedBox(height: AppSpazi.xs),
              AvvisoErrore(
                key: const Key('preventivo-clienti-errore'),
                testo: messaggioErroreClientiPreventivo(_erroreClienti!),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('preventivo-clienti-riprova'),
                  onPressed: _caricaClienti,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ),
            ] else if (!_caricandoClienti && opzioni.isEmpty) ...[
              const SizedBox(height: AppSpazi.xs),
              Text(
                'Nessun cliente disponibile. Creane uno da Clienti.',
                key: const Key('preventivo-clienti-vuoto'),
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpazi.s),
            DropdownButtonFormField<String>(
              key: const Key('preventivo-stato'),
              initialValue: _stato,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Stato'),
              items: [
                for (final voce in opzioniStatoPreventivo(_stato).entries)
                  DropdownMenuItem(value: voce.key, child: Text(voce.value)),
              ],
              onChanged: (valore) {
                if (valore == null) return;
                setState(() => _stato = valore);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sezioneRighe({required bool tabella}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(child: _TitoloSezione('Righe')),
            const SizedBox(width: AppSpazi.s),
            Flexible(
              child: Wrap(
                spacing: AppSpazi.xs,
                runSpacing: AppSpazi.xxs,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: const Key('aggiungi-dal-catalogo'),
                    onPressed: _caricandoProdotti
                        ? null
                        : _apriCatalogoProdotti,
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Dal catalogo'),
                  ),
                  FilledButton.tonalIcon(
                    key: const Key('aggiungi-riga'),
                    onPressed: _aggiungiRiga,
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi riga'),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (_erroreProdotti != null) ...[
          const SizedBox(height: AppSpazi.xs),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Catalogo non disponibile',
                  key: Key('preventivo-prodotti-errore'),
                ),
              ),
              TextButton.icon(
                key: const Key('preventivo-prodotti-riprova'),
                onPressed: _caricaProdotti,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpazi.s),
        if (_righe.isEmpty)
          const _RigheVuote()
        else if (tabella)
          _TabellaRigheEditor(
            righe: _righe,
            onCambia: () => setState(() {}),
            onRimuovi: _rimuoviRiga,
            onCatalogo: _apriCatalogoPerRiga,
          )
        else
          Column(
            children: [
              for (final riga in _righe) ...[
                _CardRigaEditor(
                  riga: riga,
                  onCambia: () => setState(() {}),
                  onRimuovi: () => _rimuoviRiga(riga),
                  onCatalogo: _apriCatalogoPerRiga,
                ),
                const SizedBox(height: AppSpazi.xs),
              ],
            ],
          ),
      ],
    );
  }

  Widget _sezioneNoteSconto() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TitoloSezione('Note e sconto'),
            const SizedBox(height: AppSpazi.s),
            TextField(
              key: const Key('preventivo-note'),
              controller: _note,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Note visibili nel preventivo',
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: TextField(
                key: const Key('preventivo-sconto'),
                controller: _scontoGenerale,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                ],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Sconto generale',
                  suffixText: '%',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Intestazione dell'editor: titolo e, in modifica, numero e revisione.
class _IntestazioneEditor extends StatelessWidget {
  const _IntestazioneEditor({this.preventivo});

  final Preventivo? preventivo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final documento = preventivo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          documento == null ? 'Nuovo preventivo' : 'Modifica preventivo',
          style: tema.textTheme.titleLarge,
        ),
        if (documento != null) ...[
          const SizedBox(height: AppSpazi.xxs),
          Wrap(
            spacing: AppSpazi.s,
            runSpacing: AppSpazi.xxs,
            children: [
              Text(
                'Numero: ${numeroVisualizzatoPreventivo(documento)}',
                key: const Key('preventivo-numero'),
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Revisione: ${documento.revisione}',
                key: const Key('preventivo-revisione'),
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Titolo di una sezione dell'editor.
class _TitoloSezione extends StatelessWidget {
  const _TitoloSezione(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Text(
      testo.toUpperCase(),
      style: tema.textTheme.labelSmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Stato vuoto dell'elenco righe.
class _RigheVuote extends StatelessWidget {
  const _RigheVuote();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      key: const Key('righe-vuote'),
      padding: const EdgeInsets.all(AppSpazi.l),
      decoration: BoxDecoration(
        color: AppColors.superficie,
        borderRadius: BorderRadius.circular(AppRaggi.card),
        border: Border.all(color: AppColors.bordo),
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_outlined,
            size: 32,
            color: tema.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpazi.xs),
          Text('Nessuna riga', style: tema.textTheme.titleSmall),
          const SizedBox(height: AppSpazi.xxs),
          Text(
            'Premi "Aggiungi riga" per inserire il primo articolo.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo numerico compatto dell'editor.
class _CampoNumero extends StatelessWidget {
  const _CampoNumero({
    super.key,
    required this.controller,
    this.etichetta,
    this.suggerimento,
    this.onCambia,
    this.allineatoDestra = false,
  });

  final TextEditingController controller;
  final String? etichetta;
  final String? suggerimento;
  final VoidCallback? onCambia;
  final bool allineatoDestra;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: allineatoDestra ? TextAlign.right : TextAlign.start,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
      onChanged: (_) => onCambia?.call(),
      decoration: InputDecoration(
        labelText: etichetta,
        hintText: suggerimento,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpazi.s,
          vertical: AppSpazi.s,
        ),
      ),
    );
  }
}

/// Riga in card (telefono).
class _CardRigaEditor extends StatelessWidget {
  const _CardRigaEditor({
    required this.riga,
    required this.onCambia,
    required this.onRimuovi,
    required this.onCatalogo,
  });

  final _RigaPreventivo riga;
  final VoidCallback onCambia;
  final VoidCallback onRimuovi;
  final ValueChanged<_RigaPreventivo> onCatalogo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final totale = totaleRiga(riga.toRiga());
    final etichettaPaniere = etichettaPaniereRiga(riga.toRiga());
    final figlia = etichettaPaniere != null;

    return Card(
      key: ValueKey('riga-card-${riga.chiave}'),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          figlia ? AppSpazi.s * 2 : AppSpazi.s,
          AppSpazi.s,
          AppSpazi.s,
          AppSpazi.s,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (figlia) ...[
              Row(
                key: Key('riga-${riga.chiave}-paniere'),
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpazi.xxs),
                  Expanded(
                    child: Text(
                      etichettaPaniere,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.xxs),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: Key('riga-${riga.chiave}-nome'),
                    controller: riga.nome,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => onCambia(),
                    decoration: const InputDecoration(
                      labelText: 'Descrizione',
                      hintText: 'Es. Licenza annuale',
                    ),
                  ),
                ),
                IconButton(
                  key: Key('riga-${riga.chiave}-catalogo'),
                  tooltip: 'Scegli dal catalogo',
                  onPressed: () => onCatalogo(riga),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
                IconButton(
                  key: Key('riga-${riga.chiave}-rimuovi'),
                  tooltip: 'Rimuovi riga',
                  onPressed: onRimuovi,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CampoNumero(
                    key: Key('riga-${riga.chiave}-quantita'),
                    controller: riga.quantita,
                    etichetta: 'Quantità',
                    onCambia: onCambia,
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 2,
                  child: _CampoNumero(
                    key: Key('riga-${riga.chiave}-prezzo'),
                    controller: riga.prezzo,
                    etichetta: 'Prezzo',
                    onCambia: onCambia,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _CampoNumero(
                    key: Key('riga-${riga.chiave}-sconto'),
                    controller: riga.sconto,
                    etichetta: 'Sconto %',
                    onCambia: onCambia,
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  child: _CampoNumero(
                    key: Key('riga-${riga.chiave}-iva'),
                    controller: riga.iva,
                    etichetta: 'IVA %',
                    onCambia: onCambia,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.xs),
            Row(
              children: [
                Text(
                  'Totale riga',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  formattaPrezzo(totale),
                  key: Key('riga-${riga.chiave}-totale'),
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

/// Larghezza della colonna "Totale riga" nella tabella desktop.
const double _larghezzaTotaleRiga = 104;

/// Larghezza del pulsante "Rimuovi" nella tabella desktop.
const double _larghezzaRimuoviRiga = 44;

/// Riga in tabella (desktop): intestazioni allineate ai campi.
class _TabellaRigheEditor extends StatelessWidget {
  const _TabellaRigheEditor({
    required this.righe,
    required this.onCambia,
    required this.onRimuovi,
    required this.onCatalogo,
  });

  final List<_RigaPreventivo> righe;
  final VoidCallback onCambia;
  final ValueChanged<_RigaPreventivo> onRimuovi;
  final ValueChanged<_RigaPreventivo> onCatalogo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final stileIntestazione = tema.textTheme.labelSmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('DESCRIZIONE', style: stileIntestazione),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Q.TÀ',
                    style: stileIntestazione,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 2,
                  child: Text(
                    'PREZZO',
                    style: stileIntestazione,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 1,
                  child: Text(
                    'SC. %',
                    style: stileIntestazione,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 1,
                  child: Text(
                    'IVA %',
                    style: stileIntestazione,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                SizedBox(
                  width: _larghezzaTotaleRiga,
                  child: Text(
                    'TOTALE',
                    style: stileIntestazione,
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: _larghezzaRimuoviRiga),
              ],
            ),
            const Divider(height: AppSpazi.m),
            for (final riga in righe)
              Padding(
                key: ValueKey('riga-tabella-${riga.chiave}'),
                padding: const EdgeInsets.symmetric(vertical: AppSpazi.xxs),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _cellaDescrizione(tema, riga)),
                    const SizedBox(width: AppSpazi.xs),
                    Expanded(
                      flex: 1,
                      child: _CampoNumero(
                        key: Key('riga-${riga.chiave}-quantita'),
                        controller: riga.quantita,
                        suggerimento: '1',
                        onCambia: onCambia,
                        allineatoDestra: true,
                      ),
                    ),
                    const SizedBox(width: AppSpazi.xs),
                    Expanded(
                      flex: 2,
                      child: _CampoNumero(
                        key: Key('riga-${riga.chiave}-prezzo'),
                        controller: riga.prezzo,
                        suggerimento: '0,00',
                        onCambia: onCambia,
                        allineatoDestra: true,
                      ),
                    ),
                    const SizedBox(width: AppSpazi.xs),
                    Expanded(
                      flex: 1,
                      child: _CampoNumero(
                        key: Key('riga-${riga.chiave}-sconto'),
                        controller: riga.sconto,
                        suggerimento: '0',
                        onCambia: onCambia,
                        allineatoDestra: true,
                      ),
                    ),
                    const SizedBox(width: AppSpazi.xs),
                    Expanded(
                      flex: 1,
                      child: _CampoNumero(
                        key: Key('riga-${riga.chiave}-iva'),
                        controller: riga.iva,
                        suggerimento: '22',
                        onCambia: onCambia,
                        allineatoDestra: true,
                      ),
                    ),
                    const SizedBox(width: AppSpazi.xs),
                    SizedBox(
                      width: _larghezzaTotaleRiga,
                      child: Text(
                        formattaPrezzo(totaleRiga(riga.toRiga())),
                        key: Key('riga-${riga.chiave}-totale'),
                        textAlign: TextAlign.right,
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                    SizedBox(
                      width: _larghezzaRimuoviRiga,
                      child: IconButton(
                        key: Key('riga-${riga.chiave}-rimuovi'),
                        tooltip: 'Rimuovi riga',
                        onPressed: () => onRimuovi(riga),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Cella Descrizione della tabella: sopra il campo, se la riga è figlia di
  /// un paniere, l'etichetta `Paniere: <nome>` in stile `labelSmall`.
  Widget _cellaDescrizione(ThemeData tema, _RigaPreventivo riga) {
    final etichettaPaniere = etichettaPaniereRiga(riga.toRiga());
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (etichettaPaniere != null) ...[
          Text(
            etichettaPaniere,
            key: Key('riga-${riga.chiave}-paniere'),
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpazi.xxs),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('riga-${riga.chiave}-nome'),
                controller: riga.nome,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => onCambia(),
                decoration: const InputDecoration(
                  hintText: 'Descrizione',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpazi.s,
                    vertical: AppSpazi.s,
                  ),
                ),
              ),
            ),
            IconButton(
              key: Key('riga-${riga.chiave}-catalogo'),
              tooltip: 'Scegli dal catalogo',
              onPressed: () => onCatalogo(riga),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
          ],
        ),
      ],
    );
  }
}

/// Riepilogo dei totali del preventivo.
class _RiepilogoTotali extends StatelessWidget {
  const _RiepilogoTotali({required this.totali});

  final PreventivoTotali totali;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TitoloSezione('Riepilogo'),
            const SizedBox(height: AppSpazi.s),
            _RigaTotale(
              etichetta: 'Subtotale',
              valore: totali.subtotale,
              chiave: 'preventivo-subtotale',
            ),
            _RigaTotale(
              etichetta: 'Sconto',
              valore: totali.impSconto,
              chiave: 'preventivo-sconto',
            ),
            _RigaTotale(
              etichetta: 'Imponibile',
              valore: totali.imponibile,
              chiave: 'preventivo-imponibile',
            ),
            _RigaTotale(
              etichetta: 'IVA',
              valore: totali.iva,
              chiave: 'preventivo-iva',
            ),
            const Divider(height: AppSpazi.l),
            Row(
              children: [
                Expanded(
                  child: Text('Totale', style: tema.textTheme.titleMedium),
                ),
                Text(
                  formattaPrezzo(totali.totaleIva),
                  key: const Key('preventivo-totale'),
                  style: tema.textTheme.titleMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga etichetta/valore del riepilogo.
class _RigaTotale extends StatelessWidget {
  const _RigaTotale({
    required this.etichetta,
    required this.valore,
    required this.chiave,
  });

  final String etichetta;
  final double valore;
  final String chiave;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final stile = tema.textTheme.bodyMedium?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpazi.xxs),
      child: Row(
        children: [
          Expanded(child: Text(etichetta, style: stile)),
          Text(
            formattaPrezzo(valore),
            key: Key(chiave),
            style: tema.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Foglio di scelta di un prodotto del catalogo da inserire nelle righe.
///
/// Mostra solo i prodotti attivi con un nome, con ricerca per nome o
/// categoria. Toccando una voce si chiude restituendo il prodotto scelto.
class _CatalogoProdottiSheet extends StatefulWidget {
  const _CatalogoProdottiSheet({required this.prodotti});

  final List<Prodotto> prodotti;

  @override
  State<_CatalogoProdottiSheet> createState() => _CatalogoProdottiSheetState();
}

class _CatalogoProdottiSheetState extends State<_CatalogoProdottiSheet> {
  final _ricerca = TextEditingController();

  @override
  void dispose() {
    _ricerca.dispose();
    super.dispose();
  }

  /// Prodotti attivi con nome, filtrati per nome o categoria.
  List<Prodotto> get _filtrati {
    final testo = _ricerca.text.trim().toLowerCase();
    return [
      for (final prodotto in widget.prodotti)
        if (prodotto.attivo && (prodotto.nome?.trim() ?? '').isNotEmpty)
          if (testo.isEmpty ||
              (prodotto.nome ?? '').toLowerCase().contains(testo) ||
              (prodotto.categoria ?? '').toLowerCase().contains(testo))
            prodotto,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final prodotti = _filtrati;
    final altezza = MediaQuery.sizeOf(context).height * 0.75;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: altezza,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpazi.m,
                AppSpazi.xs,
                AppSpazi.m,
                AppSpazi.s,
              ),
              child: TextField(
                key: const Key('catalogo-preventivo-ricerca'),
                controller: _ricerca,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Cerca nel catalogo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: prodotti.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.l),
                        child: Text(
                          'Nessun prodotto nel catalogo',
                          key: const Key('catalogo-preventivo-vuoto'),
                          textAlign: TextAlign.center,
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: AppSpazi.m),
                      itemCount: prodotti.length,
                      itemBuilder: (context, indice) {
                        final prodotto = prodotti[indice];
                        final paniere = etichettaPaniere(prodotto);
                        return ListTile(
                          key: Key('catalogo-prodotto-${prodotto.id}'),
                          title: Text(prodotto.nome!.trim()),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formattaPrezzo(prodotto.prezzo)),
                              if (paniere.isNotEmpty) Text(paniere),
                            ],
                          ),
                          onTap: () => Navigator.of(context).pop(prodotto),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stato modificabile di una riga del preventivo.
///
/// Tiene i controller dei campi e ricostruisce la [PreventivoRiga] solo quando
/// serve (totali, riga calcolata).
class _RigaPreventivo {
  _RigaPreventivo({PreventivoRiga? riga})
    : chiave = _prossimaChiave++,
      prodottoId = riga?.prodottoId,
      codice = riga?.codice,
      um = riga?.um,
      paniereId = riga?.paniereId,
      paniereNome = riga?.paniereNome {
    nome.text = riga?.nome ?? '';
    quantita.text = riga == null ? '1' : testoNumeroPreventivo(riga.qty);
    prezzo.text = riga == null ? '' : testoNumeroPreventivo(riga.prezzo);
    sconto.text = riga == null ? '' : testoNumeroPreventivo(riga.scontoPerc);
    iva.text = testoNumeroPreventivo(riga?.ivaPerc ?? 22);
  }

  static int _prossimaChiave = 0;

  /// Identificativo stabile per chiavi widget e test (`riga-0-nome`, …).
  final int chiave;

  /// Campi del prodotto collegato, modificabili quando si sceglie dal catalogo.
  String? prodottoId;
  String? codice;
  String? um;

  /// Padre del paniere per le righe figlie (`null` per le righe normali).
  String? paniereId;
  String? paniereNome;

  final nome = TextEditingController();
  final quantita = TextEditingController();
  final prezzo = TextEditingController();
  final sconto = TextEditingController();
  final iva = TextEditingController();

  /// Riga del modello costruita dai campi correnti.
  PreventivoRiga toRiga() => rigaPreventivoDaCampi(
    prodottoId: prodottoId,
    codice: codice,
    um: um,
    paniereId: paniereId,
    paniereNome: paniereNome,
    nome: nome.text,
    quantita: quantita.text,
    prezzo: prezzo.text,
    scontoPerc: sconto.text,
    ivaPerc: iva.text,
  );

  /// Compila la riga con il [prodotto] scelto dal catalogo.
  ///
  /// Riusa [rigaConProdotto] per i campi del prodotto; quantità e sconto vuoti
  /// ricadono su `1` e `0`, l'IVA torna al default 22%.
  void applicaProdotto(Prodotto prodotto) {
    final compilata = rigaConProdotto(toRiga(), prodotto);
    prodottoId = compilata.prodottoId;
    codice = compilata.codice;
    um = compilata.um;
    paniereId = compilata.paniereId;
    paniereNome = compilata.paniereNome;
    nome.text = compilata.nome ?? '';
    prezzo.text = prodotto.prezzo == null
        ? ''
        : testoNumeroPreventivo(prodotto.prezzo);
    if (quantita.text.trim().isEmpty) quantita.text = '1';
    if (sconto.text.trim().isEmpty) sconto.text = '0';
    iva.text = '22';
  }

  void dispose() {
    nome.dispose();
    quantita.dispose();
    prezzo.dispose();
    sconto.dispose();
    iva.dispose();
  }
}
