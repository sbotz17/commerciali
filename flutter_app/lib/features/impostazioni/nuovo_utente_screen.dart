import 'dart:math';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/models/ruolo.dart';
import '../../data/services/auth_service.dart'
    show EmailGiaRegistrataException;
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import 'utenti_screen.dart' show chiaviRuoloSelezionabili, etichettaRuolo;

// ---------------------------------------------------------------------------
// Funzioni pure: password, validazione e messaggi in italiano
// ---------------------------------------------------------------------------

/// Caratteri usati per generare la password temporanea (alfanumerici ASCII).
const String _caratteriPassword =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Genera una password temporanea di 12 caratteri alfanumerici.
///
/// [random] serve ai test per ottenere un risultato ripetibile; in produzione
/// si usa un generatore sicuro. La password va comunicata all'utente, che può
/// cambiarla al primo accesso.
String generaPasswordTemporanea({Random? random}) {
  final generatore = random ?? Random.secure();
  return String.fromCharCodes(
    List<int>.generate(
      12,
      (_) => _caratteriPassword.codeUnitAt(
        generatore.nextInt(_caratteriPassword.length),
      ),
    ),
  );
}

/// Validazione del nome dell'utente (obbligatorio).
String? validaNomeNuovoUtente(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci nome e cognome';
  return null;
}

/// Regex semplice per l'email: una chiocciola e almeno un punto nel dominio.
final RegExp _regexEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Validazione dell'email dell'utente (obbligatoria e in forma plausibile).
String? validaEmailNuovoUtente(String? valore) {
  final email = valore?.trim() ?? '';
  if (email.isEmpty) return 'Inserisci l\'email';
  if (!_regexEmail.hasMatch(email)) {
    return 'Inserisci un\'email valida (es. nome@azienda.it)';
  }
  return null;
}

/// Validazione della password temporanea: almeno 8 caratteri.
String? validaPasswordNuovoUtente(String? valore) {
  final password = valore ?? '';
  if (password.isEmpty) return 'Inserisci la password temporanea';
  if (password.length < 8) {
    return 'La password deve avere almeno 8 caratteri';
  }
  return null;
}

/// Voce della tendina ruolo: chiave salvata sulla membership ed etichetta.
class VoceRuolo {
  const VoceRuolo({required this.chiave, required this.etichetta});

  final String chiave;
  final String etichetta;
}

/// Ruoli selezionabili per il nuovo utente.
///
/// Usa i ruoli configurati dall'azienda; se non ce ne sono ripiega sui due
/// ruoli di sistema `admin` e `commerciale`, così il form resta utilizzabile
/// anche prima del seed.
List<VoceRuolo> ruoliNuovoUtente(List<Ruolo> ruoli) {
  final chiavi = chiaviRuoloSelezionabili(ruoli);
  final effettive = chiavi.isEmpty ? const ['admin', 'commerciale'] : chiavi;
  return [
    for (final chiave in effettive)
      VoceRuolo(chiave: chiave, etichetta: etichettaRuolo(chiave, ruoli)),
  ];
}

/// Metodo con cui consegnare le credenziali al nuovo utente.
enum MetodoCreazione {
  /// Si crea l'account con una password casuale e si invia l'email di accesso.
  invito('Invita via email'),

  /// L'amministratore comunica a voce la password temporanea.
  password('Password temporanea');

  const MetodoCreazione(this.etichetta);

  final String etichetta;
}

/// Messaggio in italiano per gli errori di creazione del nuovo utente.
String messaggioErroreNuovoUtente(Object errore) {
  if (errore is ArgumentError) {
    final messaggio = errore.message?.toString().trim() ?? '';
    return messaggio.isEmpty
        ? 'Dati non validi. Controlla i campi e riprova.'
        : messaggio;
  }
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per creare utenti. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      case 'invalid-email':
        return 'L\'email non è valida. Controllala e riprova.';
      case 'weak-password':
        return 'La password è troppo debole: usa almeno 8 caratteri.';
      case 'email-already-in-use':
        return 'Esiste già un account con questa email.';
      default:
        return 'Creazione non riuscita. Riprova.';
    }
  }
  return 'Creazione non riuscita. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Form di creazione di un nuovo utente dell'azienda attiva.
///
/// Crea l'account (Auth + profilo), lo collega all'azienda attiva con il ruolo
/// scelto e, se richiesto, invia l'email di accesso. Chiude con `true` quando
/// l'utente è stato creato, così l'elenco si ricarica.
class NuovoUtenteScreen extends ConsumerStatefulWidget {
  const NuovoUtenteScreen({super.key, required this.ruoli});

  /// Ruoli configurati per l'azienda attiva (può essere vuoto).
  final List<Ruolo> ruoli;

  @override
  ConsumerState<NuovoUtenteScreen> createState() => _NuovoUtenteScreenState();
}

class _NuovoUtenteScreenState extends ConsumerState<NuovoUtenteScreen> {
  final _modulo = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  late final TextEditingController _password;

  late final List<VoceRuolo> _vociRuolo;
  late String _ruolo;
  MetodoCreazione _metodo = MetodoCreazione.invito;

  bool _salvando = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _vociRuolo = ruoliNuovoUtente(widget.ruoli);
    _ruolo = _vociRuolo.first.chiave;
    _password = TextEditingController(text: generaPasswordTemporanea());
  }

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Rigenera la password temporanea mostrata nel campo.
  void _rigeneraPassword() {
    setState(() => _password.text = generaPasswordTemporanea());
  }

  /// Valida, crea l'account e lo collega all'azienda attiva.
  Future<void> _salva() async {
    final modulo = _modulo.currentState;
    if (modulo == null || !modulo.validate()) return;

    final aziendaId = ref.read(aziendaAttivaProvider)?.trim() ?? '';
    if (aziendaId.isEmpty) {
      setState(
        () => _errore = 'Nessuna azienda attiva. '
            'Seleziona un\'azienda e riprova.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _errore = null;
    });

    final auth = ref.read(authServiceProvider);
    final servizio = ref.read(spServiceProvider);
    servizio.setAziendaAttiva(aziendaId);
    final email = _email.text.trim();

    try {
      String? uid;
      try {
        uid = await auth.creaAccountConProfilo(
          email: email,
          password: _password.text,
          nome: _nome.text,
          ruolo: _ruolo,
        );
      } on EmailGiaRegistrataException {
        final esistente = await servizio.getUtentePerEmail(email);
        if (esistente == null) {
          if (!mounted) return;
          setState(
            () => _errore = 'Esiste già un account con questa email, '
                'ma non ha un profilo utente. Contatta l\'amministratore.',
          );
          return;
        }
        uid = esistente.uid;
      }

      await servizio.aggiungiMembro(aziendaId, uid, _ruolo);
      if (_metodo == MetodoCreazione.invito) {
        await auth.inviaEmailAccesso(email);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreNuovoUtente(errore));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final passwordTemporanea = _metodo == MetodoCreazione.password;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo utente')),
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
                              'DETTAGLI',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('nuovo-utente-nome'),
                              controller: _nome,
                              enabled: !_salvando,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Nome e cognome *',
                                hintText: 'Es. Mario Rossi',
                              ),
                              validator: validaNomeNuovoUtente,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('nuovo-utente-email'),
                              controller: _email,
                              enabled: !_salvando,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email *',
                                hintText: 'nome@azienda.it',
                              ),
                              validator: validaEmailNuovoUtente,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            DropdownButtonFormField<String>(
                              key: const Key('nuovo-utente-ruolo'),
                              initialValue: _ruolo,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Ruolo',
                              ),
                              items: [
                                for (final voce in _vociRuolo)
                                  DropdownMenuItem(
                                    value: voce.chiave,
                                    child: Text(
                                      voce.etichetta,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: _salvando
                                  ? null
                                  : (chiave) {
                                      if (chiave == null) return;
                                      setState(() => _ruolo = chiave);
                                    },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Come consegnare le credenziali',
                              style: tema.textTheme.titleSmall,
                            ),
                            const SizedBox(height: AppSpazi.xs),
                            SegmentedButton<MetodoCreazione>(
                              key: const Key('nuovo-utente-metodo'),
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: MetodoCreazione.invito,
                                  icon: Icon(Icons.mail_outline),
                                  label: Text('Invita via email'),
                                ),
                                ButtonSegment(
                                  value: MetodoCreazione.password,
                                  icon: Icon(Icons.key_outlined),
                                  label: Text('Password temporanea'),
                                ),
                              ],
                              selected: {_metodo},
                              onSelectionChanged: _salvando
                                  ? null
                                  : (selezione) => setState(
                                      () => _metodo = selezione.first,
                                    ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            if (passwordTemporanea) ...[
                              TextFormField(
                                key: const Key('nuovo-utente-password'),
                                controller: _password,
                                enabled: !_salvando,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Password temporanea',
                                  helperText:
                                      'Comunica questa password all\'utente: '
                                      'potrà cambiarla al primo accesso.',
                                  suffixIcon: IconButton(
                                    key: const Key('nuovo-utente-rigenera'),
                                    tooltip: 'Rigenera password',
                                    onPressed:
                                        _salvando ? null : _rigeneraPassword,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ),
                                validator: validaPasswordNuovoUtente,
                              ),
                            ] else
                              Text(
                                'L\'utente riceverà un\'email per scegliere '
                                'la propria password.',
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_errore != null) ...[
                      const SizedBox(height: AppSpazi.m),
                      AvvisoErrore(
                        key: const Key('nuovo-utente-errore'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('nuovo-utente-annulla'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('nuovo-utente-salva'),
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
                                      Text('Creazione…'),
                                    ],
                                  )
                                : const Text('Crea utente'),
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
                    ),
                    const SizedBox(height: AppSpazi.l),
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
