import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/licenza.dart';
import '../../state/azienda_providers.dart';
import '../bandi/bandi_screen.dart' show formattaDataBando;

// ---------------------------------------------------------------------------
// Funzioni pure: etichette, formati e messaggi (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Etichette dei piani configurati (`PIANI` della vecchia app).
const Map<String, String> pianiLicenza = {
  'trial': 'Trial',
  'starter': 'Starter',
  'professional': 'Professional',
  'enterprise': 'Enterprise',
};

/// Etichette italiane degli stati di licenza.
const Map<String, String> statiLicenza = {
  'attiva': 'Attiva',
  'trial': 'Trial',
  'scaduta': 'Scaduta',
  'sospesa': 'Sospesa',
};

/// Etichetta leggibile del piano: nome noto, altrimenti la chiave con
/// l'iniziale maiuscola; `—` se il campo è vuoto.
String etichettaPiano(String? piano) {
  final chiave = (piano ?? '').trim().toLowerCase();
  if (chiave.isEmpty) return '—';
  final nota = pianiLicenza[chiave];
  if (nota != null) return nota;
  return '${chiave[0].toUpperCase()}${chiave.substring(1)}';
}

/// Etichetta italiana di uno stato di licenza.
///
/// Gli stati sconosciuti restano leggibili così come sono (dati vecchi o
/// nuovi); il campo vuoto ricade su "Attiva", il default del modello.
String etichettaStatoLicenza(String? stato) {
  final chiave = (stato ?? '').trim().toLowerCase();
  if (chiave.isEmpty) return statiLicenza['attiva']!;
  return statiLicenza[chiave] ?? chiave;
}

/// Grigio neutro per gli stati senza colore semantico nel tema.
const Color _grigioStato = Color(0xFF64748B);

/// Colore del badge di stato, coerente con i colori semantici del tema.
Color coloreStatoLicenza(String? stato) {
  switch ((stato ?? '').trim().toLowerCase()) {
    case 'attiva':
      return AppColors.accettato;
    case 'scaduta':
      return AppColors.errore;
    case 'trial':
    case 'sospesa':
      return AppColors.attesa;
    default:
      return _grigioStato;
  }
}

/// Stato effettivo della licenza: una licenza con `data_fine` passata è
/// scaduta anche se il campo `stato` dice ancora `attiva` (stessa regola
/// della vecchia app in `licenzaValida`).
String statoLicenzaEffettivo(Licenza licenza, {DateTime? oggi}) {
  final fine = _dataLicenza(licenza.dataFine);
  final riferimento = oggi ?? DateTime.now();
  final giorno = DateTime(riferimento.year, riferimento.month, riferimento.day);
  if (fine != null && fine.isBefore(giorno)) return 'scaduta';
  return (licenza.stato.trim().isEmpty ? 'attiva' : licenza.stato.trim())
      .toLowerCase();
}

/// Data `YYYY-MM-DD` della licenza come `gg/mm/aaaa`, `—` se assente.
///
/// Riusa il formattatore già usato da bandi (stesso formato Firestore).
String formattaDataLicenza(String? data) {
  if (_dataLicenza(data) == null) return '—';
  return formattaDataBando(data);
}

/// Limite del piano leggibile: `—` mai, numero in formato italiano oppure
/// "Illimitato" quando il campo è assente o negativo (come la vecchia app).
String formattaLimite(int? valore) {
  if (valore == null || valore < 0) return 'Illimitato';
  return NumberFormat.decimalPattern('it_IT').format(valore);
}

/// Testo delle note, con fallback quando il campo è vuoto.
String noteLicenza(String? note) {
  final testo = (note ?? '').trim();
  return testo.isEmpty ? 'Nessuna nota' : testo;
}

/// Messaggio in italiano per gli errori di caricamento della licenza.
String messaggioErroreLicenza(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per vedere la licenza. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Licenza non disponibile. Riprova.';
    }
  }
  return 'Licenza non disponibile. Controlla la connessione e riprova.';
}

DateTime? _dataLicenza(String? data) {
  final valore = (data ?? '').trim();
  if (valore.isEmpty) return null;
  final parti = valore.split('T').first.split('-');
  if (parti.length != 3) return null;
  final anno = int.tryParse(parti[0]);
  final mese = int.tryParse(parti[1]);
  final giorno = int.tryParse(parti[2]);
  if (anno == null || mese == null || giorno == null) return null;
  return DateTime(anno, mese, giorno);
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata Licenze: piano e limiti dell'azienda attiva, in sola lettura.
///
/// La licenza è scritta solo dal super admin (pannello `/superadmin`): da qui
/// non si modifica nulla.
class LicenzeScreen extends ConsumerStatefulWidget {
  const LicenzeScreen({super.key});

  @override
  ConsumerState<LicenzeScreen> createState() => _LicenzeScreenState();
}

class _LicenzeScreenState extends ConsumerState<LicenzeScreen> {
  Licenza? _licenza;
  bool _caricamento = true;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e legge `licenze/{aziendaId}`.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final licenza = await servizio.getLicenzaAzienda();
      if (!mounted) return;
      setState(() {
        _licenza = licenza;
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
          child: CorpoLicenza(
            licenza: _licenza,
            caricamento: _caricamento,
            errore: _errore,
            onRiprova: _carica,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Corpo puro (testabile senza provider)
// ---------------------------------------------------------------------------

/// Contenuto della schermata Licenze, senza provider.
///
/// Gestisce caricamento, errore con "Riprova", licenza assente e scheda di
/// dettaglio. È pubblico per i widget test.
class CorpoLicenza extends StatelessWidget {
  const CorpoLicenza({
    super.key,
    required this.licenza,
    required this.onRiprova,
    this.caricamento = false,
    this.errore,
  });

  final Licenza? licenza;
  final bool caricamento;
  final Object? errore;
  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('licenze-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        key: const Key('licenze-errore'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Licenza non disponibile',
        sottotitolo: messaggioErroreLicenza(errore!),
        azione: OutlinedButton.icon(
          key: const Key('licenze-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final dati = licenza;
    if (dati == null) {
      return const StatoCentrato(
        key: Key('licenze-vuoto'),
        icona: Icons.workspace_premium_outlined,
        titolo: 'Nessuna licenza',
        sottotitolo: 'Non è ancora stata assegnata una licenza a questa '
            'azienda. La assegna il super admin della piattaforma.',
      );
    }

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: _SchedaLicenza(licenza: dati),
        ),
      ),
    );
  }
}

/// Scheda di dettaglio della licenza (sola lettura).
class _SchedaLicenza extends StatelessWidget {
  const _SchedaLicenza({required this.licenza});

  final Licenza licenza;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final stato = statoLicenzaEffettivo(licenza);

    return Card(
      key: const Key('licenze-scheda'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: tema.colorScheme.primaryContainer,
                  foregroundColor: tema.colorScheme.onPrimaryContainer,
                  child: const Icon(Icons.workspace_premium_outlined),
                ),
                const SizedBox(width: AppSpazi.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Piano ${etichettaPiano(licenza.piano)}',
                        style: tema.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpazi.xxs),
                      Text(
                        'Licenza dell\'azienda attiva',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpazi.xs),
                BadgeStatoLicenza(stato: stato),
              ],
            ),
            const Divider(height: AppSpazi.xl, color: AppColors.bordo),
            LayoutBuilder(
              builder: (context, constraints) {
                final dueColonne = constraints.maxWidth >= 420;
                final larghezza = dueColonne
                    ? (constraints.maxWidth - AppSpazi.l) / 2
                    : constraints.maxWidth;

                return Wrap(
                  spacing: AppSpazi.l,
                  runSpacing: AppSpazi.m,
                  children: [
                    for (final campo in [
                      _DatoLicenza(
                        etichetta: 'Stato',
                        valore: etichettaStatoLicenza(stato),
                      ),
                      _DatoLicenza(
                        etichetta: 'Piano',
                        valore: etichettaPiano(licenza.piano),
                      ),
                      _DatoLicenza(
                        etichetta: 'Data inizio',
                        valore: formattaDataLicenza(licenza.dataInizio),
                      ),
                      _DatoLicenza(
                        etichetta: 'Data fine',
                        valore: formattaDataLicenza(licenza.dataFine),
                      ),
                      _DatoLicenza(
                        etichetta: 'Max utenti',
                        valore: formattaLimite(licenza.maxUtenti),
                      ),
                      _DatoLicenza(
                        etichetta: 'Max preventivi',
                        valore: formattaLimite(licenza.maxPreventivi),
                      ),
                    ])
                      SizedBox(width: larghezza, child: campo),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpazi.m),
            _DatoLicenza(
              etichetta: 'Note',
              valore: noteLicenza(licenza.note),
            ),
            const SizedBox(height: AppSpazi.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  child: Text(
                    'La licenza è gestita dal super admin della piattaforma: '
                    'da qui puoi solo consultarla. Per modifiche al piano o '
                    'ai limiti rivolgiti al super admin.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
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

/// Coppia etichetta/valore di un dato della licenza.
class _DatoLicenza extends StatelessWidget {
  const _DatoLicenza({required this.etichetta, required this.valore});

  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etichetta,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpazi.xxs),
        Text(valore, style: tema.textTheme.bodyMedium),
      ],
    );
  }
}

/// Badge colorato dello stato della licenza.
class BadgeStatoLicenza extends StatelessWidget {
  const BadgeStatoLicenza({super.key, required this.stato});

  final String stato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = coloreStatoLicenza(stato);

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
        etichettaStatoLicenza(stato),
        style: tema.textTheme.labelSmall?.copyWith(color: colore),
      ),
    );
  }
}
