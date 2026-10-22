import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../state/auth_providers.dart';
import 'login_screen.dart' show validaEmail;

/// Validazione della nuova password (minimo 8 caratteri).
///
/// Funzione pura, verificabile senza Firebase né UI.
String? validaNuovaPassword(String? valore) {
  final password = valore ?? '';
  if (password.isEmpty) return 'Inserisci la nuova password';
  if (password.length < 8) {
    return 'La password deve avere almeno 8 caratteri';
  }
  return null;
}

/// Validazione della conferma password.
///
/// Funzione pura: controlla che il valore coincida con [password].
String? validaConfermaPassword(String? valore, String password) {
  if (valore == null || valore.isEmpty) {
    return 'Conferma la nuova password';
  }
  if (valore != password) return 'Le password non coincidono';
  return null;
}

/// Messaggio in italiano per gli errori di recupero password.
///
/// Distingue link scaduto o già usato, password debole, email sconosciuta e
/// problemi di rete.
String messaggioErroreReset(Object errore) {
  if (errore is FirebaseAuthException) {
    switch (errore.code) {
      case 'invalid-email':
        return 'L\'indirizzo email non è valido.';
      case 'user-not-found':
        return 'Non risulta un account con questa email.';
      case 'expired-action-code':
        return 'Il link è scaduto. Richiedi un nuovo link per reimpostare la password.';
      case 'invalid-action-code':
      case 'argument-error':
        return 'Il link non è valido o è già stato usato. Richiedi un nuovo link.';
      case 'weak-password':
        return 'La password è troppo debole. Usa almeno 8 caratteri.';
      case 'too-many-requests':
        return 'Troppi tentativi. Riprova tra qualche minuto.';
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      default:
        return 'Operazione non riuscita. Riprova.';
    }
  }
  return 'Operazione non riuscita. Controlla la connessione e riprova.';
}

/// Schermata di recupero password.
///
/// Senza `oobCode` mostra il form per ricevere il link via email; con
/// `oobCode` (parametro del link Firebase) mostra i campi per la nuova
/// password. `AuthService` viene risolto solo al submit o alla verifica del
/// codice, così il form email si può montare nei test senza Firebase.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.oobCode});

  /// Codice del link di recupero (`oobCode` della query string).
  final String? oobCode;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _modulo = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _conferma = TextEditingController();

  bool _inCorso = false;
  bool _passwordVisibile = false;
  bool _linkInviato = false;
  bool _passwordSalvata = false;
  bool _verificaCodice = false;
  bool _codiceNonValido = false;
  String? _errore;

  bool get _conCodice =>
      widget.oobCode != null && widget.oobCode!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_conCodice) _verificaLink();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _conferma.dispose();
    super.dispose();
  }

  Future<void> _verificaLink() async {
    setState(() => _verificaCodice = true);
    try {
      await ref.read(authServiceProvider).verifyResetCode(widget.oobCode!);
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _codiceNonValido = true;
        _errore = messaggioErroreReset(errore);
      });
    } finally {
      if (mounted) setState(() => _verificaCodice = false);
    }
  }

  Future<void> _inviaLink() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    setState(() => _inCorso = true);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_email.text);
      if (!mounted) return;
      setState(() => _linkInviato = true);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreReset(errore));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _salvaPassword() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    setState(() => _inCorso = true);
    try {
      await ref
          .read(authServiceProvider)
          .confirmPasswordReset(widget.oobCode!, _password.text);
      if (!mounted) return;
      setState(() => _passwordSalvata = true);
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreReset(errore));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recupero password'),
        leading: IconButton(
          tooltip: 'Torna al login',
          onPressed: () => context.go('/login'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpazi.m,
              vertical: AppSpazi.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpazi.l),
                  child: _contenuto(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenuto() {
    if (_conCodice) {
      if (_verificaCodice) return _caricamento('Verifica del link in corso…');
      if (_codiceNonValido) return _linkNonValido();
      if (_passwordSalvata) return _passwordAggiornata();
      return _formNuovaPassword();
    }
    if (_linkInviato) return _emailInviata();
    return _formEmail();
  }

  Widget _caricamento(String testo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: AppSpazi.m),
        Text(testo, textAlign: TextAlign.center),
      ],
    );
  }

  Widget _formEmail() {
    return Form(
      key: _modulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _intestazione(
            icona: Icons.lock_reset,
            titolo: 'Password dimenticata',
            sottotitolo:
                'Inserisci l\'email del tuo account: ti invieremo un link per '
                'reimpostare la password.',
          ),
          const SizedBox(height: AppSpazi.l),
          TextFormField(
            key: const Key('campo-email'),
            controller: _email,
            enabled: !_inCorso,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'nome@esempio.it',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: validaEmail,
            onFieldSubmitted: (_) {
              if (!_inCorso) _inviaLink();
            },
          ),
          if (_errore != null) ...[
            const SizedBox(height: AppSpazi.m),
            _MessaggioErrore(testo: _errore!),
          ],
          const SizedBox(height: AppSpazi.l),
          FilledButton(
            key: const Key('pulsante-invia-link'),
            onPressed: _inCorso ? null : _inviaLink,
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
                      Text('Invio in corso…'),
                    ],
                  )
                : const Text('Invia link'),
          ),
          const SizedBox(height: AppSpazi.xs),
          TextButton(
            onPressed: _inCorso ? null : () => context.go('/login'),
            child: const Text('Torna al login'),
          ),
        ],
      ),
    );
  }

  Widget _formNuovaPassword() {
    return Form(
      key: _modulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _intestazione(
            icona: Icons.lock_reset,
            titolo: 'Nuova password',
            sottotitolo: 'Scegli una password di almeno 8 caratteri.',
          ),
          const SizedBox(height: AppSpazi.l),
          _campoPassword(
            chiave: const Key('campo-nuova-password'),
            controller: _password,
            etichetta: 'Nuova password',
            validator: validaNuovaPassword,
          ),
          const SizedBox(height: AppSpazi.m),
          _campoPassword(
            chiave: const Key('campo-conferma-password'),
            controller: _conferma,
            etichetta: 'Conferma nuova password',
            validator: (valore) =>
                validaConfermaPassword(valore, _password.text),
            onSubmitted: (_) {
              if (!_inCorso) _salvaPassword();
            },
          ),
          if (_errore != null) ...[
            const SizedBox(height: AppSpazi.m),
            _MessaggioErrore(testo: _errore!),
          ],
          const SizedBox(height: AppSpazi.l),
          FilledButton(
            key: const Key('pulsante-salva-password'),
            onPressed: _inCorso ? null : _salvaPassword,
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
                      Text('Salvataggio in corso…'),
                    ],
                  )
                : const Text('Salva nuova password'),
          ),
          const SizedBox(height: AppSpazi.xs),
          TextButton(
            onPressed: _inCorso ? null : () => context.go('/login'),
            child: const Text('Torna al login'),
          ),
        ],
      ),
    );
  }

  Widget _campoPassword({
    required Key chiave,
    required TextEditingController controller,
    required String etichetta,
    required FormFieldValidator<String> validator,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      key: chiave,
      controller: controller,
      enabled: !_inCorso,
      obscureText: !_passwordVisibile,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      decoration: InputDecoration(
        labelText: etichetta,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _passwordVisibile ? 'Nascondi password' : 'Mostra password',
          onPressed: _inCorso
              ? null
              : () => setState(() => _passwordVisibile = !_passwordVisibile),
          icon: Icon(
            _passwordVisibile
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onSubmitted,
    );
  }

  Widget _emailInviata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intestazione(
          icona: Icons.mark_email_read_outlined,
          titolo: 'Controlla la posta',
          sottotitolo:
              'Ti abbiamo inviato un\'email con il link per reimpostare la '
              'password. Il link scade dopo un\'ora.',
        ),
        const SizedBox(height: AppSpazi.l),
        FilledButton(
          key: const Key('pulsante-torna-login'),
          onPressed: () => context.go('/login'),
          child: const Text('Torna al login'),
        ),
        const SizedBox(height: AppSpazi.xs),
        TextButton(
          onPressed: () => setState(() {
            _linkInviato = false;
            _errore = null;
          }),
          child: const Text('Invia di nuovo il link'),
        ),
      ],
    );
  }

  Widget _passwordAggiornata() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intestazione(
          icona: Icons.check_circle_outline,
          titolo: 'Password aggiornata',
          sottotitolo: 'Ora puoi accedere con la nuova password.',
        ),
        const SizedBox(height: AppSpazi.l),
        FilledButton(
          key: const Key('pulsante-torna-login'),
          onPressed: () => context.go('/login'),
          child: const Text('Torna al login'),
        ),
      ],
    );
  }

  Widget _linkNonValido() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _intestazione(
          icona: Icons.link_off,
          titolo: 'Link non valido',
          sottotitolo:
              _errore ??
              'Il link è scaduto o è già stato usato. Richiedi un nuovo link.',
        ),
        const SizedBox(height: AppSpazi.l),
        FilledButton(
          onPressed: () => context.go('/reset-password'),
          child: const Text('Richiedi un nuovo link'),
        ),
        const SizedBox(height: AppSpazi.xs),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Torna al login'),
        ),
      ],
    );
  }

  Widget _intestazione({
    required IconData icona,
    required String titolo,
    required String sottotitolo,
  }) {
    final tema = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tema.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRaggi.card),
          ),
          child: Icon(icona, color: tema.colorScheme.onPrimaryContainer),
        ),
        const SizedBox(height: AppSpazi.s),
        Text(
          titolo,
          style: tema.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpazi.xxs),
        Text(
          sottotitolo,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Errore in italiano, annunciato dai lettori di schermo.
class _MessaggioErrore extends StatelessWidget {
  const _MessaggioErrore({required this.testo});

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('messaggio-errore-reset'),
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
