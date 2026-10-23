// Preferenze di notifica dell'utente per l'azienda attiva.
//
// Le preferenze vivono in `impostazioni_notifiche/{aziendaId}_{uid}` e sono
// lette/scritte con `getPreferenzeNotifiche()` e `salvaPreferenzeNotifiche()`.
// Il modello, la normalizzazione degli orari e i messaggi di errore sono puri,
// così restano verificabili senza Firebase.

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Costanti e funzioni pure (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Orario di silenzio predefinito: inizio.
const String orarioSilenzioInizioPredefinito = '22:00';

/// Orario di silenzio predefinito: fine.
const String orarioSilenzioFinePredefinito = '08:00';

/// Chiavi usate su Firestore per le preferenze di notifica.
abstract final class ChiaviPreferenzeNotifiche {
  static const String canalePush = 'canale_push';
  static const String canaleWhatsapp = 'canale_whatsapp';
  static const String canaleChat = 'canale_chat';
  static const String numeroWhatsapp = 'numero_whatsapp';
  static const String consensoWhatsapp = 'consenso_whatsapp';
  static const String silenzioDa = 'silenzio_da';
  static const String silenzioA = 'silenzio_a';
  static const String urgenzePassano = 'urgenze_passano';
  static const String anteprimaPush = 'anteprima_push';
}

/// L'orario segue il formato `HH:MM` (24 ore)?
///
/// Accetta solo due cifre per l'ora e due per i minuti, dopo aver tolto gli
/// spazi ai lati. `null`, stringa vuota e valori fuori scala sono non validi.
bool orarioValidoNotifiche(String? orario) {
  final testo = (orario ?? '').trim();
  return RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(testo);
}

/// Orario normalizzato in `HH:MM`: se il valore non è valido torna
/// [predefinito] (di norma `22:00`; per la fine del silenzio `08:00`).
String normalizzaOrarioNotifiche(
  String? orario, {
  String predefinito = orarioSilenzioInizioPredefinito,
}) {
  final testo = (orario ?? '').trim();
  return orarioValidoNotifiche(testo) ? testo : predefinito;
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio.
String messaggioErrorePreferenzeNotifiche(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per cambiare le notifiche. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Preferenze non disponibili. Riprova.';
    }
  }
  return 'Preferenze non disponibili. Controlla la connessione e riprova.';
}

/// Testo breve di privacy mostrato sotto il consenso WhatsApp.
const String testoPrivacyWhatsapp =
    'Il numero serve solo alle notifiche WhatsApp dell\'azienda (preventivi, '
    'visite, promemoria). Non viene condiviso con terzi e puoi revocare il '
    'consenso quando vuoi.';

/// Testo che spiega il comportamento del push senza anteprima.
const String testoAnteprimPush =
    'Con l\'anteprima attiva il push mostra il contenuto del messaggio. '
    'Se la disattivi, il push resta generico: nessun dato compare sulla '
    'schermata di blocco.';

// ---------------------------------------------------------------------------
// Modello delle preferenze
// ---------------------------------------------------------------------------

/// Preferenze di notifica dell'utente per l'azienda attiva.
///
/// I default rispecchiano il comportamento atteso: push e chat attivi,
/// WhatsApp spento senza consenso, silenzio 22:00–08:00, anteprima attiva.
@immutable
class PreferenzeNotifiche {
  const PreferenzeNotifiche({
    this.push = true,
    this.whatsapp = false,
    this.chat = true,
    this.numeroWhatsapp = '',
    this.consensoWhatsapp = false,
    this.silenzioInizio = orarioSilenzioInizioPredefinito,
    this.silenzioFine = orarioSilenzioFinePredefinito,
    this.urgenzePassano = true,
    this.anteprimaPush = true,
  });

  /// Preferenze predefinite, usate quando il documento non esiste.
  static const PreferenzeNotifiche predefinite = PreferenzeNotifiche();

  /// Costruisce le preferenze da un documento Firestore (anche `null`).
  ///
  /// I campi assenti o di tipo inatteso ricadono sui default; gli orari
  /// vengono normalizzati in `HH:MM`.
  factory PreferenzeNotifiche.daMappa(Map<String, dynamic>? dati) {
    final valori = dati ?? const <String, dynamic>{};
    return PreferenzeNotifiche(
      push: _booleano(valori[ChiaviPreferenzeNotifiche.canalePush], true),
      whatsapp: _booleano(
        valori[ChiaviPreferenzeNotifiche.canaleWhatsapp],
        false,
      ),
      // La chat in-app resta sempre attiva: non è disattivabile.
      chat: true,
      numeroWhatsapp:
          (valori[ChiaviPreferenzeNotifiche.numeroWhatsapp] ?? '').toString().trim(),
      consensoWhatsapp: _booleano(
        valori[ChiaviPreferenzeNotifiche.consensoWhatsapp],
        false,
      ),
      silenzioInizio: normalizzaOrarioNotifiche(
        valori[ChiaviPreferenzeNotifiche.silenzioDa]?.toString(),
      ),
      silenzioFine: normalizzaOrarioNotifiche(
        valori[ChiaviPreferenzeNotifiche.silenzioA]?.toString(),
        predefinito: orarioSilenzioFinePredefinito,
      ),
      urgenzePassano: _booleano(
        valori[ChiaviPreferenzeNotifiche.urgenzePassano],
        true,
      ),
      anteprimaPush: _booleano(
        valori[ChiaviPreferenzeNotifiche.anteprimaPush],
        true,
      ),
    );
  }

  final bool push;
  final bool whatsapp;
  final bool chat;
  final String numeroWhatsapp;
  final bool consensoWhatsapp;
  final String silenzioInizio;
  final String silenzioFine;
  final bool urgenzePassano;
  final bool anteprimaPush;

  /// Copia con i campi indicati sostituiti.
  PreferenzeNotifiche copiaCon({
    bool? push,
    bool? whatsapp,
    bool? chat,
    String? numeroWhatsapp,
    bool? consensoWhatsapp,
    String? silenzioInizio,
    String? silenzioFine,
    bool? urgenzePassano,
    bool? anteprimaPush,
  }) {
    return PreferenzeNotifiche(
      push: push ?? this.push,
      whatsapp: whatsapp ?? this.whatsapp,
      chat: chat ?? this.chat,
      numeroWhatsapp: numeroWhatsapp ?? this.numeroWhatsapp,
      consensoWhatsapp: consensoWhatsapp ?? this.consensoWhatsapp,
      silenzioInizio: silenzioInizio ?? this.silenzioInizio,
      silenzioFine: silenzioFine ?? this.silenzioFine,
      urgenzePassano: urgenzePassano ?? this.urgenzePassano,
      anteprimaPush: anteprimaPush ?? this.anteprimaPush,
    );
  }

  /// Orari normalizzati in `HH:MM` prima del salvataggio.
  PreferenzeNotifiche conOrariNormalizzati() {
    return copiaCon(
      silenzioInizio: normalizzaOrarioNotifiche(silenzioInizio),
      silenzioFine: normalizzaOrarioNotifiche(
        silenzioFine,
        predefinito: orarioSilenzioFinePredefinito,
      ),
    );
  }

  /// Mappa da scrivere su Firestore con merge.
  Map<String, dynamic> aMappa() {
    final normalizzate = conOrariNormalizzati();
    return {
      ChiaviPreferenzeNotifiche.canalePush: normalizzate.push,
      ChiaviPreferenzeNotifiche.canaleWhatsapp: normalizzate.whatsapp,
      ChiaviPreferenzeNotifiche.canaleChat: true,
      ChiaviPreferenzeNotifiche.numeroWhatsapp:
          normalizzate.numeroWhatsapp.trim(),
      ChiaviPreferenzeNotifiche.consensoWhatsapp: normalizzate.consensoWhatsapp,
      ChiaviPreferenzeNotifiche.silenzioDa: normalizzate.silenzioInizio,
      ChiaviPreferenzeNotifiche.silenzioA: normalizzate.silenzioFine,
      ChiaviPreferenzeNotifiche.urgenzePassano: normalizzate.urgenzePassano,
      ChiaviPreferenzeNotifiche.anteprimaPush: normalizzate.anteprimaPush,
    };
  }
}

bool _booleano(Object? valore, bool predefinito) {
  if (valore is bool) return valore;
  if (valore is String) {
    final testo = valore.trim().toLowerCase();
    if (testo == 'true') return true;
    if (testo == 'false') return false;
  }
  return predefinito;
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata `/impostazioni/notifiche`: canali, WhatsApp, silenzio e push.
class NotifichePreferenzeScreen extends ConsumerStatefulWidget {
  const NotifichePreferenzeScreen({super.key});

  @override
  ConsumerState<NotifichePreferenzeScreen> createState() =>
      _NotifichePreferenzeScreenState();
}

class _NotifichePreferenzeScreenState
    extends ConsumerState<NotifichePreferenzeScreen> {
  PreferenzeNotifiche _preferenze = PreferenzeNotifiche.predefinite;
  bool _caricamento = true;
  bool _salvataggio = false;
  Object? _errore;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e legge le preferenze dell'utente.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      servizio.setAziendaAttiva(ref.read(aziendaAttivaProvider));
      final dati = await servizio.getPreferenzeNotifiche();
      if (!mounted) return;
      setState(() {
        _preferenze = PreferenzeNotifiche.daMappa(dati);
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

  /// Valida e salva le preferenze, poi mostra la conferma.
  Future<void> _salva() async {
    final normalizzate = _preferenze.conOrariNormalizzati();
    if (!orarioValidoNotifiche(normalizzate.silenzioInizio) ||
        !orarioValidoNotifiche(normalizzate.silenzioFine)) {
      _avviso('Inserisci gli orari nel formato HH:MM.');
      return;
    }
    if (normalizzate.consensoWhatsapp &&
        normalizzate.numeroWhatsapp.trim().isEmpty) {
      _avviso('Inserisci il numero WhatsApp per dare il consenso.');
      return;
    }

    setState(() {
      _preferenze = normalizzate;
      _salvataggio = true;
    });
    try {
      await ref
          .read(spServiceProvider)
          .salvaPreferenzeNotifiche(normalizzate.aMappa());
      if (!mounted) return;
      setState(() => _salvataggio = false);
      _avviso('Preferenze salvate');
    } catch (errore) {
      if (!mounted) return;
      setState(() => _salvataggio = false);
      _avviso(messaggioErrorePreferenzeNotifiche(errore));
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
          child: CorpoNotifichePreferenze(
            preferenze: _preferenze,
            caricamento: _caricamento,
            salvataggio: _salvataggio,
            errore: _errore,
            onModifica: (preferenze) =>
                setState(() => _preferenze = preferenze),
            onRiprova: _carica,
            onSalva: _salva,
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
class CorpoNotifichePreferenze extends StatefulWidget {
  const CorpoNotifichePreferenze({
    super.key,
    required this.preferenze,
    required this.onModifica,
    required this.onSalva,
    required this.onRiprova,
    this.caricamento = false,
    this.salvataggio = false,
    this.errore,
  });

  final PreferenzeNotifiche preferenze;
  final void Function(PreferenzeNotifiche) onModifica;
  final VoidCallback onSalva;
  final VoidCallback onRiprova;
  final bool caricamento;
  final bool salvataggio;
  final Object? errore;

  @override
  State<CorpoNotifichePreferenze> createState() =>
      _CorpoNotifichePreferenzeState();
}

class _CorpoNotifichePreferenzeState extends State<CorpoNotifichePreferenze> {
  late final TextEditingController _numero;
  late final TextEditingController _inizio;
  late final TextEditingController _fine;

  @override
  void initState() {
    super.initState();
    _numero = TextEditingController(text: widget.preferenze.numeroWhatsapp);
    _inizio = TextEditingController(text: widget.preferenze.silenzioInizio);
    _fine = TextEditingController(text: widget.preferenze.silenzioFine);
  }

  @override
  void didUpdateWidget(CorpoNotifichePreferenze vecchio) {
    super.didUpdateWidget(vecchio);
    _sincronizza(_numero, widget.preferenze.numeroWhatsapp);
    _sincronizza(_inizio, widget.preferenze.silenzioInizio);
    _sincronizza(_fine, widget.preferenze.silenzioFine);
  }

  /// Aggiorna il controller solo se il testo è davvero cambiato, così il
  /// cursore non salta mentre l'utente scrive.
  void _sincronizza(TextEditingController controller, String valore) {
    if (controller.text == valore) return;
    controller.value = TextEditingValue(
      text: valore,
      selection: TextSelection.collapsed(offset: valore.length),
    );
  }

  @override
  void dispose() {
    _numero.dispose();
    _inizio.dispose();
    _fine.dispose();
    super.dispose();
  }

  PreferenzeNotifiche get _preferenze => widget.preferenze;

  void _modifica(PreferenzeNotifiche nuove) => widget.onModifica(nuove);

  /// Apre il selettore dell'ora e riporta il risultato nel campo.
  Future<void> _scegliOra({
    required String valoreAttuale,
    required String predefinito,
    required void Function(String) onScelta,
  }) async {
    final base = orarioValidoNotifiche(valoreAttuale)
        ? valoreAttuale
        : normalizzaOrarioNotifiche(valoreAttuale, predefinito: predefinito);
    final parti = base.split(':');
    final scelta = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parti[0]) ?? 0,
        minute: int.tryParse(parti[1]) ?? 0,
      ),
      helpText: 'Scegli l\'orario',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
    );
    if (scelta == null) return;
    final ora = scelta.hour.toString().padLeft(2, '0');
    final minuti = scelta.minute.toString().padLeft(2, '0');
    onScelta('$ora:$minuti');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.caricamento) {
      return const Center(
        key: Key('notifiche-preferenze-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (widget.errore != null) {
      return StatoCentrato(
        key: const Key('notifiche-preferenze-errore'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Preferenze non disponibili',
        sottotitolo: messaggioErrorePreferenzeNotifiche(widget.errore!),
        azione: OutlinedButton.icon(
          key: const Key('notifiche-preferenze-riprova'),
          onPressed: widget.onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final tema = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SezioneCard(
                chiave: const Key('notifiche-sezione-canali'),
                titolo: 'Canali',
                icona: Icons.tune,
                figli: [
                  SwitchListTile(
                    key: const Key('notifiche-push'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Push'),
                    subtitle: const Text('Avvisi sul dispositivo'),
                    value: _preferenze.push,
                    onChanged: (valore) =>
                        _modifica(_preferenze.copiaCon(push: valore)),
                  ),
                  SwitchListTile(
                    key: const Key('notifiche-whatsapp'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('WhatsApp'),
                    subtitle: const Text('Messaggi sul numero indicato sotto'),
                    value: _preferenze.whatsapp,
                    onChanged: (valore) =>
                        _modifica(_preferenze.copiaCon(whatsapp: valore)),
                  ),
                  SwitchListTile(
                    key: const Key('notifiche-chat'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chat nell\'app'),
                    subtitle: const Text(
                      'Sempre attiva: le notifiche in-app non si possono '
                      'disattivare.',
                    ),
                    value: true,
                    onChanged: null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _SezioneCard(
                chiave: const Key('notifiche-sezione-whatsapp'),
                titolo: 'WhatsApp',
                icona: Icons.chat_bubble_outline,
                figli: [
                  TextField(
                    key: const Key('notifiche-numero-whatsapp'),
                    controller: _numero,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Numero WhatsApp',
                      hintText: '+39 333 1234567',
                      helperText: 'Scrivi il numero in formato internazionale.',
                    ),
                    onChanged: (testo) =>
                        _modifica(_preferenze.copiaCon(numeroWhatsapp: testo)),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  SwitchListTile(
                    key: const Key('notifiche-consenso-whatsapp'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Consenso ai messaggi WhatsApp'),
                    subtitle: const Text(
                      'Senza consenso non ricevi messaggi su WhatsApp.',
                    ),
                    value: _preferenze.consensoWhatsapp,
                    onChanged: (valore) => _modifica(
                      _preferenze.copiaCon(consensoWhatsapp: valore),
                    ),
                  ),
                  const SizedBox(height: AppSpazi.xxs),
                  Text(
                    testoPrivacyWhatsapp,
                    key: const Key('notifiche-privacy-whatsapp'),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _SezioneCard(
                chiave: const Key('notifiche-sezione-silenzio'),
                titolo: 'Orari di silenzio',
                icona: Icons.nightlight_outlined,
                figli: [
                  Text(
                    'In queste ore non ricevi notifiche, salvo quelle '
                    'urgenti.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final stretti = constraints.maxWidth < 420;
                      final inizio = _CampoOrario(
                        campoKey: const Key('notifiche-silenzio-inizio'),
                        etichetta: 'Dalle',
                        controller: _inizio,
                        onCambia: (testo) => _modifica(
                          _preferenze.copiaCon(silenzioInizio: testo),
                        ),
                        onScegli: () => _scegliOra(
                          valoreAttuale: _inizio.text,
                          predefinito: orarioSilenzioInizioPredefinito,
                          onScelta: (orario) {
                            _inizio.text = orario;
                            _modifica(
                              _preferenze.copiaCon(silenzioInizio: orario),
                            );
                          },
                        ),
                      );
                      final fine = _CampoOrario(
                        campoKey: const Key('notifiche-silenzio-fine'),
                        etichetta: 'Alle',
                        controller: _fine,
                        onCambia: (testo) => _modifica(
                          _preferenze.copiaCon(silenzioFine: testo),
                        ),
                        onScegli: () => _scegliOra(
                          valoreAttuale: _fine.text,
                          predefinito: orarioSilenzioFinePredefinito,
                          onScelta: (orario) {
                            _fine.text = orario;
                            _modifica(
                              _preferenze.copiaCon(silenzioFine: orario),
                            );
                          },
                        ),
                      );
                      if (stretti) {
                        return Column(
                          children: [
                            inizio,
                            const SizedBox(height: AppSpazi.s),
                            fine,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: inizio),
                          const SizedBox(width: AppSpazi.m),
                          Expanded(child: fine),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSpazi.s),
                  SwitchListTile(
                    key: const Key('notifiche-urgenze'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Le urgenze passano comunque'),
                    subtitle: const Text(
                      'Le notifiche urgenti arrivano anche negli orari di '
                      'silenzio.',
                    ),
                    value: _preferenze.urgenzePassano,
                    onChanged: (valore) => _modifica(
                      _preferenze.copiaCon(urgenzePassano: valore),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _SezioneCard(
                chiave: const Key('notifiche-sezione-push'),
                titolo: 'Push',
                icona: Icons.notifications_outlined,
                figli: [
                  SwitchListTile(
                    key: const Key('notifiche-anteprima'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mostra l\'anteprima del testo'),
                    subtitle: const Text(
                      'Nel push compare un\'anteprima del contenuto.',
                    ),
                    value: _preferenze.anteprimaPush,
                    onChanged: (valore) => _modifica(
                      _preferenze.copiaCon(anteprimaPush: valore),
                    ),
                  ),
                  const SizedBox(height: AppSpazi.xxs),
                  Text(
                    testoAnteprimPush,
                    key: const Key('notifiche-testo-anteprima'),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpazi.l),
              FilledButton.icon(
                key: const Key('notifiche-salva'),
                onPressed: widget.salvataggio ? null : widget.onSalva,
                icon: widget.salvataggio
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(widget.salvataggio ? 'Salvataggio…' : 'Salva'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card di una sezione con intestazione (icona + titolo).
class _SezioneCard extends StatelessWidget {
  const _SezioneCard({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.figli,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final List<Widget> figli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: chiave,
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icona, size: 20, color: tema.colorScheme.primary),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  child: Text(titolo, style: tema.textTheme.titleSmall),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.s),
            ...figli,
          ],
        ),
      ),
    );
  }
}

/// Campo orario `HH:MM` con icona che apre il selettore dell'ora.
class _CampoOrario extends StatelessWidget {
  const _CampoOrario({
    required this.campoKey,
    required this.etichetta,
    required this.controller,
    required this.onCambia,
    required this.onScegli,
  });

  final Key campoKey;
  final String etichetta;
  final TextEditingController controller;
  final ValueChanged<String> onCambia;
  final VoidCallback onScegli;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: campoKey,
      controller: controller,
      keyboardType: TextInputType.datetime,
      decoration: InputDecoration(
        labelText: etichetta,
        hintText: 'HH:MM',
        suffixIcon: IconButton(
          tooltip: 'Scegli orario',
          onPressed: onScegli,
          icon: const Icon(Icons.schedule),
        ),
      ),
      onChanged: onCambia,
    );
  }
}
