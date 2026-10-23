// Notifiche in-app dell'utente corrente.
//
// La schermata legge le notifiche con `getNotifiche()` e resta aggiornata con
// `notificheStream()`; il filtro "Tutte / Non lette" lavora in memoria. Le
// funzioni di conteggio, etichetta e formato sono pure, così restano
// verificabili senza Firebase.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/notifica.dart';
import '../../data/services/sp_service.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Numero di notifiche non ancora lette (`lettaAt` assente o vuoto).
int contaNotificheNonLette(List<Notifica> notifiche) {
  return notifiche.where(notificaNonLetta).length;
}

/// Etichetta breve del tipo di notifica, con fallback `Generica`.
///
/// I valori noti sono `appuntamento`, `task`, `promemoria`, `chat` e
/// `comunicazione`; spazi e maiuscole non contano.
String etichettaTipoNotificaBreve(String? tipo) {
  const etichette = {
    'appuntamento': 'Appuntamento',
    'task': 'Task',
    'promemoria': 'Promemoria',
    'chat': 'Chat',
    'comunicazione': 'Comunicazione',
  };
  final chiave = tipo?.trim().toLowerCase() ?? '';
  return etichette[chiave] ?? 'Generica';
}

/// Messaggio in italiano per gli errori di caricamento o di operazione.
String messaggioErroreNotifiche(Object errore, {bool caricamento = false}) {
  final testo = errore.toString().toLowerCase();
  if (testo.contains('permission-denied')) {
    return 'Non hai i permessi per vedere le notifiche. Contatta l\'amministratore.';
  }
  if (testo.contains('unavailable') || testo.contains('network')) {
    return 'Connessione assente. Controlla la rete e riprova.';
  }
  return caricamento
      ? 'Impossibile caricare le notifiche. Riprova.'
      : 'Operazione non riuscita. Riprova.';
}

/// Data e ora italiane (`gg/mm/aaaa · HH:MM`) della notifica.
///
/// Usa `createdAt`, poi `inviataAt`, poi `programmataAt`. Restituisce `—`
/// quando nessuno dei valori è una data valida.
String formattaDataOraNotifica(Notifica notifica) {
  final grezza =
      (notifica.createdAt ?? notifica.inviataAt ?? notifica.programmataAt ?? '')
          .trim();
  if (grezza.isEmpty) return '—';
  final data = DateTime.tryParse(grezza);
  if (data == null) return '—';
  return DateFormat('dd/MM/yyyy · HH:mm').format(data.toLocal());
}

/// Rotta da aprire al tocco, oppure `null` se il tipo non ha una destinazione.
///
/// Guarda prima `tipo` e poi `targetTipo`, così funzionano sia le notifiche
/// generate dall'evento sia quelle collegate a un elemento.
String? rottaNotifica(Notifica notifica) {
  for (final tipo in [notifica.tipo, notifica.targetTipo]) {
    switch (tipo?.trim().toLowerCase()) {
      case 'appuntamento':
        return '/calendario';
      case 'task':
        return '/task';
      case 'chat':
        return '/chat';
    }
  }
  return null;
}

IconData _iconaTipoNotifica(String? tipo) {
  switch (tipo?.trim().toLowerCase()) {
    case 'appuntamento':
      return Icons.event_outlined;
    case 'task':
      return Icons.task_alt;
    case 'promemoria':
      return Icons.alarm;
    case 'chat':
      return Icons.chat_bubble_outline;
    case 'comunicazione':
      return Icons.campaign_outlined;
    default:
      return Icons.notifications_none;
  }
}

IconData _iconaNotifica(Notifica notifica) =>
    _iconaTipoNotifica(notifica.tipo ?? notifica.targetTipo);

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Elenco delle notifiche dell'utente corrente, con filtro Tutte / Non lette.
class NotificheScreen extends ConsumerStatefulWidget {
  const NotificheScreen({super.key});

  @override
  ConsumerState<NotificheScreen> createState() => _NotificheScreenState();
}

class _NotificheScreenState extends ConsumerState<NotificheScreen> {
  List<Notifica> _notifiche = const [];
  StreamSubscription<List<Notifica>>? _sottoscrizione;

  bool _caricamento = true;
  bool _soloNonLette = false;
  bool _segnaTutteInCorso = false;
  Object? _errore;
  String? _erroreAzione;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _sottoscrizione?.cancel();
    super.dispose();
  }

  /// Carica le notifiche e poi si aggiorna in tempo reale dallo stream.
  Future<void> _carica() async {
    await _sottoscrizione?.cancel();
    _sottoscrizione = null;
    if (!mounted) return;

    setState(() {
      _caricamento = true;
      _errore = null;
      _erroreAzione = null;
    });

    final servizio = ref.read(spServiceProvider);
    try {
      final notifiche = await servizio.getNotifiche();
      if (!mounted) return;
      setState(() {
        _notifiche = notifiche;
        _caricamento = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = errore;
        _caricamento = false;
      });
      return;
    }

    if (!mounted) return;
    _sottoscrizione = servizio.notificheStream().listen(
      (notifiche) {
        if (!mounted) return;
        setState(() {
          _notifiche = notifiche;
          _caricamento = false;
          _errore = null;
        });
      },
      onError: (Object errore) {
        if (!mounted) return;
        setState(() {
          _errore = errore;
          _caricamento = false;
        });
      },
    );
  }

  List<Notifica> get _visibili =>
      _soloNonLette ? filtraNotificheNonLette(_notifiche) : _notifiche;

  /// Segna letta la notifica (se serve) senza bloccare la navigazione.
  Future<void> _segnaLetta(Notifica notifica) async {
    if (!notificaNonLetta(notifica)) return;
    try {
      await ref.read(spServiceProvider).segnaNotificaLetta(notifica.id);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _erroreAzione = messaggioErroreNotifiche(errore));
    }
  }

  /// Tocco su una voce: segna letta e, se il tipo lo prevede, apre la sezione.
  Future<void> _apriNotifica(Notifica notifica) async {
    await _segnaLetta(notifica);
    if (!mounted) return;
    final rotta = rottaNotifica(notifica);
    if (rotta != null) context.go(rotta);
  }

  Future<void> _segnaTutteLette() async {
    final nonLette = filtraNotificheNonLette(_notifiche);
    if (nonLette.isEmpty || _segnaTutteInCorso) return;

    setState(() {
      _segnaTutteInCorso = true;
      _erroreAzione = null;
    });
    try {
      await ref.read(spServiceProvider).segnaTutteNotificheLette([
        for (final notifica in nonLette) notifica.id,
      ]);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _erroreAzione = messaggioErroreNotifiche(errore));
    } finally {
      if (mounted) setState(() => _segnaTutteInCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nonLette = contaNotificheNonLette(_notifiche);

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale = largo
            ? AppSpazi.paginaDesktop
            : AppSpazi.paginaTelefono;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                orizzontale,
                orizzontale,
                0,
              ),
              child: _IntestazioneNotifiche(
                nonLette: nonLette,
                inCorso: _segnaTutteInCorso,
                onSegnaTutte: _segnaTutteLette,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                orizzontale,
                AppSpazi.s,
                orizzontale,
                AppSpazi.s,
              ),
              child: SegmentedButton<String>(
                key: const Key('notifiche-filtro'),
                segments: const [
                  ButtonSegment<String>(
                    value: 'tutte',
                    label: Text('Tutte'),
                    icon: Icon(Icons.all_inbox_outlined),
                  ),
                  ButtonSegment<String>(
                    value: 'non-lette',
                    label: Text('Non lette'),
                    icon: Icon(Icons.mark_email_unread_outlined),
                  ),
                ],
                selected: {_soloNonLette ? 'non-lette' : 'tutte'},
                showSelectedIcon: false,
                onSelectionChanged: (selezione) => setState(
                  () => _soloNonLette = selezione.first == 'non-lette',
                ),
              ),
            ),
            if (_erroreAzione != null)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  orizzontale,
                  0,
                  orizzontale,
                  AppSpazi.s,
                ),
                child: AvvisoErrore(
                  key: const Key('notifiche-errore-azione'),
                  testo: _erroreAzione!,
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
                child: CorpoNotifiche(
                  notifiche: _visibili,
                  caricamento: _caricamento,
                  errore: _errore,
                  soloNonLette: _soloNonLette,
                  onRiprova: _carica,
                  onApri: _apriNotifica,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Intestazione con titolo, badge delle non lette e azione "Segna tutte".
class _IntestazioneNotifiche extends StatelessWidget {
  const _IntestazioneNotifiche({
    required this.nonLette,
    required this.inCorso,
    required this.onSegnaTutte,
  });

  final int nonLette;
  final bool inCorso;
  final VoidCallback onSegnaTutte;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final titolo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Notifiche', style: tema.textTheme.titleLarge),
        if (nonLette > 0) ...[
          const SizedBox(width: AppSpazi.xs),
          Container(
            key: const Key('notifiche-badge'),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpazi.xs,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: tema.colorScheme.primary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$nonLette',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );

    final pulsante = OutlinedButton.icon(
      key: const Key('notifiche-segna-tutte'),
      onPressed: nonLette == 0 || inCorso ? null : onSegnaTutte,
      icon: inCorso
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.done_all),
      label: const Text('Segna tutte come lette'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 480) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titolo,
              const SizedBox(height: AppSpazi.xs),
              pulsante,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: titolo),
            const SizedBox(width: AppSpazi.s),
            pulsante,
          ],
        );
      },
    );
  }
}

/// Corpo della schermata: caricamento, errore, vuoto oppure elenco.
///
/// È pubblico per i test widget: non richiede Firebase né provider.
class CorpoNotifiche extends StatelessWidget {
  const CorpoNotifiche({
    super.key,
    required this.notifiche,
    required this.caricamento,
    this.errore,
    this.soloNonLette = false,
    this.onRiprova,
    this.onApri,
  });

  final List<Notifica> notifiche;
  final bool caricamento;
  final Object? errore;
  final bool soloNonLette;
  final VoidCallback? onRiprova;
  final ValueChanged<Notifica>? onApri;

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        child: CircularProgressIndicator(key: Key('notifiche-caricamento')),
      );
    }

    if (errore != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AvvisoErrore(
                key: const Key('notifiche-errore'),
                testo: messaggioErroreNotifiche(errore!, caricamento: true),
              ),
              const SizedBox(height: AppSpazi.m),
              FilledButton.icon(
                key: const Key('notifiche-riprova'),
                onPressed: onRiprova,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (notifiche.isEmpty) {
      return StatoCentrato(
        key: const Key('notifiche-vuoto'),
        icona: soloNonLette
            ? Icons.mark_email_read_outlined
            : Icons.notifications_none,
        titolo: soloNonLette
            ? 'Nessuna notifica non letta'
            : 'Nessuna notifica',
        sottotitolo: soloNonLette ? 'Hai letto tutte le notifiche.' : 'Qui vedrai gli avvisi su appuntamenti, task, promemoria, chat e comunicazioni.',
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.separated(
          key: const Key('notifiche-lista'),
          padding: EdgeInsets.zero,
          itemCount: notifiche.length,
          separatorBuilder: (context, indice) =>
              const SizedBox(height: AppSpazi.xs),
          itemBuilder: (context, indice) {
            final notifica = notifiche[indice];
            return _VoceNotifica(notifica: notifica, onApri: onApri);
          },
        ),
      ),
    );
  }
}

/// Riga di una notifica: icona del tipo, titolo, testo, data/ora e punto.
class _VoceNotifica extends StatelessWidget {
  const _VoceNotifica({required this.notifica, this.onApri});

  final Notifica notifica;
  final ValueChanged<Notifica>? onApri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nonLetta = notificaNonLetta(notifica);
    final titolo = (notifica.titolo ?? '').trim();
    final testo = (notifica.testo ?? '').trim();
    final tipo = etichettaTipoNotificaBreve(notifica.tipo);

    return Card(
      key: Key('notifica-${notifica.id}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onApri == null ? null : () => onApri!(notifica),
        child: Padding(
          padding: const EdgeInsets.all(AppSpazi.s),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: nonLetta
                      ? tema.colorScheme.primaryContainer
                      : tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRaggi.chip),
                ),
                child: Icon(
                  _iconaNotifica(notifica),
                  size: 22,
                  color: nonLetta
                      ? tema.colorScheme.onPrimaryContainer
                      : tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppSpazi.s),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo.isEmpty ? tipo : titolo,
                      style: tema.textTheme.bodyLarge?.copyWith(
                        fontWeight: nonLetta
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (testo.isNotEmpty) ...[
                      const SizedBox(height: AppSpazi.xxs),
                      Text(
                        testo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpazi.xs),
                    Wrap(
                      spacing: AppSpazi.s,
                      runSpacing: AppSpazi.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _DettaglioNotifica(
                          icona: Icons.schedule,
                          testo: formattaDataOraNotifica(notifica),
                        ),
                        _DettaglioNotifica(
                          icona: Icons.label_outline,
                          testo: tipo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (nonLetta) ...[
                const SizedBox(width: AppSpazi.xs),
                Semantics(
                  label: 'Non letta',
                  child: Container(
                    key: Key('notifica-punto-${notifica.id}'),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: tema.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Icona e testo di un dettaglio della notifica.
class _DettaglioNotifica extends StatelessWidget {
  const _DettaglioNotifica({required this.icona, required this.testo});

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icona, size: 14, color: tema.colorScheme.onSurfaceVariant),
        const SizedBox(width: AppSpazi.xxs),
        Text(
          testo,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
