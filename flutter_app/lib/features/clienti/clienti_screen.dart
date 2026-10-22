import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/menu_azioni.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/cliente.dart';
import '../../data/services/vies_service.dart';
import '../../state/azienda_providers.dart';

/// Tipi cliente ammessi, allineati alla vecchia app (`index.html`).
const Map<String, String> tipiCliente = {
  'azienda': 'Azienda',
  'libero_professionista': 'Libero professionista',
  'privato': 'Privato',
};

/// Settori ammessi, allineati alla vecchia app.
const Map<String, String> settoriCliente = {
  'ristorazione': 'Ristorazione',
  'retail': 'Retail',
  'grande_distribuzione': 'Grande distribuzione',
  'altro': 'Altro',
};

/// Regioni italiane (stessi id di `REGIONI_ITALIA` in `js/bandi-data.js`).
const Map<String, String> regioniCliente = {
  'lombardia': 'Lombardia',
  'veneto': 'Veneto',
  'piemonte': 'Piemonte',
  'emilia_romagna': 'Emilia-Romagna',
  'toscana': 'Toscana',
  'lazio': 'Lazio',
  'campania': 'Campania',
  'sicilia': 'Sicilia',
  'puglia': 'Puglia',
  'calabria': 'Calabria',
  'sardegna': 'Sardegna',
  'liguria': 'Liguria',
  'marche': 'Marche',
  'abruzzo': 'Abruzzo',
  'umbria': 'Umbria',
  'friuli': 'Friuli-Venezia Giulia',
  'trentino': 'Trentino-Alto Adige/Südtirol',
  'valle_aosta': 'Valle d\'Aosta/Vallée d\'Aoste',
  'basilicata': 'Basilicata',
  'molise': 'Molise',
};

/// Validazione del nome cliente: obbligatorio.
///
/// Funzione pura, così è verificabile senza Firebase né UI.
String? validaNomeCliente(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il nome del cliente';
  return null;
}

/// Validazione della P.IVA: facoltativa, ma se presente deve avere 11 cifre.
///
/// Accetta il prefisso `IT` e gli spazi grazie a [normalizzaPiva].
String? validaPivaCliente(String? valore) {
  final piva = normalizzaPiva(valore);
  if (piva == null) return null;
  if (!RegExp(r'^\d{11}$').hasMatch(piva)) {
    return 'La P.IVA deve avere 11 cifre';
  }
  return null;
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio clienti.
String messaggioErroreClienti(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per gestire i clienti. Contatta l\'amministratore.';
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

/// Messaggio mostrato quando il servizio rifiuta un cliente duplicato.
const String messaggioDuplicatoCliente =
    'Esiste già un cliente con la stessa P.IVA, lo stesso nome o lo stesso '
    'codice fiscale.';

/// Testo del cliente, con fallback per i documenti senza nome.
String nomeVisualizzatoCliente(Cliente cliente) {
  final nome = cliente.nome?.trim() ?? '';
  return nome.isEmpty ? '(senza nome)' : nome;
}

/// Elenco clienti dell'azienda attiva, con ricerca e form a pagina intera.
class ClientiScreen extends ConsumerStatefulWidget {
  const ClientiScreen({super.key});

  @override
  ConsumerState<ClientiScreen> createState() => _ClientiScreenState();
}

class _ClientiScreenState extends ConsumerState<ClientiScreen> {
  final _ricerca = TextEditingController();

  List<Cliente> _clienti = const [];
  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _ricerca.addListener(_aggiornaRicerca);
    _caricaClienti();
  }

  @override
  void dispose() {
    _ricerca.removeListener(_aggiornaRicerca);
    _ricerca.dispose();
    super.dispose();
  }

  void _aggiornaRicerca() => setState(() {});

  /// Passa l'azienda attiva al servizio e ricarica l'elenco.
  Future<void> _caricaClienti() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final clienti = await servizio.getClienti();
      if (!mounted) return;
      setState(() {
        _clienti = clienti;
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

  List<Cliente> get _clientiFiltrati {
    final testo = _ricerca.text.trim().toLowerCase();
    if (testo.isEmpty) return _clienti;
    return _clienti.where((cliente) {
      bool contiene(String? valore) =>
          (valore ?? '').toLowerCase().contains(testo);
      return contiene(cliente.nome) ||
          contiene(cliente.citta) ||
          contiene(cliente.referente);
    }).toList();
  }

  /// Apre il form a pagina intera e ricarica se il salvataggio riesce.
  Future<void> _apriForm([Cliente? cliente]) async {
    final salvato = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ClienteFormScreen(cliente: cliente)),
    );
    if (salvato == true) await _caricaClienti();
  }

  Future<void> _elimina(Cliente cliente) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-elimina-cliente'),
        title: const Text('Eliminare il cliente?'),
        content: Text(
          'Il cliente "${nomeVisualizzatoCliente(cliente)}" verrà eliminato '
          'definitivamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-elimina-cliente'),
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
      await servizio.eliminaCliente(cliente.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente eliminato')),
      );
      await _caricaClienti();
    } catch (errore) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messaggioErroreClienti(errore))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _caricaClienti();
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
              child: _BarraRicerca(
                largo: largo,
                controller: _ricerca,
                onNuovo: () => _apriForm(),
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
                child: _contenuto(largo),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _contenuto(bool largo) {
    if (_caricamento) {
      return const Center(
        key: Key('clienti-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (_errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Clienti non disponibili',
        sottotitolo: messaggioErroreClienti(_errore!),
        azione: OutlinedButton.icon(
          key: const Key('clienti-riprova'),
          onPressed: _caricaClienti,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (_clienti.isEmpty) {
      return StatoCentrato(
        icona: Icons.people_outline,
        titolo: 'Nessun cliente',
        sottotitolo:
            'Aggiungi il primo cliente con il pulsante "Nuovo cliente".',
        azione: FilledButton.icon(
          key: const Key('clienti-nuovo-vuoto'),
          onPressed: () => _apriForm(),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Nuovo cliente'),
        ),
      );
    }

    final filtrati = _clientiFiltrati;
    if (filtrati.isEmpty) {
      return const StatoCentrato(
        icona: Icons.search_off,
        titolo: 'Nessun cliente trovato',
        sottotitolo: 'Prova a cambiare i termini di ricerca.',
      );
    }

    return largo
        ? _TabellaClienti(
            clienti: filtrati,
            onModifica: _apriForm,
            onElimina: _elimina,
          )
        : _ListaClienti(
            clienti: filtrati,
            onModifica: _apriForm,
            onElimina: _elimina,
          );
  }
}

/// Campo di ricerca e pulsante "Nuovo cliente".
class _BarraRicerca extends StatelessWidget {
  const _BarraRicerca({
    required this.largo,
    required this.controller,
    required this.onNuovo,
  });

  final bool largo;
  final TextEditingController controller;
  final VoidCallback onNuovo;

  @override
  Widget build(BuildContext context) {
    final campo = TextField(
      key: const Key('clienti-ricerca'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cerca per nome, città o referente',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('clienti-azzera-ricerca'),
                tooltip: 'Azzera ricerca',
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              ),
      ),
    );
    final pulsante = FilledButton.icon(
      key: const Key('nuovo-cliente'),
      onPressed: onNuovo,
      icon: const Icon(Icons.person_add_alt_1),
      label: const Text('Nuovo cliente'),
    );

    if (!largo) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          campo,
          const SizedBox(height: AppSpazi.xs),
          pulsante,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: campo),
        const SizedBox(width: AppSpazi.s),
        pulsante,
      ],
    );
  }
}

/// Elenco a card (telefono).
class _ListaClienti extends StatelessWidget {
  const _ListaClienti({
    required this.clienti,
    required this.onModifica,
    required this.onElimina,
  });

  final List<Cliente> clienti;
  final ValueChanged<Cliente> onModifica;
  final ValueChanged<Cliente> onElimina;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const Key('lista-clienti'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: clienti.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) {
        final cliente = clienti[indice];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            key: ValueKey('cliente-${cliente.id}'),
            onTap: () => onModifica(cliente),
            title: Text(nomeVisualizzatoCliente(cliente)),
            subtitle: Text(_dettagli(cliente)),
            trailing: MenuAzioni(
              key: ValueKey('menu-cliente-${cliente.id}'),
              tooltip: 'Azioni cliente',
              onModifica: () => onModifica(cliente),
              onElimina: () => onElimina(cliente),
            ),
          ),
        );
      },
    );
  }
}

/// Elenco tabellare (da 600 px in su).
class _TabellaClienti extends StatelessWidget {
  const _TabellaClienti({
    required this.clienti,
    required this.onModifica,
    required this.onElimina,
  });

  final List<Cliente> clienti;
  final ValueChanged<Cliente> onModifica;
  final ValueChanged<Cliente> onElimina;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('tabella-clienti'),
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Tipo')),
            DataColumn(label: Text('Città')),
            DataColumn(label: Text('Referente')),
            DataColumn(label: Text('P.IVA')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final cliente in clienti)
              DataRow(
                key: ValueKey('cliente-${cliente.id}'),
                onSelectChanged: (_) => onModifica(cliente),
                cells: [
                  DataCell(Text(nomeVisualizzatoCliente(cliente))),
                  DataCell(
                    Text(tipiCliente[cliente.tipoCliente] ?? cliente.tipoCliente),
                  ),
                  DataCell(Text(_testo(cliente.citta))),
                  DataCell(Text(_testo(cliente.referente))),
                  DataCell(Text(_testo(cliente.piva))),
                  DataCell(
                    MenuAzioni(
                      key: ValueKey('menu-cliente-${cliente.id}'),
                      tooltip: 'Azioni cliente',
                      onModifica: () => onModifica(cliente),
                      onElimina: () => onElimina(cliente),
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

String _testo(String? valore) {
  final testo = valore?.trim() ?? '';
  return testo.isEmpty ? '—' : testo;
}

String _dettagli(Cliente cliente) {
  final parti = <String>[
    if ((cliente.citta ?? '').trim().isNotEmpty) cliente.citta!.trim(),
    if ((cliente.referente ?? '').trim().isNotEmpty)
      'Ref. ${cliente.referente!.trim()}',
    if ((cliente.piva ?? '').trim().isNotEmpty) 'P.IVA ${cliente.piva!.trim()}',
  ];
  return parti.isEmpty ? 'Nessun dettaglio' : parti.join(' · ');
}

/// Form completo di un cliente, aperto a pagina intera (nuovo o modifica).
class ClienteFormScreen extends ConsumerStatefulWidget {
  const ClienteFormScreen({super.key, this.cliente, this.onSalvato});

  /// Cliente da modificare; `null` per crearne uno nuovo.
  final Cliente? cliente;

  /// Callback invocata dopo il salvataggio riuscito, con l'id del cliente
  /// (utile a chi apre il form per selezionare subito il nuovo cliente).
  final ValueChanged<String?>? onSalvato;

  @override
  ConsumerState<ClienteFormScreen> createState() => _ClienteFormScreenState();
}

class _ClienteFormScreenState extends ConsumerState<ClienteFormScreen> {
  final _modulo = GlobalKey<FormState>();

  late final TextEditingController _nome;
  late final TextEditingController _referente;
  late final TextEditingController _piva;
  late final TextEditingController _codiceFiscale;
  late final TextEditingController _email;
  late final TextEditingController _telefono;
  late final TextEditingController _indirizzo;
  late final TextEditingController _civico;
  late final TextEditingController _cap;
  late final TextEditingController _citta;
  late final TextEditingController _provincia;
  late final TextEditingController _ateco;
  late final TextEditingController _note;

  late String _tipoCliente;
  late String _settore;
  late String _regione;

  bool _salvando = false;
  String? _errore;

  final ViesService _vies = ViesService();
  bool _verificandoPiva = false;

  bool get _modifica => widget.cliente != null;

  @override
  void initState() {
    super.initState();
    final cliente = widget.cliente;
    _nome = TextEditingController(text: cliente?.nome ?? '');
    _referente = TextEditingController(text: cliente?.referente ?? '');
    _piva = TextEditingController(text: cliente?.piva ?? '');
    _codiceFiscale = TextEditingController(text: cliente?.codiceFiscale ?? '');
    _email = TextEditingController(text: cliente?.email ?? '');
    _telefono = TextEditingController(text: cliente?.telefono ?? '');
    _indirizzo = TextEditingController(text: cliente?.indirizzo ?? '');
    _civico = TextEditingController(text: cliente?.civico ?? '');
    _cap = TextEditingController(text: cliente?.cap ?? '');
    _citta = TextEditingController(text: cliente?.citta ?? '');
    _provincia = TextEditingController(text: cliente?.provincia ?? '');
    _ateco = TextEditingController(text: cliente?.ateco ?? '');
    _note = TextEditingController(text: cliente?.note ?? '');

    final tipo = cliente?.tipoCliente ?? 'azienda';
    _tipoCliente = tipiCliente.containsKey(tipo) ? tipo : 'azienda';
    final settore = cliente?.settore ?? 'ristorazione';
    _settore = settoriCliente.containsKey(settore) ? settore : 'ristorazione';
    final regione = cliente?.regione ?? 'lombardia';
    _regione = regioniCliente.containsKey(regione) ? regione : 'lombardia';
  }

  @override
  void dispose() {
    _nome.dispose();
    _referente.dispose();
    _piva.dispose();
    _codiceFiscale.dispose();
    _email.dispose();
    _telefono.dispose();
    _indirizzo.dispose();
    _civico.dispose();
    _cap.dispose();
    _citta.dispose();
    _provincia.dispose();
    _ateco.dispose();
    _note.dispose();
    _vies.close();
    super.dispose();
  }

  Future<void> _salva() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    setState(() => _salvando = true);
    final dati = <String, dynamic>{
      'tipo_cliente': _tipoCliente,
      'nome': _nome.text,
      'referente': _referente.text,
      'piva': _piva.text,
      'codice_fiscale': _codiceFiscale.text,
      'email': _email.text,
      'telefono': _telefono.text,
      'indirizzo': _indirizzo.text,
      'civico': _civico.text,
      'cap': _cap.text,
      'citta': _citta.text,
      'provincia': _provincia.text,
      'ateco': _ateco.text,
      'settore': _settore,
      'regione': _regione,
      'note': _note.text,
    };

    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final String? id;
      if (_modifica) {
        id = widget.cliente!.id;
        await servizio.aggiornaCliente(id, dati);
      } else {
        final nuovo = await servizio.inserisciCliente(dati);
        id = nuovo['id'] as String?;
      }
      if (!mounted) return;
      widget.onSalvato?.call(id);
      Navigator.of(context).pop(true);
      return;
    } on DuplicatoClienteException {
      if (!mounted) return;
      setState(() => _errore = messaggioDuplicatoCliente);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreClienti(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  /// Avvia la verifica VIES della P.IVA inserita.
  ///
  /// Normalizza e valida l'input (11 cifre), chiama [ViesService.verifica] e
  /// mostra l'esito. Non salva nulla: il cliente resta invariato fino al
  /// salvataggio esplicito.
  Future<void> _verificaPiva() async {
    final valore = _piva.text;
    final normalizzata = normalizzaPivaVies(valore);
    if (normalizzata == null || normalizzata.length != 11) {
      _mostraErroreVies('La P.IVA deve avere 11 cifre.');
      return;
    }

    setState(() => _verificandoPiva = true);
    try {
      final risultato = await _vies.verifica(valore);
      if (!mounted) return;
      if (risultato.errore != null) {
        _mostraErroreVies(risultato.errore!);
        return;
      }
      _compilaDaVies(risultato);
      await _mostraEsitoVies(risultato);
    } on ViesException catch (errore) {
      if (!mounted) return;
      _mostraErroreVies(errore.message);
    } finally {
      if (mounted) setState(() => _verificandoPiva = false);
    }
  }

  /// Compila nome e indirizzo solo se vuoti, usando i dati VIES validi.
  ///
  /// Non tocca i campi già valorizzati e non salva nulla.
  void _compilaDaVies(ViesRisultato risultato) {
    if (!risultato.valido) return;
    final nome = risultato.ragioneSociale?.trim() ?? '';
    if (nome.isNotEmpty && _nome.text.trim().isEmpty) {
      _nome.text = nome;
    }
    final indirizzo = risultato.indirizzo?.trim() ?? '';
    if (indirizzo.isNotEmpty && _indirizzo.text.trim().isEmpty) {
      _indirizzo.text = indirizzo;
    }
  }

  /// Dialogo con ragione sociale, stato e indirizzo restituiti da VIES.
  Future<void> _mostraEsitoVies(ViesRisultato risultato) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-verifica-piva'),
        title: Text(risultato.valido ? 'P.IVA valida' : 'P.IVA non valida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _rigaVies('Stato', risultato.valido ? 'Valida' : 'Non valida'),
            _rigaVies('Ragione sociale', risultato.ragioneSociale ?? ''),
            _rigaVies('Indirizzo', risultato.indirizzo ?? ''),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Chiudi'),
          ),
        ],
      ),
    );
  }

  Widget _rigaVies(String etichetta, String valore) {
    final tema = Theme.of(context);
    final testo = valore.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpazi.xs),
      child: Text.rich(
        TextSpan(
          text: '$etichetta: ',
          style: tema.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          children: [
            TextSpan(
              text: testo.isEmpty ? '—' : testo,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostraErroreVies(String messaggio) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(messaggio)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final privato = _tipoCliente == 'privato';

    return Scaffold(
      appBar: AppBar(
        title: Text(_modifica ? 'Modifica cliente' : 'Nuovo cliente'),
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
                    _Sezione(
                      titolo: 'Anagrafica',
                      figli: [
                        _tendina(
                          etichetta: 'Tipo cliente',
                          chiave: 'cliente-tipo',
                          valore: _tipoCliente,
                          opzioni: tipiCliente,
                          onCambia: (valore) {
                            if (valore == null) return;
                            setState(() => _tipoCliente = valore);
                          },
                        ),
                        _campo(
                          etichetta:
                              privato ? 'Nome e cognome' : 'Ragione sociale',
                          chiave: 'cliente-nome',
                          controller: _nome,
                          suggerimento:
                              privato ? 'Es. Mario Rossi' : 'Es. Acme S.r.l.',
                          capitalizzazione: TextCapitalization.words,
                          validatore: validaNomeCliente,
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: _campo(
                                etichetta: 'Partita IVA',
                                chiave: 'cliente-piva',
                                controller: _piva,
                                suggerimento: 'Es. 12345678901',
                                validatore: validaPivaCliente,
                              ),
                            ),
                            const SizedBox(width: AppSpazi.s),
                            OutlinedButton.icon(
                              key: const Key('verifica-piva'),
                              onPressed: _verificandoPiva || _salvando
                                  ? null
                                  : _verificaPiva,
                              icon: _verificandoPiva
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.verified_outlined),
                              label: Text(
                                _verificandoPiva
                                    ? 'Verifica…'
                                    : 'Verifica P.IVA',
                              ),
                            ),
                          ],
                        ),
                        _campo(
                          etichetta: 'Codice fiscale',
                          chiave: 'cliente-codice-fiscale',
                          controller: _codiceFiscale,
                          suggerimento: 'Es. RSSMRA80A01H501U',
                          capitalizzazione: TextCapitalization.characters,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _Sezione(
                      titolo: 'Sede legale',
                      figli: [
                        _campo(
                          etichetta: 'Indirizzo',
                          chiave: 'cliente-indirizzo',
                          controller: _indirizzo,
                          suggerimento: 'Via Roma',
                          capitalizzazione: TextCapitalization.words,
                        ),
                        _campo(
                          etichetta: 'Civico',
                          chiave: 'cliente-civico',
                          controller: _civico,
                          suggerimento: '1',
                        ),
                        _campo(
                          etichetta: 'CAP',
                          chiave: 'cliente-cap',
                          controller: _cap,
                          suggerimento: '20100',
                          tastiera: TextInputType.number,
                          formattatori: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                        ),
                        _campo(
                          etichetta: 'Città',
                          chiave: 'cliente-citta',
                          controller: _citta,
                          capitalizzazione: TextCapitalization.words,
                        ),
                        _campo(
                          etichetta: 'Provincia',
                          chiave: 'cliente-provincia',
                          controller: _provincia,
                          suggerimento: 'MI',
                          capitalizzazione: TextCapitalization.characters,
                          formattatori: [
                            LengthLimitingTextInputFormatter(2),
                          ],
                        ),
                        _tendina(
                          etichetta: 'Regione',
                          chiave: 'cliente-regione',
                          valore: _regione,
                          opzioni: regioniCliente,
                          onCambia: (valore) {
                            if (valore == null) return;
                            setState(() => _regione = valore);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _Sezione(
                      titolo: 'Contatti',
                      figli: [
                        _campo(
                          etichetta: 'Referente',
                          chiave: 'cliente-referente',
                          controller: _referente,
                          capitalizzazione: TextCapitalization.words,
                        ),
                        _campo(
                          etichetta: 'Email',
                          chiave: 'cliente-email',
                          controller: _email,
                          tastiera: TextInputType.emailAddress,
                          suggerimento: 'nome@azienda.it',
                        ),
                        _campo(
                          etichetta: 'Telefono',
                          chiave: 'cliente-telefono',
                          controller: _telefono,
                          tastiera: TextInputType.phone,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.m),
                    _Sezione(
                      titolo: 'Attività',
                      figli: [
                        _campo(
                          etichetta: 'Codice ATECO',
                          chiave: 'cliente-ateco',
                          controller: _ateco,
                          suggerimento: 'Es. 56.10',
                        ),
                        _tendina(
                          etichetta: 'Settore',
                          chiave: 'cliente-settore',
                          valore: _settore,
                          opzioni: settoriCliente,
                          onCambia: (valore) {
                            if (valore == null) return;
                            setState(() => _settore = valore);
                          },
                        ),
                        _campo(
                          etichetta: 'Note',
                          chiave: 'cliente-note',
                          controller: _note,
                          righe: 3,
                          capitalizzazione: TextCapitalization.sentences,
                          azione: TextInputAction.newline,
                        ),
                      ],
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('errore-cliente'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('annulla-cliente'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('salva-cliente'),
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
                                        : 'Crea cliente',
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

  Widget _campo({
    required String etichetta,
    required String chiave,
    required TextEditingController controller,
    String? suggerimento,
    TextInputType? tastiera,
    int righe = 1,
    List<TextInputFormatter>? formattatori,
    String? Function(String?)? validatore,
    TextCapitalization capitalizzazione = TextCapitalization.none,
    TextInputAction azione = TextInputAction.next,
  }) {
    return TextFormField(
      key: Key(chiave),
      controller: controller,
      enabled: !_salvando,
      keyboardType: tastiera,
      textCapitalization: capitalizzazione,
      textInputAction: azione,
      minLines: righe,
      maxLines: righe,
      inputFormatters: formattatori,
      decoration: InputDecoration(
        labelText: etichetta,
        hintText: suggerimento,
      ),
      validator: validatore,
    );
  }

  Widget _tendina({
    required String etichetta,
    required String chiave,
    required String valore,
    required Map<String, String> opzioni,
    required ValueChanged<String?> onCambia,
  }) {
    return DropdownButtonFormField<String>(
      key: Key(chiave),
      initialValue: valore,
      isExpanded: true,
      decoration: InputDecoration(labelText: etichetta),
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
      onChanged: _salvando ? null : onCambia,
    );
  }
}

/// Card di sezione del form con titolo e campi disposti su una o due colonne.
class _Sezione extends StatelessWidget {
  const _Sezione({required this.titolo, required this.figli});

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
