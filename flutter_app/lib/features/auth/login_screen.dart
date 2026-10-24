import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/google_icon.dart';
import '../../data/services/auth_service.dart';
import '../../state/auth_providers.dart';

/// Validazione dell'email per il form di accesso.
///
/// Funzione pura (nessuna dipendenza da Firebase o UI) così è verificabile
/// con un test normale.
String? validaEmail(String? valore) {
  final email = valore?.trim() ?? '';
  if (email.isEmpty) return 'Inserisci l\'email';
  final formato = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  if (!formato.hasMatch(email)) return 'Inserisci un indirizzo email valido';
  return null;
}

/// Validazione della password per il form di accesso.
///
/// Funzione pura: la password non viene mai salvata né modificata.
String? validaPassword(String? valore) {
  if (valore == null || valore.isEmpty) return 'Inserisci la password';
  return null;
}

/// Messaggio in italiano per gli errori di accesso.
///
/// Distingue credenziali errate, utente disabilitato e problemi di rete.
String messaggioErroreAccesso(Object errore) {
  if (errore is FirebaseAuthException) {
    switch (errore.code) {
      case 'invalid-email':
        return 'L\'indirizzo email non è valido.';
      case 'user-disabled':
        return 'Utente disabilitato. Contatta l\'amministratore.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Email o password non corretti.';
      case 'too-many-requests':
        return 'Troppi tentativi di accesso. Riprova tra qualche minuto.';
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'operation-not-allowed':
        return 'Accesso con email e password non disponibile.';
      default:
        return 'Accesso non riuscito. Riprova.';
    }
  }
  return 'Accesso non riuscito. Controlla la connessione e riprova.';
}

/// Messaggio in italiano per gli errori di registrazione.
String messaggioErroreRegistrazione(Object errore) {
  if (errore is FirebaseAuthException) {
    switch (errore.code) {
      case 'email-already-in-use':
        return 'Questa email è già registrata. Accedi con la password.';
      case 'invalid-email':
        return 'L\'indirizzo email non è valido.';
      case 'weak-password':
        return 'La password è troppo debole: usa almeno 6 caratteri.';
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'operation-not-allowed':
        return 'La registrazione è temporaneamente disattivata.';
      default:
        return 'Registrazione non riuscita. Riprova.';
    }
  }
  return 'Registrazione non riuscita. Controlla la connessione e riprova.';
}

/// Schermata di accesso con email e password.
///
/// Non legge provider Firebase durante il build: `AuthService` viene risolto
/// solo al submit, così il widget può essere montato nei test senza Firebase.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _modulo = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _passwordVisibile = false;
  bool _inCorso = false;
  bool _inCorsoGoogle = false;
  String? _errore;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _invia() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    setState(() => _inCorso = true);
    try {
      final servizio = ref.read(authServiceProvider);
      final credenziale = await servizio.signInWithEmail(
        _email.text,
        _password.text,
      );

      final profilo = await servizio.loadProfile(
        credenziale.user?.email ?? _email.text,
      );
      if (servizio.isDisabled(profilo)) {
        await servizio.signOut();
        if (!mounted) return;
        setState(() {
          _errore = 'Utente disabilitato. Contatta l\'amministratore.';
        });
        return;
      }

      if (!mounted) return;
      context.go('/');
    } on FirebaseAuthException catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreAccesso(errore));
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreAccesso(errore));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _accediConGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    setState(() => _inCorsoGoogle = true);
    try {
      final servizio = ref.read(authServiceProvider);
      await servizio.signInWithGoogle();
      if (!mounted) return;
      context.go('/');
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreGoogle(errore));
    } finally {
      if (mounted) setState(() => _inCorsoGoogle = false);
    }
  }

  /// Apre la registrazione email/password. Dopo la creazione dell'account
  /// `AuthGate` porta all'onboarding per creare l'azienda.
  Future<void> _apriRegistrazione() async {
    final creato = await showDialog<bool>(
      context: context,
      builder: (context) => const _DialogoRegistrazione(),
    );
    if (creato == true && mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpazi.m,
              vertical: AppSpazi.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Intestazione(tema: tema),
                  const SizedBox(height: AppSpazi.l),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpazi.l),
                      child: Form(
                        key: _modulo,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              key: const Key('campo-email'),
                              controller: _email,
                              enabled: !_inCorso,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              autocorrect: false,
                              enableSuggestions: false,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                hintText: 'nome@esempio.it',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: validaEmail,
                            ),
                            const SizedBox(height: AppSpazi.m),
                            TextFormField(
                              key: const Key('campo-password'),
                              controller: _password,
                              enabled: !_inCorso,
                              obscureText: !_passwordVisibile,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _passwordVisibile
                                      ? 'Nascondi password'
                                      : 'Mostra password',
                                  onPressed: _inCorso
                                      ? null
                                      : () => setState(
                                            () => _passwordVisibile =
                                                !_passwordVisibile,
                                          ),
                                  icon: Icon(
                                    _passwordVisibile
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                              validator: validaPassword,
                              onFieldSubmitted: (_) {
                                if (!_inCorso) _invia();
                              },
                            ),
                            if (_errore != null) ...[
                              const SizedBox(height: AppSpazi.m),
                              _MessaggioErrore(testo: _errore!),
                            ],
                            const SizedBox(height: AppSpazi.l),
                            FilledButton(
                              key: const Key('pulsante-accedi'),
                              onPressed: _inCorso ? null : _invia,
                              child: _inCorso
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
                                        Text('Accesso in corso…'),
                                      ],
                                    )
                                  : const Text('Accedi'),
                            ),
                            const SizedBox(height: AppSpazi.xs),
                            TextButton(
                              onPressed: _inCorso
                                  ? null
                                  : () => context.go('/reset-password'),
                              child: const Text('Password dimenticata?'),
                            ),
                            const SizedBox(height: AppSpazi.m),
                            Row(
                              children: const [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: AppSpazi.s,
                                  ),
                                  child: Text('oppure'),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: AppSpazi.m),
                            OutlinedButton(
                              key: const Key('pulsante-google'),
                              onPressed: (_inCorso || _inCorsoGoogle)
                                  ? null
                                  : _accediConGoogle,
                              child: _inCorsoGoogle
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GoogleIcon(size: 18),
                                        SizedBox(width: AppSpazi.s),
                                        Text('Accedi con Google'),
                                      ],
                                    ),
                            ),
                            const SizedBox(height: AppSpazi.l),
                            Text(
                              'Non hai un account?',
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            TextButton(
                              key: const Key('registrati-azienda'),
                              onPressed: (_inCorso || _inCorsoGoogle)
                                  ? null
                                  : _apriRegistrazione,
                              child: const Text('Registra la tua azienda'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Intestazione con logo e sottotitolo, fuori dalla card.
class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.tema});

  final ThemeData tema;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRaggi.card),
          child: Image.asset(
            'assets/icon/closer_icon.png',
            width: 64,
            height: 64,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: AppSpazi.s),
        Text(
          'Closer',
          style: tema.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpazi.xxs),
        Text(
          'Accedi alla piattaforma',
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Errore di accesso in italiano, annunciato dai lettori di schermo.
class _MessaggioErrore extends StatelessWidget {
  const _MessaggioErrore({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('messaggio-errore'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpazi.s,
          vertical: AppSpazi.xs,
        ),
        decoration: BoxDecoration(
          color: tema.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRaggi.chip),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 18,
              color: tema.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: AppSpazi.xs),
            Expanded(
              child: Text(
                testo,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialogo di registrazione email/password per un nuovo titolare.
///
/// Crea solo l'account Auth: dopo il login `AuthGate` mostra l'onboarding per
/// creare profilo, azienda, membership e seed.
class _DialogoRegistrazione extends ConsumerStatefulWidget {
  const _DialogoRegistrazione();

  @override
  ConsumerState<_DialogoRegistrazione> createState() =>
      _DialogoRegistrazioneState();
}

class _DialogoRegistrazioneState extends ConsumerState<_DialogoRegistrazione> {
  final _modulo = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _conferma = TextEditingController();
  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _conferma.dispose();
    super.dispose();
  }

  Future<void> _registra() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;
    setState(() => _inCorso = true);
    try {
      await ref
          .read(authServiceProvider)
          .registraConEmail(_email.text, _password.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreRegistrazione(errore));
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreRegistrazione(errore));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('dialogo-registrazione'),
      title: const Text('Registra la tua azienda'),
      content: SingleChildScrollView(
        child: Form(
          key: _modulo,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const Key('registrazione-email'),
                controller: _email,
                enabled: !_inCorso,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: validaEmail,
              ),
              const SizedBox(height: AppSpazi.s),
              TextFormField(
                key: const Key('registrazione-password'),
                controller: _password,
                enabled: !_inCorso,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'Almeno 6 caratteri',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (valore) {
                  final testo = valore ?? '';
                  if (testo.length < 6) {
                    return 'La password deve avere almeno 6 caratteri';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpazi.s),
              TextFormField(
                key: const Key('registrazione-conferma'),
                controller: _conferma,
                enabled: !_inCorso,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Conferma password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (valore) => valore == _password.text
                    ? null
                    : 'Le password non coincidono',
              ),
              if (_errore != null) ...[
                const SizedBox(height: AppSpazi.s),
                Text(
                  _errore!,
                  key: const Key('registrazione-errore'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('registrazione-annulla'),
          onPressed: _inCorso ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annulla'),
        ),
        FilledButton(
          key: const Key('registrazione-conferma-pulsante'),
          onPressed: _inCorso ? null : _registra,
          child: _inCorso
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crea account'),
        ),
      ],
    );
  }
}
