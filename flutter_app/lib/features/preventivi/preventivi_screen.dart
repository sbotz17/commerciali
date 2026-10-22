import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/preventivo.dart';
import '../../state/azienda_providers.dart';
import '../catalogo/catalogo_screen.dart' show formattaPrezzo;

// ---------------------------------------------------------------------------
// Funzioni pure: stati, formati, messaggi e ricerca (verificabili senza
// Firebase né UI)
// ---------------------------------------------------------------------------

/// Etichette italiane degli stati del preventivo (chiavi Firestore).
const Map<String, String> statiPreventivo = {
  'bozza': 'Bozza',
  'inviato': 'Inviato',
  'accettato': 'Accettato',
  'rifiutato': 'Rifiutato',
  'revisionato': 'Revisionato',
};

/// Colore neutro per la bozza (nessun colore semantico dedicato nel tema).
const Color _grigioBozza = Color(0xFF64748B);

/// Etichetta italiana di uno [stato] del preventivo.
///
/// Gli stati sconosciuti (dati vecchi o nuovi) vengono mostrati così come
/// sono, senza essere nascosti; lo stato vuoto ricade su "Bozza".
String etichettaStatoPreventivo(String stato) {
  final chiave = stato.trim().toLowerCase();
  if (chiave.isEmpty) return statiPreventivo['bozza']!;
  return statiPreventivo[chiave] ?? chiave;
}

/// Colore del badge di stato, coerente con i colori semantici del tema.
Color coloreStatoPreventivo(String stato) {
  switch (stato.trim().toLowerCase()) {
    case 'inviato':
      return AppColors.primario;
    case 'accettato':
      return AppColors.accettato;
    case 'rifiutato':
      return AppColors.errore;
    case 'revisionato':
      return AppColors.attesa;
    default:
      return _grigioBozza;
  }
}

/// Numero del preventivo, con `—` per i documenti senza numero.
String numeroVisualizzatoPreventivo(Preventivo preventivo) {
  final numero = preventivo.numero?.trim() ?? '';
  return numero.isEmpty ? '—' : numero;
}

/// Nome del cliente denormalizzato, con `—` se assente.
String clienteVisualizzatoPreventivo(Preventivo preventivo) {
  final nome = preventivo.clienteNome?.trim() ?? '';
  return nome.isEmpty ? '—' : nome;
}

/// Filtra i preventivi per numero o nome cliente (case-insensitive).
List<Preventivo> filtraPreventivi(List<Preventivo> preventivi, String testo) {
  final cerca = testo.trim().toLowerCase();
  if (cerca.isEmpty) return preventivi;
  return preventivi.where((preventivo) {
    final numero = (preventivo.numero ?? '').toLowerCase();
    final cliente = (preventivo.clienteNome ?? '').toLowerCase();
    return numero.contains(cerca) || cliente.contains(cerca);
  }).toList();
}

/// Messaggio in italiano per gli errori di caricamento dei preventivi.
String messaggioErrorePreventivi(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per vedere i preventivi. '
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
// Schermata
// ---------------------------------------------------------------------------

/// Elenco dei preventivi dell'azienda attiva.
///
/// La modifica e la creazione aprono per ora la rotta `/preventivi/nuovo`
/// (editor in F12b).
class PreventiviScreen extends ConsumerStatefulWidget {
  const PreventiviScreen({super.key});

  @override
  ConsumerState<PreventiviScreen> createState() => _PreventiviScreenState();
}

class _PreventiviScreenState extends ConsumerState<PreventiviScreen> {
  final _ricerca = TextEditingController();

  List<Preventivo> _preventivi = const [];
  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _ricerca.addListener(_aggiornaRicerca);
    _caricaPreventivi();
  }

  @override
  void dispose() {
    _ricerca.removeListener(_aggiornaRicerca);
    _ricerca.dispose();
    super.dispose();
  }

  void _aggiornaRicerca() => setState(() {});

  /// Passa l'azienda attiva al servizio e ricarica l'elenco.
  Future<void> _caricaPreventivi() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final preventivi = await servizio.getPreventivi();
      if (!mounted) return;
      setState(() {
        _preventivi = preventivi;
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

  /// Apre il preventivo: per ora la rotta dell'editor (F12b).
  void _apriPreventivo(Preventivo _) {
    context.go('/preventivi/nuovo');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(aziendaAttivaProvider, (precedente, attuale) {
      if (precedente != attuale) _caricaPreventivi();
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
                onNuovo: () => context.go('/preventivi/nuovo'),
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
                child: ElencoPreventivi(
                  preventivi: filtraPreventivi(_preventivi, _ricerca.text),
                  caricamento: _caricamento,
                  errore: _errore,
                  ricercaAttiva: _ricerca.text.trim().isNotEmpty,
                  largo: largo,
                  onRiprova: _caricaPreventivi,
                  onNuovo: () => context.go('/preventivi/nuovo'),
                  onApri: _apriPreventivo,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Corpo della lista: stati caricamento/errore/vuoto e lista responsive.
///
/// È pubblico e senza provider per poter essere verificato con un widget test
/// senza Firebase.
class ElencoPreventivi extends StatelessWidget {
  const ElencoPreventivi({
    super.key,
    required this.preventivi,
    required this.caricamento,
    required this.onRiprova,
    required this.onNuovo,
    required this.onApri,
    this.errore,
    this.ricercaAttiva = false,
    this.largo = false,
  });

  final List<Preventivo> preventivi;
  final bool caricamento;
  final Object? errore;
  final bool ricercaAttiva;
  final bool largo;
  final VoidCallback onRiprova;
  final VoidCallback onNuovo;
  final ValueChanged<Preventivo> onApri;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('preventivi-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        icona: Icons.cloud_off_outlined,
        titolo: 'Preventivi non disponibili',
        sottotitolo: messaggioErrorePreventivi(errore!),
        azione: OutlinedButton.icon(
          key: const Key('preventivi-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (preventivi.isEmpty) {
      if (ricercaAttiva) {
        return const StatoCentrato(
          icona: Icons.search_off,
          titolo: 'Nessun preventivo trovato',
          sottotitolo: 'Prova a cambiare numero o cliente nella ricerca.',
        );
      }
      return StatoCentrato(
        icona: Icons.description_outlined,
        titolo: 'Nessun preventivo',
        sottotitolo:
            'Crea il primo preventivo con il pulsante "Nuovo preventivo".',
        azione: FilledButton.icon(
          key: const Key('preventivi-nuovo-vuoto'),
          onPressed: onNuovo,
          icon: const Icon(Icons.note_add_outlined),
          label: const Text('Nuovo preventivo'),
        ),
      );
    }

    return largo
        ? _TabellaPreventivi(preventivi: preventivi, onApri: onApri)
        : _ListaPreventivi(preventivi: preventivi, onApri: onApri);
  }
}

/// Campo di ricerca e pulsante "Nuovo preventivo".
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
      key: const Key('preventivi-ricerca'),
      controller: controller,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Cerca per numero o cliente',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                key: const Key('preventivi-azzera-ricerca'),
                tooltip: 'Azzera ricerca',
                onPressed: controller.clear,
                icon: const Icon(Icons.close),
              ),
      ),
    );
    final pulsante = FilledButton.icon(
      key: const Key('nuovo-preventivo'),
      onPressed: onNuovo,
      icon: const Icon(Icons.note_add_outlined),
      label: const Text('Nuovo preventivo'),
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

/// Badge/chip dello stato del preventivo.
class BadgeStatoPreventivo extends StatelessWidget {
  const BadgeStatoPreventivo({super.key, required this.stato});

  final String stato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoPreventivo(stato);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpazi.xs,
        vertical: AppSpazi.xxs,
      ),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRaggi.chip),
      ),
      child: Text(
        etichettaStatoPreventivo(stato),
        style: tema.textTheme.labelSmall?.copyWith(
          color: colore,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Elenco a card (telefono).
class _ListaPreventivi extends StatelessWidget {
  const _ListaPreventivi({required this.preventivi, required this.onApri});

  final List<Preventivo> preventivi;
  final ValueChanged<Preventivo> onApri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListView.separated(
      key: const Key('lista-preventivi'),
      padding: const EdgeInsets.only(bottom: AppSpazi.l),
      itemCount: preventivi.length,
      separatorBuilder: (context, indice) =>
          const SizedBox(height: AppSpazi.xs),
      itemBuilder: (context, indice) {
        final preventivo = preventivi[indice];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('preventivo-${preventivo.id}'),
            onTap: () => onApri(preventivo),
            child: Padding(
              padding: const EdgeInsets.all(AppSpazi.m),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          numeroVisualizzatoPreventivo(preventivo),
                          style: tema.textTheme.titleSmall,
                        ),
                        const SizedBox(height: AppSpazi.xxs),
                        Text(
                          clienteVisualizzatoPreventivo(preventivo),
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpazi.s),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BadgeStatoPreventivo(stato: preventivo.stato),
                      const SizedBox(height: AppSpazi.xxs),
                      Text(
                        formattaPrezzo(preventivo.totaleIva),
                        style: tema.textTheme.titleSmall,
                      ),
                    ],
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
class _TabellaPreventivi extends StatelessWidget {
  const _TabellaPreventivi({required this.preventivi, required this.onApri});

  final List<Preventivo> preventivi;
  final ValueChanged<Preventivo> onApri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('tabella-preventivi'),
          showCheckboxColumn: false,
          columns: const [
            DataColumn(label: Text('Numero')),
            DataColumn(label: Text('Cliente')),
            DataColumn(label: Text('Stato')),
            DataColumn(label: Text('Totale'), numeric: true),
          ],
          rows: [
            for (final preventivo in preventivi)
              DataRow(
                key: ValueKey('preventivo-${preventivo.id}'),
                onSelectChanged: (_) => onApri(preventivo),
                cells: [
                  DataCell(Text(numeroVisualizzatoPreventivo(preventivo))),
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 280),
                      child: Text(
                        clienteVisualizzatoPreventivo(preventivo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(BadgeStatoPreventivo(stato: preventivo.stato)),
                  DataCell(
                    Text(
                      formattaPrezzo(preventivo.totaleIva),
                      style: tema.textTheme.bodyMedium,
                      textAlign: TextAlign.right,
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
