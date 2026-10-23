import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../data/services/auth_service.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';
import 'nuovo_utente_screen.dart' show generaPasswordTemporanea;

// ---------------------------------------------------------------------------
// Funzioni pure: validazione e messaggi in italiano
// ---------------------------------------------------------------------------

/// Regex semplice per l'email: una chiocciola e almeno un punto nel dominio.
final RegExp _regexEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Validazione del nome o ragione sociale dell'azienda (obbligatorio).
String? validaNomeNuovaAzienda(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il nome o la ragione sociale';
  return null;
}

/// Validazione dell'email del primo amministratore (obbligatoria e valida).
String? validaEmailNuovaAzienda(String? valore) {
  final email = valore?.trim() ?? '';
  if (email.isEmpty) return 'Inserisci l\'email dell\'amministratore';
  if (!_regexEmail.hasMatch(email)) {
    return 'Inserisci un\'email valida (es. nome@azienda.it)';
  }
  return null;
}

/// Messaggio in italiano per gli errori di creazione di una nuova azienda.
String messaggioErroreNuovaAzienda(Object errore) {
  if (errore is ArgumentError) {
    final messaggio = errore.message?.toString().trim() ?? '';
    return messaggio.isEmpty
        ? 'Dati non validi. Controlla i campi e riprova.'
        : messaggio;
  }
  if (errore is EmailGiaRegistrataException) {
    return 'Esiste già un account con questa email.';
  }
  if (errore is StateError) {
    final messaggio = errore.message.trim();
    return messaggio.isEmpty
        ? 'Operazione non riuscita. Riprova.'
        : messaggio;
  }
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per creare aziende. '
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

/// Metodo con cui consegnare le credenziali al primo amministratore.
enum MetodoNuovaAzienda {
  /// Si crea l'account con una password casuale e si invia l'email di accesso.
  invito('Invita via email'),

  /// Il super admin comunica a voce la password temporanea.
  password('Password temporanea');

  const MetodoNuovaAzienda(this.etichetta);

  final String etichetta;
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Form di creazione di una nuova azienda con il suo primo amministratore.
///
/// Crea il documento `aziende`, collega il super admin corrente, esegue il seed
/// iniziale e crea (o riusa, se l'email è già registrata) l'account del primo
/// amministratore. Non cambia l'azienda attiva: ogni operazione usa l'id
/// appena creato. Chiude con `true` quando l'azienda è pronta.
class NuovaAziendaScreen extends ConsumerStatefulWidget {
  const NuovaAziendaScreen({super.key});

  @override
  ConsumerState<NuovaAziendaScreen> createState() => _NuovaAziendaScreenState();
}

class _NuovaAziendaScreenState extends ConsumerState<NuovaAziendaScreen> {
  final _modulo = GlobalKey<FormState>();

  final _nomeAzienda = TextEditingController();
  final _partitaIva = TextEditingController();
  final _codiceFiscale = TextEditingController();
  final _indirizzo = TextEditingController();
  final _comune = TextEditingController();
  final _provincia = TextEditingController();
  final _cap = TextEditingController();
  final _telefono = TextEditingController();
  final _emailAzienda = TextEditingController();
  final _pec = TextEditingController();

  final _nomeAdmin = TextEditingController();
  final _emailAdmin = TextEditingController();
  late final TextEditingController _password;

  MetodoNuovaAzienda _metodo = MetodoNuovaAzienda.invito;

  bool _salvando = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _password = TextEditingController(text: generaPasswordTemporanea());
  }

  @override
  void dispose() {
    _nomeAzienda.dispose();
    _partitaIva.dispose();
    _codiceFiscale.dispose();
    _indirizzo.dispose();
    _comune.dispose();
    _provincia.dispose();
    _cap.dispose();
    _telefono.dispose();
    _emailAzienda.dispose();
    _pec.dispose();
    _nomeAdmin.dispose();
    _emailAdmin.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Rigenera la password temporanea mostrata nel campo.
  void _rigeneraPassword() {
    setState(() => _password.text = generaPasswordTemporanea());
  }

  /// Valida, crea l'azienda e il primo amministratore.
  Future<void> _salva() async {
    final modulo = _modulo.currentState;
    if (modulo == null || !modulo.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _salvando = true;
      _errore = null;
    });

    final servizio = ref.read(spServiceProvider);
    final auth = ref.read(authServiceProvider);
    final emailAdmin = _emailAdmin.text.trim();

    var aziendaCreata = false;
    var faseAmministratore = false;

    try {
      final azienda = await servizio.creaAzienda({
        'nome': _nomeAzienda.text,
        'partita_iva': _partitaIva.text,
        'codice_fiscale': _codiceFiscale.text,
        'indirizzo': _indirizzo.text,
        'comune': _comune.text,
        'provincia': _provincia.text,
        'cap': _cap.text,
        'telefono': _telefono.text,
        'email': _emailAzienda.text,
        'pec': _pec.text,
      });

      final azId = azienda['id'];
      if (azId is! String || azId.isEmpty) {
        throw StateError(
          'Creazione azienda non riuscita: identificativo mancante.',
        );
      }
      aziendaCreata = true;

      final superUid = FirebaseAuth.instance.currentUser!.uid;
      await servizio.aggiungiMembro(azId, superUid, 'admin');
      await servizio.seedAzienda(azId);

      faseAmministratore = true;
      String uid;
      try {
        uid = await auth.creaAccountConProfilo(
          email: emailAdmin,
          password: _password.text,
          nome: _nomeAdmin.text,
          ruolo: 'admin',
        );
      } on EmailGiaRegistrataException {
        final esistente = await servizio.getUtentePerEmail(emailAdmin);
        if (esistente == null) {
          throw StateError(
            'Esiste già un account con questa email, ma non ha un profilo '
            'utente. Contatta l\'amministratore.',
          );
        }
        uid = esistente.uid;
      }

      await servizio.aggiungiMembro(azId, uid, 'admin');
      if (_metodo == MetodoNuovaAzienda.invito) {
        await auth.inviaEmailAccesso(emailAdmin);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (errore) {
      if (!mounted) return;
      final dettaglio = messaggioErroreNuovaAzienda(errore);
      final messaggio = !aziendaCreata
          ? dettaglio
          : faseAmministratore
              ? 'L\'azienda è stata creata, ma non è stato possibile creare '
                  'l\'amministratore. $dettaglio'
              : 'L\'azienda è stata creata, ma non è stato possibile '
                  'completare la configurazione. $dettaglio';
      setState(() => _errore = messaggio);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final passwordTemporanea = _metodo == MetodoNuovaAzienda.password;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuova azienda')),
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
                              'AZIENDA',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            _grigliaCampi([
                              _campo(
                                chiave: 'nuova-azienda-nome',
                                controller: _nomeAzienda,
                                etichetta: 'Nome o ragione sociale *',
                                suggerimento: 'Es. Rossi Srl',
                                capitalizza: true,
                                prossimo: TextInputAction.next,
                                validatore: validaNomeNuovaAzienda,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-piva',
                                controller: _partitaIva,
                                etichetta: 'Partita IVA',
                                suggerimento: '01234567890',
                                tipo: TextInputType.number,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-codice-fiscale',
                                controller: _codiceFiscale,
                                etichetta: 'Codice fiscale',
                                capitalizza: true,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-indirizzo',
                                controller: _indirizzo,
                                etichetta: 'Indirizzo',
                                suggerimento: 'Via Roma 1',
                                capitalizza: true,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-comune',
                                controller: _comune,
                                etichetta: 'Comune',
                                capitalizza: true,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-provincia',
                                controller: _provincia,
                                etichetta: 'Provincia',
                                suggerimento: 'MI',
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-cap',
                                controller: _cap,
                                etichetta: 'CAP',
                                tipo: TextInputType.number,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-telefono',
                                controller: _telefono,
                                etichetta: 'Telefono',
                                tipo: TextInputType.phone,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-email',
                                controller: _emailAzienda,
                                etichetta: 'Email',
                                suggerimento: 'info@azienda.it',
                                tipo: TextInputType.emailAddress,
                                prossimo: TextInputAction.next,
                              ),
                              _campo(
                                chiave: 'nuova-azienda-pec',
                                controller: _pec,
                                etichetta: 'PEC',
                                suggerimento: 'azienda@pec.it',
                                tipo: TextInputType.emailAddress,
                                prossimo: TextInputAction.next,
                              ),
                            ]),
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
                              'PRIMO AMMINISTRATORE',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            _campo(
                              chiave: 'nuova-azienda-admin-nome',
                              controller: _nomeAdmin,
                              etichetta: 'Nome e cognome',
                              suggerimento: 'Es. Mario Rossi',
                              capitalizza: true,
                              prossimo: TextInputAction.next,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextFormField(
                              key: const Key('nuova-azienda-admin-email'),
                              controller: _emailAdmin,
                              enabled: !_salvando,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email *',
                                hintText: 'nome@azienda.it',
                              ),
                              validator: validaEmailNuovaAzienda,
                            ),
                            const SizedBox(height: AppSpazi.s),
                            SegmentedButton<MetodoNuovaAzienda>(
                              key: const Key('nuova-azienda-metodo'),
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                  value: MetodoNuovaAzienda.invito,
                                  icon: Icon(Icons.mail_outline),
                                  label: Text('Invita via email'),
                                ),
                                ButtonSegment(
                                  value: MetodoNuovaAzienda.password,
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
                                key: const Key('nuova-azienda-password'),
                                controller: _password,
                                enabled: !_salvando,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                decoration: InputDecoration(
                                  labelText: 'Password temporanea',
                                  helperText:
                                      'Comunica questa password '
                                      'all\'amministratore: potrà cambiarla '
                                      'al primo accesso.',
                                  suffixIcon: IconButton(
                                    key: const Key(
                                      'nuova-azienda-rigenera',
                                    ),
                                    tooltip: 'Rigenera password',
                                    onPressed:
                                        _salvando ? null : _rigeneraPassword,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                ),
                                validator: validaPasswordTemporanea,
                              ),
                            ] else
                              Text(
                                'L\'amministratore riceverà un\'email per '
                                'scegliere la propria password.',
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
                        key: const Key('nuova-azienda-errore'),
                        testo: _errore!,
                      ),
                    ],
                    const SizedBox(height: AppSpazi.l),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            key: const Key('nuova-azienda-annulla'),
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(false),
                            child: const Text('Annulla'),
                          ),
                        ),
                        const SizedBox(width: AppSpazi.s),
                        Expanded(
                          child: FilledButton(
                            key: const Key('nuova-azienda-salva'),
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
                                : const Text('Crea azienda'),
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

  /// Campo di testo standard del form azienda.
  Widget _campo({
    required String chiave,
    required TextEditingController controller,
    required String etichetta,
    String? suggerimento,
    TextInputType? tipo,
    TextInputAction prossimo = TextInputAction.next,
    bool capitalizza = false,
    String? Function(String?)? validatore,
  }) {
    return TextFormField(
      key: Key(chiave),
      controller: controller,
      enabled: !_salvando,
      keyboardType: tipo,
      autocorrect: tipo != TextInputType.emailAddress,
      textCapitalization: capitalizza
          ? TextCapitalization.words
          : TextCapitalization.none,
      textInputAction: prossimo,
      decoration: InputDecoration(
        labelText: etichetta,
        hintText: suggerimento,
      ),
      validator: validatore,
    );
  }

  /// Dispone i campi su due colonne quando c'è spazio, altrimenti in colonna.
  Widget _grigliaCampi(List<Widget> campi) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: [
              for (var i = 0; i < campi.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpazi.s),
                campi[i],
              ],
            ],
          );
        }

        final righe = <Widget>[];
        for (var i = 0; i < campi.length; i += 2) {
          final secondo = i + 1 < campi.length ? campi[i + 1] : null;
          righe.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: campi[i]),
                const SizedBox(width: AppSpazi.s),
                Expanded(child: secondo ?? const SizedBox.shrink()),
              ],
            ),
          );
          if (i + 2 < campi.length) {
            righe.add(const SizedBox(height: AppSpazi.s));
          }
        }
        return Column(children: righe);
      },
    );
  }
}
