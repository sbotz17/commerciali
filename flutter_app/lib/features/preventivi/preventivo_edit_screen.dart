// Editor del preventivo (F12b-1).
//
// Contiene i dati generali (cliente, stato), le note, lo sconto generale e le
// righe modificabili, con il riepilogo dei totali. Il salvataggio, il
// caricamento del preventivo da Firestore e le revisioni arrivano in F12b-2:
// qui la schermata lavora solo in memoria.
//
// I totali usano le funzioni pure del modello (`totaleRiga`, `calcolaTotali`)
// per restare identici alla vecchia app.

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/models/cliente.dart';
import '../../data/models/preventivo.dart';
import '../../state/azienda_providers.dart';
import '../catalogo/catalogo_screen.dart' show formattaPrezzo, prezzoDaTesto;
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
  );
}

/// Sconto globale in euro a partire dalla percentuale e dal subtotale righe.
double scontoGlobaleEuroDaPercentuale(
  double subtotale,
  double percentuale,
) {
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
/// Senza [iniziale] prepara un preventivo nuovo (nessuna riga iniziale).
class PreventivoEditScreen extends ConsumerStatefulWidget {
  const PreventivoEditScreen({super.key, this.iniziale});

  /// Preventivo da modificare; `null` per crearne uno nuovo.
  final Preventivo? iniziale;

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

  String? _clienteId;
  String _stato = 'bozza';

  @override
  void initState() {
    super.initState();
    final preventivo = widget.iniziale;
    _clienteId = preventivo?.clienteId;
    _stato = (preventivo?.stato ?? 'bozza').trim().toLowerCase();
    if (_stato.isEmpty) _stato = 'bozza';
    _note.text = preventivo?.note ?? '';
    _scontoGenerale.text =
        preventivo == null ? '' : testoNumeroPreventivo(preventivo.sconto);
    for (final riga in preventivo?.righe ?? const <PreventivoRiga>[]) {
      _righe.add(_RigaPreventivo(riga: riga));
    }
    _caricaClienti();
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

  void _aggiungiRiga() {
    setState(() => _righe.add(_RigaPreventivo()));
  }

  void _rimuoviRiga(_RigaPreventivo riga) {
    setState(() => _righe.remove(riga));
    // I controller vengono liberati dopo il rebuild che rimuove i campi.
    WidgetsBinding.instance.addPostFrameCallback((_) => riga.dispose());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _caricaClienti();
    });

    final righe = _righe.map((riga) => riga.toRiga()).toList();
    final totali = totaliEditorPreventivo(
      righe,
      scontoGenerale: _scontoGenerale.text,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;
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
                  _IntestazioneEditor(preventivo: widget.iniziale),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneCliente(),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneRighe(tabella: tabella),
                  const SizedBox(height: AppSpazi.m),
                  _sezioneNoteSconto(),
                  const SizedBox(height: AppSpazi.m),
                  _RiepilogoTotali(totali: totali),
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

  Widget _sezioneCliente() {
    final opzioni = opzioniClientiPreventivo(
      _clienti,
      idSelezionato: _clienteId,
      nomeSelezionato: widget.iniziale?.clienteNome,
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
          children: [
            const Expanded(child: _TitoloSezione('Righe')),
            const SizedBox(width: AppSpazi.s),
            FilledButton.tonalIcon(
              key: const Key('aggiungi-riga'),
              onPressed: _aggiungiRiga,
              icon: const Icon(Icons.add),
              label: const Text('Aggiungi riga'),
            ),
          ],
        ),
        const SizedBox(height: AppSpazi.s),
        if (_righe.isEmpty)
          const _RigheVuote()
        else if (tabella)
          _TabellaRigheEditor(
            righe: _righe,
            onCambia: () => setState(() {}),
            onRimuovi: _rimuoviRiga,
          )
        else
          Column(
            children: [
              for (final riga in _righe) ...[
                _CardRigaEditor(
                  riga: riga,
                  onCambia: () => setState(() {}),
                  onRimuovi: () => _rimuoviRiga(riga),
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
          Text(
            'Nessuna riga',
            style: tema.textTheme.titleSmall,
          ),
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
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
      ],
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
  });

  final _RigaPreventivo riga;
  final VoidCallback onCambia;
  final VoidCallback onRimuovi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final totale = totaleRiga(riga.toRiga());

    return Card(
      key: ValueKey('riga-card-${riga.chiave}'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.s),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
  });

  final List<_RigaPreventivo> righe;
  final VoidCallback onCambia;
  final ValueChanged<_RigaPreventivo> onRimuovi;

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
                Expanded(flex: 3, child: Text('DESCRIZIONE', style: stileIntestazione)),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 1,
                  child: Text('Q.TÀ', style: stileIntestazione, textAlign: TextAlign.right),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 2,
                  child: Text('PREZZO', style: stileIntestazione, textAlign: TextAlign.right),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 1,
                  child: Text('SC. %', style: stileIntestazione, textAlign: TextAlign.right),
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  flex: 1,
                  child: Text('IVA %', style: stileIntestazione, textAlign: TextAlign.right),
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
                    Expanded(
                      flex: 3,
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

/// Stato modificabile di una riga del preventivo.
///
/// Tiene i controller dei campi e ricostruisce la [PreventivoRiga] solo quando
/// serve (totali, riga calcolata).
class _RigaPreventivo {
  _RigaPreventivo({PreventivoRiga? riga})
      : chiave = _prossimaChiave++,
        prodottoId = riga?.prodottoId,
        codice = riga?.codice,
        um = riga?.um {
    nome.text = riga?.nome ?? '';
    quantita.text = riga == null ? '1' : testoNumeroPreventivo(riga.qty);
    prezzo.text = riga == null ? '' : testoNumeroPreventivo(riga.prezzo);
    sconto.text =
        riga == null ? '' : testoNumeroPreventivo(riga.scontoPerc);
    iva.text = testoNumeroPreventivo(riga?.ivaPerc ?? 22);
  }

  static int _prossimaChiave = 0;

  /// Identificativo stabile per chiavi widget e test (`riga-0-nome`, …).
  final int chiave;

  /// Campi del prodotto collegato, preservati dal preventivo di partenza.
  final String? prodottoId;
  final String? codice;
  final String? um;

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
        nome: nome.text,
        quantita: quantita.text,
        prezzo: prezzo.text,
        scontoPerc: sconto.text,
        ivaPerc: iva.text,
      );

  void dispose() {
    nome.dispose();
    quantita.dispose();
    prezzo.dispose();
    sconto.dispose();
    iva.dispose();
  }
}
