// Condivisione del calendario personale con i colleghi dell'azienda.
//
// I dati passano da `getUtenti()`, `getCondivisioniCalendario()`,
// `getCondivisioniRicevute()`, `condividiCalendario()` e `revocaCondivisione()`
// di `SpService`. Il filtro dei colleghi, i testi e i messaggi di errore sono
// funzioni pure, così restano verificabili senza Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/condivisione_calendario.dart';
import '../../data/models/integrazione_azienda.dart';
import '../../data/models/user_profile.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import 'impostazioni_screen.dart'
    show inizialiProfilo, nomeVisualizzatoProfilo;

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Livello preselezionato nel form: sola lettura con i dettagli degli eventi.
const String livelloPredefinitoCondivisione = 'dettagli';

/// Messaggio in italiano per gli errori di caricamento, condivisione e revoca.
String messaggioErroreCondivisioneCalendario(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per condividere il calendario. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Condivisione calendario non disponibile. Riprova.';
    }
  }
  if (errore is StateError) {
    return 'Esiste già una condivisione con un altro livello. '
        'Revocala prima di cambiarla.';
  }
  return 'Condivisione calendario non disponibile. Controlla la connessione '
      'e riprova.';
}

/// Colleghi con cui si può condividere il calendario.
///
/// Esclude l'utente corrente ([uidCorrente]), i profili senza uid e i
/// duplicati, mantenendo l'ordine ricevuto dal servizio.
List<UserProfile> colleghiCondivisibili(
  List<UserProfile> utenti,
  String? uidCorrente,
) {
  final corrente = (uidCorrente ?? '').trim();
  final visti = <String>{};
  final risultato = <UserProfile>[];
  for (final utente in utenti) {
    final uid = utente.uid.trim();
    if (uid.isEmpty) continue;
    if (corrente.isNotEmpty && uid == corrente) continue;
    if (!visti.add(uid)) continue;
    risultato.add(utente);
  }
  return risultato;
}

/// Profilo corrispondente a [uid], `null` se assente o non indicato.
UserProfile? profiloPerUid(List<UserProfile> utenti, String? uid) {
  final cercato = (uid ?? '').trim();
  if (cercato.isEmpty) return null;
  for (final utente in utenti) {
    if (utente.uid.trim() == cercato) return utente;
  }
  return null;
}

/// Nome da mostrare per l'utente [uid]; "Collega" se il profilo non c'è più.
String nomeUtentePerUid(List<UserProfile> utenti, String? uid) {
  final profilo = profiloPerUid(utenti, uid);
  return profilo == null ? 'Collega' : nomeVisualizzatoProfilo(profilo);
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata `/impostazioni/condivisioni-calendario`: condivisione del proprio
/// calendario con i colleghi dell'azienda attiva.
class CondivisioneCalendarioScreen extends ConsumerStatefulWidget {
  const CondivisioneCalendarioScreen({super.key});

  @override
  ConsumerState<CondivisioneCalendarioScreen> createState() =>
      _CondivisioneCalendarioScreenState();
}

class _CondivisioneCalendarioScreenState
    extends ConsumerState<CondivisioneCalendarioScreen> {
  List<UserProfile> _utenti = const [];
  List<CondivisioneCalendario> _condivisioni = const [];
  List<CondivisioneCalendario> _ricevute = const [];
  String? _uidCorrente;
  bool _caricamento = true;
  bool _salvataggio = false;
  String? _revocaInCorso;
  Object? _errore;
  String? _erroreOperazione;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e carica utenti e condivisioni in
  /// parallelo.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
      _erroreOperazione = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final uidCorrente = ref.read(firebaseAuthProvider).currentUser?.uid;
      final risultati = await Future.wait<Object>([
        servizio.getUtenti(),
        servizio.getCondivisioniCalendario(),
        servizio.getCondivisioniRicevute(),
      ]);
      if (!mounted) return;
      setState(() {
        _utenti = risultati[0] as List<UserProfile>;
        _condivisioni = risultati[1] as List<CondivisioneCalendario>;
        _ricevute = risultati[2] as List<CondivisioneCalendario>;
        _uidCorrente = uidCorrente;
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

  /// Crea la condivisione, ricarica gli elenchi e conferma con uno SnackBar.
  Future<void> _condividi(String destinatarioUid, String livello) async {
    setState(() {
      _salvataggio = true;
      _erroreOperazione = null;
    });
    try {
      await ref.read(spServiceProvider).condividiCalendario(
            destinatarioUid: destinatarioUid,
            livello: livello,
          );
      if (!mounted) return;
      _avviso('Calendario condiviso');
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      final messaggio = messaggioErroreCondivisioneCalendario(errore);
      setState(() => _erroreOperazione = messaggio);
      _avviso(messaggio);
    } finally {
      if (mounted) setState(() => _salvataggio = false);
    }
  }

  /// Revoca la condivisione scelta (la conferma è chiesta dal corpo).
  Future<void> _revoca(CondivisioneCalendario condivisione) async {
    setState(() {
      _revocaInCorso = condivisione.id;
      _erroreOperazione = null;
    });
    try {
      await ref.read(spServiceProvider).revocaCondivisione(condivisione.id);
      if (!mounted) return;
      _avviso('Condivisione revocata');
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      final messaggio = messaggioErroreCondivisioneCalendario(errore);
      setState(() => _erroreOperazione = messaggio);
      _avviso(messaggio);
    } finally {
      if (mounted) setState(() => _revocaInCorso = null);
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
          child: CorpoCondivisioneCalendario(
            utenti: _utenti,
            uidCorrente: _uidCorrente,
            condivisioni: _condivisioni,
            ricevute: _ricevute,
            caricamento: _caricamento,
            salvataggio: _salvataggio,
            revocaInCorso: _revocaInCorso,
            errore: _errore,
            messaggioErroreOperazione: _erroreOperazione,
            onRiprova: _carica,
            onCondividi: _condividi,
            onRevoca: _revoca,
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
class CorpoCondivisioneCalendario extends StatefulWidget {
  const CorpoCondivisioneCalendario({
    super.key,
    required this.utenti,
    required this.uidCorrente,
    required this.condivisioni,
    required this.ricevute,
    required this.onCondividi,
    required this.onRevoca,
    required this.onRiprova,
    this.caricamento = false,
    this.salvataggio = false,
    this.revocaInCorso,
    this.errore,
    this.messaggioErroreOperazione,
  });

  /// Tutti gli utenti dell'azienda attiva (il corpo esclude da solo l'utente
  /// corrente con [colleghiCondivisibili]).
  final List<UserProfile> utenti;

  /// Uid dell'utente corrente, escluso dall'elenco dei colleghi.
  final String? uidCorrente;

  /// Condivisioni fatte dall'utente corrente (proprietario).
  final List<CondivisioneCalendario> condivisioni;

  /// Condivisioni ricevute dall'utente corrente, mostrate in sola lettura.
  final List<CondivisioneCalendario> ricevute;

  /// Riceve il destinatario e il livello scelti, senza validazione aggiuntiva.
  final void Function(String destinatarioUid, String livello) onCondividi;

  /// Riceve la condivisione da revocare dopo la conferma dell'utente.
  final void Function(CondivisioneCalendario condivisione) onRevoca;

  final VoidCallback onRiprova;
  final bool caricamento;
  final bool salvataggio;

  /// Id della condivisione in corso di revoca (pulsante spento con spinner).
  final String? revocaInCorso;

  /// Errore di caricamento; se presente sostituisce il contenuto.
  final Object? errore;

  /// Errore di condivisione o revoca, già in italiano.
  final String? messaggioErroreOperazione;

  @override
  State<CorpoCondivisioneCalendario> createState() =>
      _CorpoCondivisioneCalendarioState();
}

class _CorpoCondivisioneCalendarioState
    extends State<CorpoCondivisioneCalendario> {
  String? _collegaUid;
  String _livello = livelloPredefinitoCondivisione;

  /// Chiede conferma e, solo se accettata, passa la condivisione a `onRevoca`.
  Future<void> _chiediRevoca(CondivisioneCalendario condivisione) async {
    final nome = nomeUtentePerUid(widget.utenti, condivisione.destinatarioUid);
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('dialog-revoca-condivisione'),
        title: const Text('Revocare l\'accesso?'),
        content: Text('Vuoi revocare l\'accesso a $nome?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            key: const Key('conferma-revoca-condivisione'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoca'),
          ),
        ],
      ),
    );
    if (conferma != true) return;
    widget.onRevoca(condivisione);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caricamento) {
      return const Center(
        key: Key('condivisione-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (widget.errore != null) {
      return StatoCentrato(
        key: const Key('condivisione-errore-caricamento'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Condivisione non disponibile',
        sottotitolo: messaggioErroreCondivisioneCalendario(widget.errore!),
        azione: OutlinedButton.icon(
          key: const Key('condivisione-riprova'),
          onPressed: widget.onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final tema = Theme.of(context);
    final colleghi =
        colleghiCondivisibili(widget.utenti, widget.uidCorrente);
    final collegaSelezionato = colleghi.any((c) => c.uid == _collegaUid)
        ? _collegaUid
        : null;
    final messaggioErrore = widget.messaggioErroreOperazione;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Condivisione calendario',
                key: const Key('condivisione-titolo'),
                style: tema.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpazi.xxs),
              Text(
                'Condividi il tuo calendario con un collega della stessa '
                'azienda.',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpazi.m),
              if (messaggioErrore != null) ...[
                AvvisoErrore(
                  key: const Key('condivisione-errore'),
                  testo: messaggioErrore,
                ),
                const SizedBox(height: AppSpazi.s),
              ],
              _CardSezioneCondivisione(
                chiave: const Key('condivisione-sezione-nuova'),
                titolo: 'Condividi il mio calendario',
                icona: Icons.share_outlined,
                figli: [
                  if (colleghi.isEmpty)
                    Text(
                      'Nessun collega disponibile: invita un\'altra persona '
                      'nell\'azienda per condividere il calendario.',
                      key: const Key('condivisione-nessun-collega'),
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      key: const Key('condivisione-collega'),
                      initialValue: collegaSelezionato,
                      isExpanded: true,
                      itemHeight: 64,
                      decoration: const InputDecoration(
                        labelText: 'Collega',
                        helperText: 'Solo persone della tua azienda.',
                      ),
                      hint: const Text('Scegli un collega'),
                      selectedItemBuilder: (context) => [
                        for (final collega in colleghi)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              nomeVisualizzatoProfilo(collega),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      items: [
                        for (final collega in colleghi)
                          DropdownMenuItem(
                            value: collega.uid,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nomeVisualizzatoProfilo(collega),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((collega.email ?? '').trim().isNotEmpty)
                                  Text(
                                    collega.email!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tema.textTheme.bodySmall?.copyWith(
                                      color: tema.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (valore) {
                        if (valore != null) {
                          setState(() => _collegaUid = valore);
                        }
                      },
                    ),
                  const SizedBox(height: AppSpazi.s),
                  DropdownButtonFormField<String>(
                    key: const Key('condivisione-livello'),
                    initialValue: _livello,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Livello di accesso',
                    ),
                    items: [
                      for (final livello in livelliCondivisione)
                        DropdownMenuItem(
                          value: livello,
                          child: Text(etichettaLivelloCondivisione(livello)),
                        ),
                    ],
                    onChanged: (valore) {
                      if (valore != null) setState(() => _livello = valore);
                    },
                  ),
                  if (_livello == 'modifica') ...[
                    const SizedBox(height: AppSpazi.s),
                    Container(
                      key: const Key('condivisione-avviso-modifica'),
                      padding: const EdgeInsets.all(AppSpazi.s),
                      decoration: BoxDecoration(
                        color: AppColors.attesa.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRaggi.chip),
                        border: Border.all(color: AppColors.attesa),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_outlined,
                            size: 20,
                            color: AppColors.attesa,
                          ),
                          const SizedBox(width: AppSpazi.xs),
                          Expanded(
                            child: Text(
                              'Il collega potrà modificare i tuoi '
                              'appuntamenti.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: AppColors.attesa,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpazi.m),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      key: const Key('condivisione-crea'),
                      onPressed: (collegaSelezionato == null ||
                              widget.salvataggio)
                          ? null
                          : () => widget.onCondividi(
                                collegaSelezionato,
                                _livello,
                              ),
                      icon: widget.salvataggio
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.share_outlined),
                      label: Text(
                        widget.salvataggio
                            ? 'Condivisione…'
                            : 'Condividi calendario',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardSezioneCondivisione(
                chiave: const Key('condivisione-sezione-attive'),
                titolo: 'Condivisioni attive',
                icona: Icons.people_outline,
                senzaPadding: widget.condivisioni.isNotEmpty,
                figli: widget.condivisioni.isEmpty
                    ? [
                        Text(
                          'Non hai ancora condiviso il tuo calendario',
                          key: const Key('condivisione-vuoto'),
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ]
                    : [
                        for (var indice = 0;
                            indice < widget.condivisioni.length;
                            indice++) ...[
                          if (indice > 0) const Divider(height: 1),
                          _RigaCondivisione(
                            condivisione: widget.condivisioni[indice],
                            utenti: widget.utenti,
                            revocaInCorso: widget.revocaInCorso ==
                                widget.condivisioni[indice].id,
                            onRevoca: () => _chiediRevoca(
                              widget.condivisioni[indice],
                            ),
                          ),
                        ],
                      ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardSezioneCondivisione(
                chiave: const Key('condivisione-sezione-ricevute'),
                titolo: 'Condivisi con me',
                icona: Icons.event_available_outlined,
                senzaPadding: widget.ricevute.isNotEmpty,
                figli: widget.ricevute.isEmpty
                    ? [
                        Text(
                          'Nessun calendario condiviso con te',
                          key: const Key('condivisione-ricevute-vuoto'),
                          style: tema.textTheme.bodyMedium?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ]
                    : [
                        for (var indice = 0;
                            indice < widget.ricevute.length;
                            indice++) ...[
                          if (indice > 0) const Divider(height: 1),
                          _RigaCondivisione(
                            condivisione: widget.ricevute[indice],
                            utenti: widget.utenti,
                            solaLettura: true,
                          ),
                        ],
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Riga di condivisione: avatar, nome, badge livello e, se richiesto, revoca.
class _RigaCondivisione extends StatelessWidget {
  const _RigaCondivisione({
    required this.condivisione,
    required this.utenti,
    this.solaLettura = false,
    this.revocaInCorso = false,
    this.onRevoca,
  });

  final CondivisioneCalendario condivisione;
  final List<UserProfile> utenti;

  /// Le condivisioni ricevute non si revocano da qui.
  final bool solaLettura;
  final bool revocaInCorso;
  final VoidCallback? onRevoca;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final uid = solaLettura
        ? condivisione.proprietarioUid
        : condivisione.destinatarioUid;
    final profilo = profiloPerUid(utenti, uid);
    final email = profilo?.email?.trim() ?? '';

    return ListTile(
      key: Key('condivisione-riga-$uid'),
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: tema.colorScheme.primaryContainer,
        foregroundColor: tema.colorScheme.onPrimaryContainer,
        child: Text(
          inizialiProfilo(profilo),
          style: tema.textTheme.labelLarge?.copyWith(
            color: tema.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(nomeUtentePerUid(utenti, uid)),
      subtitle: solaLettura && condivisione.livello == 'dettagli'
          ? const Text('Sola lettura')
          : (email.isEmpty ? null : Text(email)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BadgeLivello(livello: condivisione.livello),
          if (!solaLettura) ...[
            const SizedBox(width: AppSpazi.xs),
            if (revocaInCorso)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                key: Key('condivisione-revoca-${uid ?? condivisione.id}'),
                tooltip: 'Revoca condivisione',
                onPressed: onRevoca,
                icon: const Icon(Icons.link_off),
              ),
          ],
        ],
      ),
    );
  }
}

/// Badge compatto con l'etichetta del livello di condivisione.
class _BadgeLivello extends StatelessWidget {
  const _BadgeLivello({required this.livello});

  final String livello;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore =
        livello == 'modifica' ? AppColors.attesa : tema.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpazi.xs,
        vertical: AppSpazi.xxs,
      ),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRaggi.chip),
        border: Border.all(color: colore.withValues(alpha: 0.5)),
      ),
      child: Text(
        etichettaLivelloCondivisione(livello),
        style: tema.textTheme.labelSmall?.copyWith(color: colore),
      ),
    );
  }
}

/// Card di una sezione con intestazione (icona + titolo).
class _CardSezioneCondivisione extends StatelessWidget {
  const _CardSezioneCondivisione({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.figli,
    this.senzaPadding = false,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final List<Widget> figli;

  /// Per gli elenchi: le righe arrivano fino al bordo della card.
  final bool senzaPadding;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final intestazione = Row(
      children: [
        Icon(icona, size: 20, color: tema.colorScheme.primary),
        const SizedBox(width: AppSpazi.xs),
        Expanded(child: Text(titolo, style: tema.textTheme.titleSmall)),
      ],
    );

    return Card(
      key: chiave,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpazi.internoCard,
          AppSpazi.internoCard,
          AppSpazi.internoCard,
          senzaPadding ? AppSpazi.xxs : AppSpazi.internoCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            intestazione,
            const SizedBox(height: AppSpazi.s),
            ...figli,
          ],
        ),
      ),
    );
  }
}
