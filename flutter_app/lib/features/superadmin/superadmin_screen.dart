import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/azienda.dart';
import '../../state/azienda_providers.dart';
import '../../state/auth_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Filtra le aziende per nome (case-insensitive, spazi ai bordi ignorati).
///
/// Con testo vuoto torna l'elenco così com'è.
List<Azienda> filtraAziende(List<Azienda> aziende, String testo) {
  final cerca = testo.trim().toLowerCase();
  if (cerca.isEmpty) return aziende;
  return aziende
      .where((azienda) => azienda.nome.toLowerCase().contains(cerca))
      .toList();
}

/// Messaggio in italiano per gli errori di caricamento delle aziende.
String messaggioErroreSuperAdmin(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per vedere le aziende. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Aziende non disponibili. Riprova.';
    }
  }
  return 'Aziende non disponibili. Controlla la connessione e riprova.';
}

/// Nome leggibile dell'azienda, con fallback quando il campo è vuoto.
String _nomeAzienda(Azienda azienda) {
  final nome = azienda.nome.trim();
  return nome.isEmpty ? 'Azienda senza nome' : nome;
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Pannello super admin: elenco di tutte le aziende e accesso a una di esse.
///
/// La lettura di `getTutteAziende` parte solo se il profilo ha
/// `superAdmin == true`; per tutti gli altri la schermata mostra "Accesso
/// riservato" senza chiamare Firestore.
class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  List<Azienda> _aziende = const [];
  bool _caricamento = false;
  Object? _errore;

  /// Vero dopo il primo avvio della lettura: evita richieste duplicate.
  bool _avviato = false;

  @override
  void initState() {
    super.initState();
    // Il profilo può essere già disponibile (es. ritorno sulla schermata):
    // si prova subito, il listener in build copre l'arrivo successivo.
    Future<void>.microtask(_avviaSeSuperAdmin);
  }

  void _avviaSeSuperAdmin() {
    if (!mounted || _avviato) return;
    final profilo = ref.read(profileProvider).asData?.value;
    if (profilo?.superAdmin != true) return;
    _avviato = true;
    _carica();
  }

  Future<void> _carica() async {
    if (ref.read(profileProvider).asData?.value?.superAdmin != true) return;

    setState(() {
      _caricamento = true;
      _errore = null;
    });

    try {
      final aziende = await ref.read(spServiceProvider).getTutteAziende();
      if (!mounted) return;
      setState(() {
        _aziende = aziende;
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

  void _entra(Azienda azienda) {
    ref.read(aziendaAttivaProvider.notifier).state = azienda.id;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(profileProvider, (precedente, attuale) {
      if (attuale.asData?.value?.superAdmin == true) _avviaSeSuperAdmin();
    });

    final profilo = ref.watch(profileProvider);

    if (profilo.isLoading) {
      return const Center(
        key: Key('superadmin-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (profilo.asData?.value?.superAdmin != true) {
      return const StatoCentrato(
        key: Key('superadmin-riservato'),
        icona: Icons.lock_outline,
        titolo: 'Accesso riservato',
        sottotitolo: 'Questa sezione è visibile solo al super admin '
            'della piattaforma.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

        return Padding(
          padding: EdgeInsets.all(orizzontale),
          child: CorpoSuperAdmin(
            aziende: _aziende,
            caricamento: !_avviato || _caricamento,
            errore: _errore,
            largo: largo,
            onRiprova: _carica,
            onEntra: _entra,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Contenuto del pannello super admin, senza provider.
///
/// Gestisce caricamento, errore con "Riprova", elenco vuoto, ricerca senza
/// risultati e lista responsive (card sotto 600 px, tabella da 600 px in su).
class CorpoSuperAdmin extends StatefulWidget {
  const CorpoSuperAdmin({
    super.key,
    required this.aziende,
    required this.onEntra,
    required this.onRiprova,
    this.caricamento = false,
    this.errore,
    this.largo,
  });

  final List<Azienda> aziende;
  final ValueChanged<Azienda> onEntra;
  final VoidCallback onRiprova;
  final bool caricamento;
  final Object? errore;

  /// Forza il layout largo (tabella); se `null` decide la larghezza.
  final bool? largo;

  @override
  State<CorpoSuperAdmin> createState() => _CorpoSuperAdminState();
}

class _CorpoSuperAdminState extends State<CorpoSuperAdmin> {
  final TextEditingController _ricerca = TextEditingController();

  @override
  void dispose() {
    _ricerca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caricamento) {
      return const Center(
        key: Key('superadmin-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (widget.errore != null) {
      return StatoCentrato(
        key: const Key('superadmin-errore'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Aziende non disponibili',
        sottotitolo: messaggioErroreSuperAdmin(widget.errore!),
        azione: OutlinedButton.icon(
          key: const Key('superadmin-riprova'),
          onPressed: widget.onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (widget.aziende.isEmpty) {
      return const StatoCentrato(
        key: Key('superadmin-vuoto'),
        icona: Icons.business_outlined,
        titolo: 'Nessuna azienda',
        sottotitolo: 'Non ci sono aziende registrate sulla piattaforma.',
      );
    }

    final filtrate = filtraAziende(widget.aziende, _ricerca.text);

    return Column(
      children: [
        TextField(
          key: const Key('superadmin-ricerca'),
          controller: _ricerca,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Cerca per nome azienda',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _ricerca.text.isEmpty
                ? null
                : IconButton(
                    key: const Key('superadmin-azzera-ricerca'),
                    tooltip: 'Azzera ricerca',
                    onPressed: () {
                      _ricerca.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: AppSpazi.s),
        Expanded(
          child: filtrate.isEmpty
              ? const StatoCentrato(
                  key: Key('superadmin-nessun-risultato'),
                  icona: Icons.search_off,
                  titolo: 'Nessuna azienda trovata',
                  sottotitolo: 'Prova a cambiare il nome nella ricerca.',
                )
              : _elenco(filtrate),
        ),
      ],
    );
  }

  Widget _elenco(List<Azienda> aziende) {
    final largo = widget.largo;
    if (largo != null) return _layout(aziende, largo);

    return LayoutBuilder(
      builder: (context, constraints) =>
          _layout(aziende, constraints.maxWidth >= AppBreakpoints.telefono),
    );
  }

  Widget _layout(List<Azienda> aziende, bool largo) {
    if (!largo) {
      return ListView.separated(
        key: const Key('superadmin-lista'),
        padding: const EdgeInsets.only(bottom: AppSpazi.l),
        itemCount: aziende.length,
        separatorBuilder: (context, indice) =>
            const SizedBox(height: AppSpazi.xs),
        itemBuilder: (context, indice) {
          final azienda = aziende[indice];
          return Card(
            key: ValueKey('superadmin-azienda-${azienda.id}'),
            child: Padding(
              padding: const EdgeInsets.all(AppSpazi.internoCard),
              child: Row(
                children: [
                  _IconaAzienda(azienda: azienda),
                  const SizedBox(width: AppSpazi.s),
                  Expanded(child: _TestoAzienda(azienda: azienda)),
                  const SizedBox(width: AppSpazi.xs),
                  FilledButton(
                    key: ValueKey('superadmin-entra-${azienda.id}'),
                    onPressed: () => widget.onEntra(azienda),
                    child: const Text('Entra'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      key: const Key('superadmin-tabella-scroll'),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            key: const Key('superadmin-tabella'),
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Azienda')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final azienda in aziende)
                DataRow(
                  key: ValueKey('superadmin-riga-${azienda.id}'),
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _IconaAzienda(azienda: azienda),
                          const SizedBox(width: AppSpazi.s),
                          _TestoAzienda(azienda: azienda),
                        ],
                      ),
                    ),
                    DataCell(
                      FilledButton(
                        key: ValueKey('superadmin-entra-${azienda.id}'),
                        onPressed: () => widget.onEntra(azienda),
                        child: const Text('Entra'),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Iniziali dell'azienda in un cerchio colorato.
class _IconaAzienda extends StatelessWidget {
  const _IconaAzienda({required this.azienda});

  final Azienda azienda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nome = _nomeAzienda(azienda);
    final iniziali = nome
        .split(RegExp(r'\s+'))
        .where((parola) => parola.isNotEmpty)
        .take(2)
        .map((parola) => parola[0].toUpperCase())
        .join();

    return CircleAvatar(
      radius: 20,
      backgroundColor: tema.colorScheme.primaryContainer,
      foregroundColor: tema.colorScheme.onPrimaryContainer,
      child: Text(
        iniziali.isEmpty ? '?' : iniziali,
        style: tema.textTheme.labelLarge?.copyWith(
          color: tema.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Nome e identificativo breve dell'azienda.
class _TestoAzienda extends StatelessWidget {
  const _TestoAzienda({required this.azienda});

  final Azienda azienda;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_nomeAzienda(azienda), style: tema.textTheme.titleSmall),
        const SizedBox(height: AppSpazi.xxs),
        Text(
          'Azienda della piattaforma',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
