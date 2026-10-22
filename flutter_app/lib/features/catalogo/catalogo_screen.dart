import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/menu_azioni.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/categoria.dart';
import '../../data/models/prodotto.dart';
import '../../state/azienda_providers.dart';
import '../../state/catalogo_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure: validazioni, formati e messaggi (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Validazione del nome prodotto: obbligatorio.
String? validaNomeProdotto(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il nome del prodotto';
  return null;
}

/// Converte il testo del campo prezzo in numero, accettando la virgola
/// decimale italiana. Ritorna `null` se il campo è vuoto o non numerico.
double? prezzoDaTesto(String? valore) {
  final testo = (valore ?? '').trim();
  if (testo.isEmpty) return null;

  final normalizzato = testo.contains(',') && testo.contains('.')
      ? testo.replaceAll('.', '').replaceAll(',', '.')
      : testo.replaceAll(',', '.');
  return double.tryParse(normalizzato);
}

/// Validazione del prezzo: facoltativo, ma se presente deve essere un numero
/// maggiore o uguale a zero.
String? validaPrezzo(String? valore) {
  final testo = (valore ?? '').trim();
  if (testo.isEmpty) return null;

  final prezzo = prezzoDaTesto(testo);
  if (prezzo == null) return 'Inserisci un prezzo valido, es. 120,50';
  if (prezzo < 0) return 'Il prezzo non può essere negativo';
  return null;
}

/// Validazione del nome categoria: obbligatorio.
String? validaNomeCategoria(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il nome della categoria';
  return null;
}

/// Prezzo in euro con formato italiano (`1.234,50 €`), `—` se assente.
String formattaPrezzo(num? prezzo) {
  if (prezzo == null) return '—';
  return NumberFormat.currency(
    locale: 'it_IT',
    symbol: '€',
    decimalDigits: 2,
  ).format(prezzo);
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio catalogo.
String messaggioErroreCatalogo(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per gestire il catalogo. '
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

/// Codice del prodotto ripulito dagli spazi, `—` se assente.
String codiceVisualizzatoProdotto(Prodotto prodotto) {
  final codice = prodotto.codice?.trim() ?? '';
  return codice.isEmpty ? '—' : codice;
}

/// Testo del prodotto, con fallback per i documenti senza nome.
String nomeVisualizzatoProdotto(Prodotto prodotto) {
  final nome = prodotto.nome?.trim() ?? '';
  return nome.isEmpty ? '(senza nome)' : nome;
}

/// Riepilogo del paniere di un prodotto, per il sottotitolo della card.
///
/// Ritorna una stringa vuota se il prodotto non ha sotto-prodotti, altrimenti
/// `Paniere: N sotto-prodotti`, con l'aggiunta di `· a prezzo zero` quando i
/// figli sono venduti a prezzo zero.
String etichettaPaniere(Prodotto prodotto) {
  final numero = prodotto.figliIds.length;
  if (numero == 0) return '';

  final sostantivo = numero == 1 ? 'sotto-prodotto' : 'sotto-prodotti';
  final prezzoZero = prodotto.figliAZero ? ' · a prezzo zero' : '';
  return 'Paniere: $numero $sostantivo$prezzoZero';
}

/// Cella della colonna "Paniere" della tabella: `—` se non ci sono figli.
String etichettaFigli(Prodotto prodotto) {
  final numero = prodotto.figliIds.length;
  if (numero == 0) return '—';
  return '$numero ${numero == 1 ? 'figlio' : 'figli'}';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Catalogo dell'azienda attiva: prodotti e categorie in due schede.
class CatalogoScreen extends ConsumerStatefulWidget {
  const CatalogoScreen({super.key});

  @override
  ConsumerState<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends ConsumerState<CatalogoScreen> {
  final _ricerca = TextEditingController();

  /// Nome della categoria usata come filtro; stringa vuota = tutte.
  String _filtroCategoria = '';

  @override
  void initState() {
    super.initState();
    _ricerca.addListener(_aggiornaRicerca);
  }

  @override
  void dispose() {
    _ricerca.removeListener(_aggiornaRicerca);
    _ricerca.dispose();
    super.dispose();
  }

  void _aggiornaRicerca() => setState(() {});

  void _ricarica() => ref.invalidate(catalogoProvider);

  /// Apre il form prodotto a pagina intera e ricarica se il salvataggio riesce.
  Future<void> _apriProdotto({
    Prodotto? prodotto,
    required List<Categoria> categorie,
    required List<Prodotto> prodotti,
  }) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProdottoFormScreen(
          prodotto: prodotto,
          categorie: categorie,
          prodotti: prodotti,
        ),
      ),
    );
    if (salvato == true) _ricarica();
  }

  /// Apre il form categoria a pagina intera e ricarica se il salvataggio riesce.
  Future<void> _apriCategoria({Categoria? categoria}) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoriaFormScreen(categoria: categoria),
      ),
    );
    if (salvato == true) _ricarica();
  }

  Future<void> _eliminaProdotto(Prodotto prodotto) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-elimina-prodotto'),
        title: const Text('Eliminare il prodotto?'),
        content: Text(
          'Il prodotto "${nomeVisualizzatoProdotto(prodotto)}" verrà '
          'eliminato definitivamente dal catalogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-elimina-prodotto'),
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
      await servizio.eliminaProdotto(prodotto.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prodotto eliminato')),
      );
      _ricarica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreCatalogo(errore))),
      );
    }
  }

  Future<void> _eliminaCategoria(Categoria categoria) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-elimina-categoria'),
        title: const Text('Eliminare la categoria?'),
        content: Text(
          'La categoria "${_testo(categoria.nome)}" verrà eliminata '
          'definitivamente. I prodotti che la usano restano nel catalogo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-elimina-categoria'),
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
      await servizio.eliminaCategoria(categoria.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoria eliminata')),
      );
      _ricarica();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreCatalogo(errore))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(catalogoProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(text: 'Prodotti'),
                Tab(text: 'Categorie'),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(
                key: Key('catalogo-caricamento'),
                child: CircularProgressIndicator(),
              ),
              error: (errore, _) => StatoCentrato(
                icona: Icons.cloud_off_outlined,
                titolo: 'Catalogo non disponibile',
                sottotitolo: messaggioErroreCatalogo(errore),
                azione: OutlinedButton.icon(
                  key: const Key('catalogo-riprova'),
                  onPressed: _ricarica,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ),
              data: (dati) => TabBarView(
                children: [
                  _schedaProdotti(dati),
                  _schedaCategorie(dati),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- scheda Prodotti ----------

  Widget _schedaProdotti(DatiCatalogo dati) {
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
              child: _BarraProdotti(
                largo: largo,
                controller: _ricerca,
                categorie: dati.categorie,
                filtro: _filtroCategoria,
                onFiltro: (valore) => setState(() => _filtroCategoria = valore),
                onNuovo: () => _apriProdotto(
                  categorie: dati.categorie,
                  prodotti: dati.prodotti,
                ),
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
                child: _contenutoProdotti(dati, largo),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _contenutoProdotti(DatiCatalogo dati, bool largo) {
    if (dati.prodotti.isEmpty) {
      return StatoCentrato(
        icona: Icons.inventory_2_outlined,
        titolo: 'Nessun prodotto',
        sottotitolo:
            'Aggiungi il primo prodotto con il pulsante "Nuovo prodotto".',
        azione: FilledButton.icon(
          key: const Key('catalogo-nuovo-prodotto-vuoto'),
          onPressed: () => _apriProdotto(
            categorie: dati.categorie,
            prodotti: dati.prodotti,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Nuovo prodotto'),
        ),
      );
    }

    final filtrati = _prodottiFiltrati(dati.prodotti);
    if (filtrati.isEmpty) {
      return const StatoCentrato(
        icona: Icons.search_off,
        titolo: 'Nessun prodotto trovato',
        sottotitolo: 'Prova a cambiare i termini di ricerca o la categoria.',
      );
    }

    return largo
        ? _TabellaProdotti(
            prodotti: filtrati,
            onModifica: (prodotto) => _apriProdotto(
              prodotto: prodotto,
              categorie: dati.categorie,
              prodotti: dati.prodotti,
            ),
            onElimina: _eliminaProdotto,
          )
        : _ListaProdotti(
            prodotti: filtrati,
            onModifica: (prodotto) => _apriProdotto(
              prodotto: prodotto,
              categorie: dati.categorie,
              prodotti: dati.prodotti,
            ),
            onElimina: _eliminaProdotto,
          );
  }

  List<Prodotto> _prodottiFiltrati(List<Prodotto> prodotti) {
    final testo = _ricerca.text.trim().toLowerCase();
    return prodotti.where((prodotto) {
      final nome = (prodotto.nome ?? '').toLowerCase();
      final categoria = prodotto.categoria?.trim() ?? '';
      final okNome = testo.isEmpty || nome.contains(testo);
      final okCategoria =
          _filtroCategoria.isEmpty || categoria == _filtroCategoria;
      return okNome && okCategoria;
    }).toList();
  }

  // ---------- scheda Categorie ----------

  Widget _schedaCategorie(DatiCatalogo dati) {
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
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  key: const Key('nuova-categoria'),
                  onPressed: _apriCategoria,
                  icon: const Icon(Icons.add),
                  label: const Text('Nuova categoria'),
                ),
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
                child: dati.categorie.isEmpty
                    ? StatoCentrato(
                        icona: Icons.label_outline,
                        titolo: 'Nessuna categoria',
                        sottotitolo:
                            'Crea la prima categoria per raggruppare i '
                            'prodotti del catalogo.',
                        azione: FilledButton.icon(
                          key: const Key('catalogo-nuova-categoria-vuota'),
                          onPressed: _apriCategoria,
                          icon: const Icon(Icons.add),
                          label: const Text('Nuova categoria'),
                        ),
                      )
                    : _ListaCategorie(
                        categorie: dati.categorie,
                        onModifica: (categoria) =>
                            _apriCategoria(categoria: categoria),
                        onElimina: _eliminaCategoria,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Barra di ricerca e filtri
// ---------------------------------------------------------------------------

/// Ricerca per nome, filtro per categoria e pulsante "Nuovo prodotto".
class _BarraProdotti extends StatelessWidget {
  const _BarraProdotti({
    required this.largo,
    required this.controller,
    required this.categorie,
    required this.filtro,
    required this.onFiltro,
    required this.onNuovo,
  });

  final bool largo;
  final TextEditingController controller;
  final List<Categoria> categorie;
  final String filtro;
  final ValueChanged<String> onFiltro;
  final VoidCallback onNuovo;

  @override
  Widget build(BuildContext context) {
    final campoRicerca = TextField(
      key: const Key('catalogo-ricerca'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cerca per nome',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('catalogo-azzera-ricerca'),
                tooltip: 'Azzera ricerca',
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              ),
      ),
    );

    final filtroCategoria = DropdownButtonFormField<String>(
      key: const Key('catalogo-filtro-categoria'),
      initialValue: filtro,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Categoria'),
      items: [
        const DropdownMenuItem(value: '', child: Text('Tutte le categorie')),
        for (final categoria in categorie)
          if ((categoria.nome ?? '').trim().isNotEmpty)
            DropdownMenuItem(
              value: categoria.nome!.trim(),
              child: Text(
                categoria.nome!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
      ],
      onChanged: (valore) => onFiltro(valore ?? ''),
    );

    final pulsante = FilledButton.icon(
      key: const Key('nuovo-prodotto'),
      onPressed: onNuovo,
      icon: const Icon(Icons.add),
      label: const Text('Nuovo prodotto'),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          campoRicerca,
          const SizedBox(height: AppSpazi.xs),
          filtroCategoria,
          const SizedBox(height: AppSpazi.xs),
          pulsante,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: campoRicerca),
        const SizedBox(width: AppSpazi.s),
        SizedBox(width: 220, child: filtroCategoria),
        const SizedBox(width: AppSpazi.s),
        pulsante,
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Elenchi prodotti
// ---------------------------------------------------------------------------

/// Elenco a card (telefono).
class _ListaProdotti extends StatelessWidget {
  const _ListaProdotti({
    required this.prodotti,
    required this.onModifica,
    required this.onElimina,
  });

  final List<Prodotto> prodotti;
  final ValueChanged<Prodotto> onModifica;
  final ValueChanged<Prodotto> onElimina;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('lista-prodotti'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: prodotti.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) {
        final prodotto = prodotti[indice];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: ValueKey('prodotto-${prodotto.id}'),
            onTap: () => onModifica(prodotto),
            leading: MiniaturaProdotto(immagine: prodotto.immagine),
            title: Text(nomeVisualizzatoProdotto(prodotto)),
            subtitle: Text(_dettagliProdotto(prodotto)),
            trailing: MenuAzioni(
              key: ValueKey('menu-prodotto-${prodotto.id}'),
              tooltip: 'Azioni prodotto',
              onModifica: () => onModifica(prodotto),
              onElimina: () => onElimina(prodotto),
            ),
          ),
        );
      },
    );
  }
}

/// Elenco tabellare (da 600 px in su).
class _TabellaProdotti extends StatelessWidget {
  const _TabellaProdotti({
    required this.prodotti,
    required this.onModifica,
    required this.onElimina,
  });

  final List<Prodotto> prodotti;
  final ValueChanged<Prodotto> onModifica;
  final ValueChanged<Prodotto> onElimina;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('tabella-prodotti'),
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Prodotto')),
            DataColumn(label: Text('Codice')),
            DataColumn(label: Text('Categoria')),
            DataColumn(label: Text('Paniere')),
            DataColumn(label: Text('Descrizione')),
            DataColumn(label: Text('Prezzo'), numeric: true),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final prodotto in prodotti)
              DataRow(
                key: ValueKey('prodotto-${prodotto.id}'),
                onSelectChanged: (_) => onModifica(prodotto),
                cells: [
                  DataCell(Text(nomeVisualizzatoProdotto(prodotto))),
                  DataCell(Text(codiceVisualizzatoProdotto(prodotto))),
                  DataCell(Text(_testo(prodotto.categoria))),
                  DataCell(Text(etichettaFigli(prodotto))),
                  DataCell(Text(_testo(prodotto.descrizione))),
                  DataCell(Text(formattaPrezzo(prodotto.prezzo))),
                  DataCell(
                    MenuAzioni(
                      key: ValueKey('menu-prodotto-${prodotto.id}'),
                      tooltip: 'Azioni prodotto',
                      onModifica: () => onModifica(prodotto),
                      onElimina: () => onElimina(prodotto),
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

/// Miniatura dell'immagine di un prodotto (URL, data URL o icona).
class MiniaturaProdotto extends StatelessWidget {
  const MiniaturaProdotto({
    super.key,
    required this.immagine,
    this.lato = 48,
  });

  /// Valore del campo `immagine` del prodotto.
  final String? immagine;
  final double lato;

  @override
  Widget build(BuildContext context) {
    final testo = (immagine ?? '').trim();
    // In Flutter `Image.network` vuole un `BuildContext` per gli errori, quindi
    // l'anteprima usa `errorBuilder` e ricade sull'icona segnaposto.
    Widget contenuto;
    if (testo.startsWith('data:image')) {
      final virgola = testo.indexOf(',');
      try {
        contenuto = Image.memory(
          base64Decode(testo.substring(virgola + 1)),
          fit: BoxFit.cover,
        );
      } catch (_) {
        contenuto = const Icon(Icons.image_not_supported_outlined);
      }
    } else if (testo.startsWith('http')) {
      contenuto = Image.network(
        testo,
        fit: BoxFit.cover,
        errorBuilder: (context, errore, traccia) =>
            const Icon(Icons.image_not_supported_outlined),
      );
    } else {
      contenuto = const Icon(Icons.inventory_2_outlined);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRaggi.chip),
      child: SizedBox(width: lato, height: lato, child: contenuto),
    );
  }
}

// ---------------------------------------------------------------------------
// Elenco categorie
// ---------------------------------------------------------------------------

/// Elenco delle categorie con icona, nome e ordine.
class _ListaCategorie extends StatelessWidget {
  const _ListaCategorie({
    required this.categorie,
    required this.onModifica,
    required this.onElimina,
  });

  final List<Categoria> categorie;
  final ValueChanged<Categoria> onModifica;
  final ValueChanged<Categoria> onElimina;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('lista-categorie'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: categorie.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) {
        final categoria = categorie[indice];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: ValueKey('categoria-${categoria.id}'),
            onTap: () => onModifica(categoria),
            leading: IconaCategoria(icona: categoria.icona),
            title: Text(_testo(categoria.nome)),
            subtitle: Text('Ordine: ${categoria.ordine ?? 0}'),
            trailing: MenuAzioni(
              key: ValueKey('menu-categoria-${categoria.id}'),
              tooltip: 'Azioni categoria',
              onModifica: () => onModifica(categoria),
              onElimina: () => onElimina(categoria),
            ),
          ),
        );
      },
    );
  }
}

/// Icona (emoji) di una categoria dentro un cerchio colorato.
class IconaCategoria extends StatelessWidget {
  const IconaCategoria({super.key, required this.icona});

  /// Emoji o simbolo salvato nel campo `icona`.
  final String? icona;

  @override
  Widget build(BuildContext context) {
    final testo = (icona ?? '').trim();
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      child: testo.isEmpty
          ? const Icon(Icons.label_outline, size: 20)
          : Text(testo, style: const TextStyle(fontSize: 18)),
    );
  }
}

// ---------------------------------------------------------------------------
// Form prodotto
// ---------------------------------------------------------------------------

/// Form completo di un prodotto, aperto a pagina intera (nuovo o modifica).
class ProdottoFormScreen extends ConsumerStatefulWidget {
  const ProdottoFormScreen({
    super.key,
    this.prodotto,
    this.categorie = const [],
    this.prodotti = const [],
  });

  /// Prodotto da modificare; `null` per crearne uno nuovo.
  final Prodotto? prodotto;

  /// Categorie disponibili nella tendina (nome usato come valore salvato).
  final List<Categoria> categorie;

  /// Tutti i prodotti dell'azienda, per scegliere i sotto-prodotti (figli).
  final List<Prodotto> prodotti;

  @override
  ConsumerState<ProdottoFormScreen> createState() => _ProdottoFormScreenState();
}

class _ProdottoFormScreenState extends ConsumerState<ProdottoFormScreen> {
  final _modulo = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _codice;
  late final TextEditingController _prezzo;
  late final TextEditingController _descrizione;
  late final TextEditingController _immagine;
  late final TextEditingController _cercaFiglio;

  /// Nomi delle categorie, senza duplicati e nell'ordine del catalogo.
  late final List<String> _nomiCategorie;

  /// Id dei prodotti scelti come sotto-prodotti.
  final Set<String> _figliIds = {};

  /// Se `true`, i sotto-prodotti vengono venduti a prezzo zero.
  bool _figliAZero = false;

  String? _categoria;
  bool _salvando = false;
  String? _errore;

  bool get _modifica => widget.prodotto != null;

  @override
  void initState() {
    super.initState();
    final prodotto = widget.prodotto;

    _nome = TextEditingController(text: prodotto?.nome ?? '');
    _codice = TextEditingController(text: prodotto?.codice ?? '');
    _prezzo = TextEditingController(text: _testoPrezzo(prodotto?.prezzo));
    _descrizione = TextEditingController(text: prodotto?.descrizione ?? '');
    _immagine = TextEditingController(text: prodotto?.immagine ?? '');
    _cercaFiglio = TextEditingController();

    _figliIds.addAll(prodotto?.figliIds ?? const <String>[]);
    _figliAZero = prodotto?.figliAZero ?? false;

    _nomiCategorie = <String>{
      for (final categoria in widget.categorie)
        if ((categoria.nome ?? '').trim().isNotEmpty) categoria.nome!.trim(),
    }.toList();

    final categoriaProdotto = prodotto?.categoria?.trim();
    if (categoriaProdotto != null &&
        _nomiCategorie.contains(categoriaProdotto)) {
      _categoria = categoriaProdotto;
    } else if (_nomiCategorie.isNotEmpty) {
      _categoria = _nomiCategorie.first;
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _codice.dispose();
    _prezzo.dispose();
    _descrizione.dispose();
    _immagine.dispose();
    _cercaFiglio.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    final dati = <String, dynamic>{
      'nome': _nome.text,
      'codice': _codice.text,
      'categoria': _categoria ?? '',
      'prezzo': prezzoDaTesto(_prezzo.text) ?? 0,
      'descrizione': _descrizione.text,
      'immagine': _immagine.text,
      'attivo': widget.prodotto?.attivo ?? true,
      'figliIds': _figliIds.toList(growable: false),
      'figliAZero': _figliAZero,
    };

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      if (_modifica) {
        await servizio.aggiornaProdotto(widget.prodotto!.id, dati);
      } else {
        await servizio.inserisciProdotto(dati);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreCatalogo(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Prodotti proponibili come sotto-prodotti: attivi, diversi da questo e
  /// filtrati dal testo di ricerca.
  List<Prodotto> get _prodottiFigliDisponibili {
    final ricerca = _cercaFiglio.text.trim().toLowerCase();
    return widget.prodotti.where((prodotto) {
      if (prodotto.id == widget.prodotto?.id) return false;
      if (!prodotto.attivo) return false;
      if (ricerca.isEmpty) return true;
      return (prodotto.nome ?? '').toLowerCase().contains(ricerca);
    }).toList();
  }

  /// Id selezionati che non possono più essere usati come figli.
  List<String> get _figliNonDisponibili {
    final utilizzabili = <String>{
      for (final prodotto in widget.prodotti)
        if (prodotto.attivo && prodotto.id != widget.prodotto?.id) prodotto.id,
    };
    return _figliIds.where((id) => !utilizzabili.contains(id)).toList();
  }

  Widget _schedaPaniere(ThemeData tema) {
    final disponibili = _prodottiFigliDisponibili;
    final nonDisponibili = _figliNonDisponibili;

    return Card(
      key: const Key('prodotto-paniere'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.m),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Paniere (sotto-prodotti)', style: tema.textTheme.titleMedium),
            const SizedBox(height: AppSpazi.xxs),
            Text(
              'Scegli i prodotti da vendere insieme a questo. I sotto-prodotti '
              'entrano nel preventivo quando aggiungi il prodotto.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            SwitchListTile(
              key: const Key('prodotto-figli-a-zero'),
              contentPadding: EdgeInsets.zero,
              value: _figliAZero,
              onChanged: _salvando
                  ? null
                  : (valore) => setState(() => _figliAZero = valore),
              title: const Text('Vendi i sotto-prodotti a prezzo zero'),
            ),
            const SizedBox(height: AppSpazi.s),
            TextField(
              key: const Key('prodotto-cerca-figlio'),
              controller: _cercaFiglio,
              enabled: !_salvando,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Cerca sotto-prodotti',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _cercaFiglio.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Azzera ricerca',
                        onPressed: () => setState(_cercaFiglio.clear),
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            Text(
              'Selezionati: ${_figliIds.length}',
              key: const Key('prodotto-figli-selezionati'),
              style: tema.textTheme.bodyMedium,
            ),
            if (widget.prodotti.where((p) => p.id != widget.prodotto?.id).isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpazi.s),
                child: Text(
                  'Crea prima altri prodotti per usarli come sotto-prodotti.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (disponibili.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpazi.s),
                child: Text(
                  'Nessun prodotto trovato.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final prodotto in disponibili)
                CheckboxListTile(
                  key: ValueKey('prodotto-figlio-${prodotto.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: _figliIds.contains(prodotto.id),
                  onChanged: _salvando
                      ? null
                      : (selezionato) => setState(() {
                            if (selezionato == true) {
                              _figliIds.add(prodotto.id);
                            } else {
                              _figliIds.remove(prodotto.id);
                            }
                          }),
                  title: Text(
                    nomeVisualizzatoProdotto(prodotto),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(_dettagliProdotto(prodotto)),
                ),
            if (nonDisponibili.isNotEmpty) ...[
              const SizedBox(height: AppSpazi.s),
              Text(
                'Sotto-prodotti non più disponibili',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpazi.xxs),
              Wrap(
                spacing: AppSpazi.xs,
                runSpacing: AppSpazi.xxs,
                children: [
                  for (final id in nonDisponibili)
                    InputChip(
                      key: ValueKey('rimuovi-figlio-$id'),
                      label: const Text('Prodotto non disponibile'),
                      onDeleted: _salvando
                          ? null
                          : () => setState(() => _figliIds.remove(id)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final anteprima = _immagine.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica prodotto' : 'Nuovo prodotto'),
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
                            TextFormField(
                              key: const Key('prodotto-nome'),
                              controller: _nome,
                              enabled: !_salvando,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome *',
                                hintText: 'Es. Licenza software annuale',
                              ),
                              validator: validaNomeProdotto,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('prodotto-codice'),
                              controller: _codice,
                              enabled: !_salvando,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Codice prodotto',
                                hintText: 'Es. PRD-001',
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            DropdownButtonFormField<String>(
                              key: const Key('prodotto-categoria'),
                              initialValue: _categoria,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Categoria',
                              ),
                              items: [
                                for (final nome in _nomiCategorie)
                                  DropdownMenuItem(
                                    value: nome,
                                    child: Text(
                                      nome,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _salvando
                                  ? null
                                  : (valore) {
                                      if (valore == null) return;
                                      setState(() => _categoria = valore);
                                    },
                            ),
                            if (_nomiCategorie.isEmpty) ...[
                              const SizedBox(height: AppSpazi.xxs),
                              Text(
                                'Nessuna categoria disponibile: creala dalla '
                                'scheda Categorie.',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('prodotto-prezzo'),
                              controller: _prezzo,
                              enabled: !_salvando,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              textInputAction: TextInputAction.next,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Prezzo (€)',
                                hintText: 'Es. 120,50',
                              ),
                              validator: validaPrezzo,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('prodotto-descrizione'),
                              controller: _descrizione,
                              enabled: !_salvando,
                              minLines: 3,
                              maxLines: 5,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.newline,
                              decoration: const InputDecoration(
                                labelText: 'Descrizione',
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('prodotto-immagine'),
                              controller: _immagine,
                              enabled: !_salvando,
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'Immagine (URL)',
                                hintText: 'https://esempio.it/prodotto.png',
                              ),
                            ),
                            if (anteprima.isNotEmpty) ...[
                              const SizedBox(height: AppSpazi.s),
                              Row(
                                children: [
                                  MiniaturaProdotto(
                                    immagine: anteprima,
                                    lato: 64,
                                  ),
                                  const SizedBox(width: AppSpazi.s),
                                  Expanded(
                                    child: Text(
                                      'Anteprima immagine',
                                      style: tema.textTheme.bodySmall?.copyWith(
                                        color:
                                            tema.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _schedaPaniere(tema),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('errore-prodotto'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-prodotto'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-prodotto'),
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
                                        : 'Crea prodotto',
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

// ---------------------------------------------------------------------------
// Form categoria
// ---------------------------------------------------------------------------

/// Form di una categoria, aperto a pagina intera (nuova o modifica).
class CategoriaFormScreen extends ConsumerStatefulWidget {
  const CategoriaFormScreen({super.key, this.categoria});

  /// Categoria da modificare; `null` per crearne una nuova.
  final Categoria? categoria;

  @override
  ConsumerState<CategoriaFormScreen> createState() =>
      _CategoriaFormScreenState();
}

class _CategoriaFormScreenState extends ConsumerState<CategoriaFormScreen> {
  final _modulo = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _icona;
  late final TextEditingController _ordine;

  bool _salvando = false;
  String? _errore;

  bool get _modifica => widget.categoria != null;

  @override
  void initState() {
    super.initState();
    final categoria = widget.categoria;
    _nome = TextEditingController(text: categoria?.nome ?? '');
    _icona = TextEditingController(text: categoria?.icona ?? '');
    _ordine = TextEditingController(
      text: categoria?.ordine?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nome.dispose();
    _icona.dispose();
    _ordine.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    final dati = <String, dynamic>{
      'nome': _nome.text,
      'icona': _icona.text,
      'ordine': int.tryParse(_ordine.text.trim()) ?? 0,
    };

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      if (_modifica) {
        await servizio.aggiornaCategoria(widget.categoria!.id, dati);
      } else {
        await servizio.inserisciCategoria(dati);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
      return;
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreCatalogo(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica categoria' : 'Nuova categoria'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpazi.paginaTelefono),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
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
                            TextFormField(
                              key: const Key('categoria-nome'),
                              controller: _nome,
                              enabled: !_salvando,
                              textCapitalization: TextCapitalization.sentences,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome *',
                                hintText: 'Es. software',
                              ),
                              validator: validaNomeCategoria,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('categoria-icona'),
                              controller: _icona,
                              enabled: !_salvando,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Icona',
                                hintText: 'Es. 💻',
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('categoria-ordine'),
                              controller: _ordine,
                              enabled: !_salvando,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Ordine',
                                hintText: 'Es. 1',
                                helperText:
                                    'Le categorie con numero più basso '
                                    'compaiono prima.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('errore-categoria'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-categoria'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-categoria'),
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
                                        : 'Crea categoria',
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

// ---------------------------------------------------------------------------
// Helper di formattazione
// ---------------------------------------------------------------------------

/// Testo ripulito, `—` se vuoto.
String _testo(String? valore) {
  final testo = valore?.trim() ?? '';
  return testo.isEmpty ? '—' : testo;
}

/// Prezzo iniziale del form, con la virgola decimale italiana.
String _testoPrezzo(num? prezzo) {
  if (prezzo == null) return '';
  return prezzo.toString().replaceAll('.', ',');
}

/// Codice, categoria, prezzo e paniere di un prodotto, per il sottotitolo
/// della card.
String _dettagliProdotto(Prodotto prodotto) {
  final paniere = etichettaPaniere(prodotto);
  final codice = (prodotto.codice ?? '').trim();
  final parti = <String>[
    if (codice.isNotEmpty) codice,
    _testo(prodotto.categoria),
    if (prodotto.prezzo != null) formattaPrezzo(prodotto.prezzo),
    if (paniere.isNotEmpty) paniere,
  ];
  return parti.join(' · ');
}
