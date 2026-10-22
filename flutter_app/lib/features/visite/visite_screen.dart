import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/menu_azioni.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/cliente.dart';
import '../../data/models/visita.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: stati, date, ordinamento e messaggi (verificabili senza
// Firebase né UI)
// ---------------------------------------------------------------------------

/// Etichette italiane degli stati della visita (chiavi Firestore).
const Map<String, String> statiVisita = {
  'da_fare': 'Da fare',
  'fatto': 'Fatto',
};

/// Etichetta italiana di uno [stato] della visita.
///
/// Lo stato vuoto ricade su "Da fare" (default della vecchia app); gli stati
/// sconosciuti restano visibili così come sono.
String etichettaStatoVisita(String stato) {
  final chiave = stato.trim().toLowerCase();
  if (chiave.isEmpty) return statiVisita['da_fare']!;
  return statiVisita[chiave] ?? chiave;
}

/// Colore del badge di stato, coerente con i colori semantici del tema.
Color coloreStatoVisita(String stato) {
  switch (stato.trim().toLowerCase()) {
    case 'fatto':
      return AppColors.accettato;
    default:
      return AppColors.attesa;
  }
}

/// Nome del cliente denormalizzato, con `—` se assente.
String nomeClienteVisita(Visita visita) {
  final nome = visita.clienteNome?.trim() ?? '';
  return nome.isEmpty ? '—' : nome;
}

/// Ora della visita `HH:MM`, con `—` se assente.
String oraVisita(Visita visita) {
  final ora = visita.ora?.trim() ?? '';
  return ora.isEmpty ? '—' : ora;
}

/// Note della visita, con `—` se assenti.
String noteVisita(Visita visita) {
  final note = visita.note?.trim() ?? '';
  return note.isEmpty ? '—' : note;
}

/// Formatta una data come `gg/mm/aaaa` (formato italiano).
String formattaDataVisita(DateTime data) {
  final giorno = data.day.toString().padLeft(2, '0');
  final mese = data.month.toString().padLeft(2, '0');
  return '$giorno/$mese/${data.year}';
}

/// Data in formato Firestore `YYYY-MM-DD`.
String dataIsoVisita(DateTime data) {
  final mese = data.month.toString().padLeft(2, '0');
  final giorno = data.day.toString().padLeft(2, '0');
  return '${data.year}-$mese-$giorno';
}

/// Interpreta una data italiana `gg/mm/aaaa`.
///
/// Ritorna `null` se il testo non è una data valida (compresi i giorni che non
/// esistono nel mese, es. 31/02).
DateTime? parseDataItaliana(String? testo) {
  final valore = testo?.trim() ?? '';
  final parti = valore.split('/');
  if (parti.length != 3) return null;
  final giorno = int.tryParse(parti[0]);
  final mese = int.tryParse(parti[1]);
  final anno = int.tryParse(parti[2]);
  if (giorno == null || mese == null || anno == null) return null;
  if (anno < 1900 || mese < 1 || mese > 12 || giorno < 1) return null;
  final data = DateTime(anno, mese, giorno);
  if (data.year != anno || data.month != mese || data.day != giorno) {
    return null;
  }
  return data;
}

/// Validazione della data della visita: obbligatoria e in formato italiano.
String? validaDataVisita(String? valore) {
  if (parseDataItaliana(valore) == null) {
    return 'Inserisci una data valida (gg/mm/aaaa)';
  }
  return null;
}

/// Normalizza l'ora in `HH:MM`; `null` se il testo non è un'ora valida.
///
/// Accetta anche una cifra sola (`9:5` diventa `09:05`).
String? normalizzaOraVisita(String? testo) {
  final valore = testo?.trim() ?? '';
  if (valore.isEmpty) return null;
  final parti = valore.split(':');
  if (parti.length != 2) return null;
  final ore = int.tryParse(parti[0]);
  final minuti = int.tryParse(parti[1]);
  if (ore == null || minuti == null) return null;
  if (ore < 0 || ore > 23 || minuti < 0 || minuti > 59) return null;
  return '${ore.toString().padLeft(2, '0')}:'
      '${minuti.toString().padLeft(2, '0')}';
}

/// Validazione dell'ora: facoltativa, ma se presente deve essere `HH:MM`.
String? validaOraVisita(String? valore) {
  final testo = valore?.trim() ?? '';
  if (testo.isEmpty) return null;
  if (normalizzaOraVisita(testo) == null) {
    return 'Inserisci un\'ora valida (HH:MM)';
  }
  return null;
}

/// Etichetta del giorno selezionato: "Oggi", "Ieri", "Domani" o la data.
String etichettaGiornoVisite(DateTime giorno, {DateTime? oggi}) {
  final riferimento = oggi ?? DateTime.now();
  final g = DateTime(giorno.year, giorno.month, giorno.day);
  final o = DateTime(riferimento.year, riferimento.month, riferimento.day);
  final differenza = g.difference(o).inDays;
  switch (differenza) {
    case 0:
      return 'Oggi';
    case -1:
      return 'Ieri';
    case 1:
      return 'Domani';
    default:
      return formattaDataVisita(g);
  }
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio visite.
String messaggioErroreVisite(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per gestire le visite. '
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

/// Copia delle visite ordinate per `ordine` e poi per `ora`, come il servizio.
List<Visita> ordinaVisite(List<Visita> visite) {
  final risultato = List<Visita>.from(visite);
  risultato.sort((a, b) {
    final cmpOrdine = a.ordine.compareTo(b.ordine);
    if (cmpOrdine != 0) return cmpOrdine;
    return (a.ora ?? '').compareTo(b.ora ?? '');
  });
  return risultato;
}

/// Nuovo elenco con la visita in [indice] spostata di [scarto] posizioni.
///
/// Lo spostamento viene limitato ai bordi della lista: in cima la freccia su
/// non fa nulla, in fondo la freccia giù non fa nulla. L'elenco restituito è
/// già ordinato per `ordine`.
List<Visita> spostaVisita(List<Visita> visite, int indice, int scarto) {
  final ordinate = ordinaVisite(visite);
  if (indice < 0 || indice >= ordinate.length || scarto == 0) {
    return ordinate;
  }
  final destinazione = (indice + scarto).clamp(0, ordinate.length - 1);
  if (destinazione == indice) return ordinate;
  final risultato = List<Visita>.from(ordinate);
  final visitata = risultato.removeAt(indice);
  risultato.insert(destinazione, visitata);
  return risultato;
}

/// Ordini da salvare in batch dopo un riordino (0, 1, 2, …).
List<({String id, int ordine})> ordiniVisite(List<Visita> visite) {
  return [
    for (var i = 0; i < visite.length; i++) (id: visite[i].id, ordine: i),
  ];
}

/// Indirizzo del cliente composto come nella vecchia app.
String? indirizzoCliente(Cliente cliente) {
  final via = [
    cliente.indirizzo?.trim() ?? '',
    cliente.civico?.trim() ?? '',
  ].where((parte) => parte.isNotEmpty).join(' ');
  final localita = [
    cliente.cap?.trim() ?? '',
    cliente.citta?.trim() ?? '',
  ].where((parte) => parte.isNotEmpty).join(' ');
  final parti = [
    if (via.isNotEmpty) via,
    if (localita.isNotEmpty) localita,
  ];
  return parti.isEmpty ? null : parti.join(', ');
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Giro visite del giorno: selezione data, elenco, form e riordino.
class VisiteScreen extends ConsumerStatefulWidget {
  const VisiteScreen({super.key});

  @override
  ConsumerState<VisiteScreen> createState() => _VisiteScreenState();
}

class _VisiteScreenState extends ConsumerState<VisiteScreen> {
  late DateTime _giorno;
  late final TextEditingController _dataVisita;

  List<Visita> _visite = const [];
  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    final oggi = DateTime.now();
    _giorno = DateTime(oggi.year, oggi.month, oggi.day);
    _dataVisita = TextEditingController(text: formattaDataVisita(_giorno));
    _caricaVisite();
  }

  @override
  void dispose() {
    _dataVisita.dispose();
    super.dispose();
  }

  /// Passa l'azienda attiva al servizio e ricarica le visite del giorno.
  Future<void> _caricaVisite() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final visite = await servizio.getVisite(dataIsoVisita(_giorno));
      if (!mounted) return;
      setState(() {
        _visite = visite;
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

  void _vaiAlGiorno(DateTime giorno) {
    final normalizzato = DateTime(giorno.year, giorno.month, giorno.day);
    _dataVisita.text = formattaDataVisita(normalizzato);
    setState(() => _giorno = normalizzato);
    _caricaVisite();
  }

  void _applicaDataScritta() {
    final giorno = parseDataItaliana(_dataVisita.text);
    if (giorno == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data non valida. Usa il formato gg/mm/aaaa.'),
        ),
      );
      return;
    }
    if (dataIsoVisita(giorno) != dataIsoVisita(_giorno)) {
      _vaiAlGiorno(giorno);
    }
  }

  Future<void> _apriForm([Visita? visita]) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VisitaFormScreen(
          visita: visita,
          dataIniziale: _giorno,
          ordineIniziale: _visite.length,
        ),
      ),
    );
    if (salvato == true) await _caricaVisite();
  }

  Future<void> _elimina(Visita visita) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-elimina-visita'),
        title: const Text('Eliminare la visita?'),
        content: Text(
          'La visita a "${nomeClienteVisita(visita)}" verrà eliminata '
          'definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-elimina-visita'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      await servizio.eliminaVisita(visita.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Visita eliminata')),
      );
      await _caricaVisite();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreVisite(errore))),
      );
    }
  }

  /// Sposta la visita di [scarto] posizioni e salva i nuovi ordini in batch.
  Future<void> _sposta(int indice, int scarto) async {
    final nuove = spostaVisita(_visite, indice, scarto);
    final invariato = nuove.length == _visite.length &&
        List.generate(nuove.length, (i) => nuove[i].id == _visite[i].id)
            .every((uguale) => uguale);
    if (invariato) return;

    setState(() => _visite = nuove);
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      await servizio.riordinaVisite(ordiniVisite(nuove));
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreVisite(errore))),
      );
      await _caricaVisite();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _caricaVisite();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                orizzontale,
                orizzontale,
                AppSpazi.s,
              ),
              child: _BarraVisite(
                largo: largo,
                controller: _dataVisita,
                etichettaGiorno: etichettaGiornoVisite(_giorno),
                onPrecedente: () => _vaiAlGiorno(
                  _giorno.subtract(const Duration(days: 1)),
                ),
                onSuccessivo: () => _vaiAlGiorno(
                  _giorno.add(const Duration(days: 1)),
                ),
                onApplicaData: _applicaDataScritta,
                onOggi: () => _vaiAlGiorno(DateTime.now()),
                onNuova: () => _apriForm(),
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
                child: ElencoVisite(
                  visite: _visite,
                  caricamento: _caricamento,
                  errore: _errore,
                  largo: largo,
                  onRiprova: _caricaVisite,
                  onNuova: () => _apriForm(),
                  onModifica: (visita) => _apriForm(visita),
                  onElimina: _elimina,
                  onSposta: _sposta,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Barra con navigazione del giorno e pulsante "Nuova visita".
class _BarraVisite extends StatelessWidget {
  const _BarraVisite({
    required this.largo,
    required this.controller,
    required this.etichettaGiorno,
    required this.onPrecedente,
    required this.onSuccessivo,
    required this.onApplicaData,
    required this.onOggi,
    required this.onNuova,
  });

  final bool largo;
  final TextEditingController controller;
  final String etichettaGiorno;
  final VoidCallback onPrecedente;
  final VoidCallback onSuccessivo;
  final VoidCallback onApplicaData;
  final VoidCallback onOggi;
  final VoidCallback onNuova;

  @override
  Widget build(BuildContext context) {
    final navigazione = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('visite-giorno-precedente'),
          tooltip: 'Giorno precedente',
          onPressed: onPrecedente,
          icon: const Icon(Icons.chevron_left),
        ),
        SizedBox(
          width: 150,
          child: TextField(
            key: const Key('visite-data'),
            controller: controller,
            textAlign: TextAlign.center,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onApplicaData(),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9/]')),
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Data',
              hintText: 'gg/mm/aaaa',
              isDense: true,
            ),
          ),
        ),
        IconButton(
          key: const Key('visite-giorno-successivo'),
          tooltip: 'Giorno successivo',
          onPressed: onSuccessivo,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    final pulsanteOggi = TextButton(
      key: const Key('visite-oggi'),
      onPressed: onOggi,
      child: const Text('Oggi'),
    );

    final pulsanteNuova = FilledButton.icon(
      key: const Key('nuova-visita'),
      onPressed: onNuova,
      icon: const Icon(Icons.add),
      label: const Text('Nuova visita'),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: navigazione),
          Center(
            child: Text(
              etichettaGiorno,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          const SizedBox(height: AppSpazi.xs),
          Row(
            children: [
              pulsanteOggi,
              const SizedBox(width: AppSpazi.xs),
              Expanded(child: pulsanteNuova),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        navigazione,
        const SizedBox(width: AppSpazi.xs),
        pulsanteOggi,
        const SizedBox(width: AppSpazi.xs),
        Text(etichettaGiorno),
        const Spacer(),
        pulsanteNuova,
      ],
    );
  }
}

/// Corpo della lista: stati caricamento/errore/vuoto e lista responsive.
///
/// È pubblico e senza provider per poter essere verificato con un widget test
/// senza Firebase.
class ElencoVisite extends StatelessWidget {
  const ElencoVisite({
    super.key,
    required this.visite,
    required this.caricamento,
    required this.onRiprova,
    required this.onNuova,
    required this.onModifica,
    required this.onElimina,
    required this.onSposta,
    this.errore,
    this.largo = false,
  });

  final List<Visita> visite;
  final bool caricamento;
  final Object? errore;
  final bool largo;
  final VoidCallback onRiprova;
  final VoidCallback onNuova;
  final ValueChanged<Visita> onModifica;
  final ValueChanged<Visita> onElimina;

  /// Callback con indice nella lista mostrata e scarto (-1 su, +1 giù).
  final void Function(int indice, int scarto) onSposta;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('visite-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Visite non disponibili',
        sottotitolo: messaggioErroreVisite(errore!),
        azione: OutlinedButton.icon(
          key: const Key('visite-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (visite.isEmpty) {
      return StatoCentrato(
        icona: Icons.event_outlined,
        titolo: 'Nessuna visita',
        sottotitolo:
            'Aggiungi la prima visita del giorno con il pulsante "Nuova '
            'visita".',
        azione: FilledButton.icon(
          key: const Key('visite-nuova-vuoto'),
          onPressed: onNuova,
          icon: const Icon(Icons.add),
          label: const Text('Nuova visita'),
        ),
      );
    }

    return largo
        ? _TabellaVisite(
            visite: visite,
            onModifica: onModifica,
            onElimina: onElimina,
            onSposta: onSposta,
          )
        : _ListaVisite(
            visite: visite,
            onModifica: onModifica,
            onElimina: onElimina,
            onSposta: onSposta,
          );
  }
}

/// Badge colorato con l'etichetta dello stato della visita.
class BadgeStatoVisita extends StatelessWidget {
  const BadgeStatoVisita({super.key, required this.stato});

  final String stato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoVisita(stato);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpazi.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRaggi.chip),
      ),
      child: Text(
        etichettaStatoVisita(stato),
        style: tema.textTheme.labelSmall?.copyWith(color: colore),
      ),
    );
  }
}

/// Elenco a card (telefono).
class _ListaVisite extends StatelessWidget {
  const _ListaVisite({
    required this.visite,
    required this.onModifica,
    required this.onElimina,
    required this.onSposta,
  });

  final List<Visita> visite;
  final ValueChanged<Visita> onModifica;
  final ValueChanged<Visita> onElimina;
  final void Function(int indice, int scarto) onSposta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListView.separated(
      key: const Key('lista-visite'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: visite.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) {
        final visita = visite[indice];
        final note = visita.note?.trim() ?? '';
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('visita-${visita.id}'),
            onTap: () => onModifica(visita),
            child: Padding(
              padding: const EdgeInsets.all(AppSpazi.m),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      oraVisita(visita),
                      style: tema.textTheme.titleSmall,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                nomeClienteVisita(visita),
                                style: tema.textTheme.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpazi.xs),
                            BadgeStatoVisita(stato: visita.stato),
                          ],
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: AppSpazi.xxs),
                          Text(
                            note,
                            style: tema.textTheme.bodySmall?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: ValueKey('visita-su-${visita.id}'),
                        tooltip: 'Sposta su',
                        visualDensity: VisualDensity.compact,
                        onPressed:
                            indice == 0 ? null : () => onSposta(indice, -1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        key: ValueKey('visita-giu-${visita.id}'),
                        tooltip: 'Sposta giù',
                        visualDensity: VisualDensity.compact,
                        onPressed: indice == visite.length - 1
                            ? null
                            : () => onSposta(indice, 1),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                    ],
                  ),
                  MenuAzioni(
                    key: ValueKey('menu-visita-${visita.id}'),
                    tooltip: 'Azioni visita',
                    onModifica: () => onModifica(visita),
                    onElimina: () => onElimina(visita),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Elenco tabellare (da 600 px in su).
class _TabellaVisite extends StatelessWidget {
  const _TabellaVisite({
    required this.visite,
    required this.onModifica,
    required this.onElimina,
    required this.onSposta,
  });

  final List<Visita> visite;
  final ValueChanged<Visita> onModifica;
  final ValueChanged<Visita> onElimina;
  final void Function(int indice, int scarto) onSposta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('tabella-visite'),
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Ora')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Stato')),
            DataColumn(label: Text('Note')),
            DataColumn(label: Text('Ordine')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (var indice = 0; indice < visite.length; indice++)
              DataRow(
                key: ValueKey('visita-${visite[indice].id}'),
                onSelectChanged: (_) => onModifica(visite[indice]),
                cells: [
                  DataCell(Text(oraVisita(visite[indice]))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 220),
                      child: Text(
                        nomeClienteVisita(visite[indice]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    BadgeStatoVisita(stato: visite[indice].stato),
                  ),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        noteVisita(visite[indice]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          key: ValueKey('visita-su-${visite[indice].id}'),
                          tooltip: 'Sposta su',
                          onPressed: indice == 0
                              ? null
                              : () => onSposta(indice, -1),
                          icon: const Icon(Icons.arrow_upward, size: 18),
                        ),
                        IconButton(
                          key: ValueKey('visita-giu-${visite[indice].id}'),
                          tooltip: 'Sposta giù',
                          onPressed: indice == visite.length - 1
                              ? null
                              : () => onSposta(indice, 1),
                          icon: const Icon(Icons.arrow_downward, size: 18),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    MenuAzioni(
                      key: ValueKey('menu-visita-${visite[indice].id}'),
                      tooltip: 'Azioni visita',
                      onModifica: () => onModifica(visite[indice]),
                      onElimina: () => onElimina(visite[indice]),
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

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

/// Form completo di una visita, aperto a pagina intera (nuova o modifica).
class VisitaFormScreen extends ConsumerStatefulWidget {
  const VisitaFormScreen({
    super.key,
    this.visita,
    this.dataIniziale,
    this.ordineIniziale = 0,
  });

  /// Visita da modificare; `null` per crearne una nuova.
  final Visita? visita;

  /// Giorno proposto per una nuova visita (default: oggi).
  final DateTime? dataIniziale;

  /// Posizione proposta in fondo al giro per una nuova visita.
  final int ordineIniziale;

  @override
  ConsumerState<VisitaFormScreen> createState() => _VisitaFormScreenState();
}

class _VisitaFormScreenState extends ConsumerState<VisitaFormScreen> {
  final _modulo = GlobalKey<FormState>();

  late final TextEditingController _data;
  late final TextEditingController _ora;
  late final TextEditingController _note;

  late DateTime _dataScelta;
  late String _stato;
  String? _clienteId;

  List<Cliente> _clienti = const [];
  bool _caricamentoClienti = true;
  Object? _erroreClienti;

  bool _salvando = false;
  String? _errore;

  bool get _modifica => widget.visita != null;

  @override
  void initState() {
    super.initState();
    final visita = widget.visita;
    _dataScelta = parseDataItaliana(visita?.data) ??
        widget.dataIniziale ??
        DateTime.now();
    _data = TextEditingController(text: formattaDataVisita(_dataScelta));
    _ora = TextEditingController(text: visita?.ora ?? '');
    _note = TextEditingController(text: visita?.note ?? '');
    _clienteId = visita?.clienteId;

    final stato = (visita?.stato ?? 'da_fare').trim().toLowerCase();
    _stato = statiVisita.containsKey(stato) ? stato : 'da_fare';

    _caricaClienti();
  }

  @override
  void dispose() {
    _data.dispose();
    _ora.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _caricaClienti() async {
    setState(() {
      _caricamentoClienti = true;
      _erroreClienti = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final clienti = await servizio.getClienti();
      if (!mounted) return;
      setState(() {
        _clienti = clienti;
        _caricamentoClienti = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _erroreClienti = errore;
        _caricamentoClienti = false;
      });
    }
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
      for (final cliente in _clienti)
        cliente.id: () {
          final nome = cliente.nome?.trim() ?? '';
          return nome.isEmpty ? '(senza nome)' : nome;
        }(),
    };
    final id = _clienteId;
    if (id != null && id.isNotEmpty && !opzioni.containsKey(id)) {
      final nome = widget.visita?.clienteNome?.trim() ?? '';
      opzioni[id] = nome.isEmpty ? 'Cliente non disponibile' : nome;
    }
    return opzioni;
  }

  Future<void> _salva() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    final giorno = parseDataItaliana(_data.text);
    if (giorno == null) return;

    final cliente = _clienteSelezionato;
    final visita = widget.visita;

    setState(() => _salvando = true);
    final dati = <String, dynamic>{
      'utente_id': visita?.utenteId ??
          ref.read(firebaseAuthProvider).currentUser?.uid,
      'cliente_id': _clienteId,
      'cliente_nome': cliente?.nome ??
          (cliente == null ? visita?.clienteNome : null),
      'telefono': cliente?.telefono ?? visita?.telefono,
      'indirizzo': (cliente == null ? null : indirizzoCliente(cliente)) ??
          visita?.indirizzo,
      'data': dataIsoVisita(giorno),
      'ora': normalizzaOraVisita(_ora.text),
      'ordine': visita?.ordine ?? widget.ordineIniziale,
      'stato': _stato,
      'note': _note.text,
      'visita_padre_id': visita?.visitaPadreId,
      'promemoria_min': visita?.promemoriaMin,
      'promemoria_at': visita?.promemoriaAt,
      'promemoria_numero': visita?.promemoriaNumero,
      'promemoria_inviato_at': visita?.promemoriaInviatoAt,
    };

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      if (_modifica) {
        await servizio.aggiornaVisita(visita!.id, dati);
      } else {
        await servizio.aggiungiVisita(dati);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreVisite(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final opzioniClienti = _opzioniClienti;

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica visita' : 'Nuova visita'),
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
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'VISITA',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            if (_caricamentoClienti)
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSpazi.s,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              )
                            else
                              DropdownButtonFormField<String>(
                                key: const Key('visita-cliente'),
                                initialValue: _clienteId,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Cliente *',
                                ),
                                validator: (valore) {
                                  if (valore == null || valore.isEmpty) {
                                    return 'Scegli un cliente';
                                  }
                                  return null;
                                },
                                items: [
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
                                onChanged: _salvando
                                    ? null
                                    : (valore) =>
                                        setState(() => _clienteId = valore),
                              ),
                            if (_erroreClienti != null) ...[
                              const SizedBox(height: AppSpazi.s),
                              AvvisoErrore(
                                key: const Key('errore-clienti-visita'),
                                testo: messaggioErroreVisite(_erroreClienti!),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  key: const Key('riprova-clienti-visita'),
                                  onPressed: _caricaClienti,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Riprova clienti'),
                                ),
                              ),
                            ],
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
                                    SizedBox(
                                      width: larghezza,
                                      child: TextFormField(
                                        key: const Key('visita-data'),
                                        controller: _data,
                                        enabled: !_salvando,
                                        textInputAction: TextInputAction.next,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9/]'),
                                          ),
                                          LengthLimitingTextInputFormatter(
                                            10,
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Data *',
                                          hintText: 'gg/mm/aaaa',
                                        ),
                                        validator: validaDataVisita,
                                      ),
                                    ),
                                    SizedBox(
                                      width: larghezza,
                                      child: TextFormField(
                                        key: const Key('visita-ora'),
                                        controller: _ora,
                                        enabled: !_salvando,
                                        textInputAction: TextInputAction.next,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9:]'),
                                          ),
                                          LengthLimitingTextInputFormatter(
                                            5,
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Ora',
                                          hintText: '09:30',
                                        ),
                                        validator: validaOraVisita,
                                      ),
                                    ),
                                    SizedBox(
                                      width: larghezza,
                                      child: DropdownButtonFormField<String>(
                                        key: const Key('visita-stato'),
                                        initialValue: _stato,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                          labelText: 'Stato',
                                        ),
                                        items: [
                                          for (final voce
                                              in statiVisita.entries)
                                            DropdownMenuItem(
                                              value: voce.key,
                                              child: Text(voce.value),
                                            ),
                                        ],
                                        onChanged: _salvando
                                            ? null
                                            : (valore) {
                                                if (valore == null) return;
                                                setState(() => _stato = valore);
                                              },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('visita-note'),
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
                      ),
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('errore-visita'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-visita'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-visita'),
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
                                    _modifica
                                        ? 'Salva modifiche'
                                        : 'Crea visita',
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
