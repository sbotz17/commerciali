import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

/// Validazione del nome della persona che crea l'azienda.
///
/// Funzione pura (nessuna dipendenza da Firebase o UI) così è verificabile con
/// un test normale.
String? validaNomeUtente(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il tuo nome';
  if (nome.length < 2) return 'Il nome deve avere almeno 2 caratteri';
  return null;
}

/// Validazione del nome dell'azienda.
///
/// Funzione pura, riusabile da form futuri (impostazioni azienda).
String? validaNomeAzienda(String? valore) {
  final nome = valore?.trim() ?? '';
  if (nome.isEmpty) return 'Inserisci il nome dell\'azienda';
  if (nome.length < 2) {
    return 'Il nome dell\'azienda deve avere almeno 2 caratteri';
  }
  return null;
}

/// Messaggio in italiano per gli errori di creazione dell'azienda.
///
/// Distingue permessi mancanti, rete assente e caso generico.
String messaggioErroreOnboarding(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per creare l\'azienda. Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Creazione non riuscita. Riprova.';
    }
  }
  return 'Creazione non riuscita. Controlla la connessione e riprova.';
}

/// Primo avvio: crea il profilo, l'azienda, la membership admin e il seed.
///
/// Non legge provider Firebase durante il build: `SpService` e `FirebaseAuth`
/// vengono risolti solo al submit, così il widget può essere montato nei test
/// senza Firebase. Il redirect di autenticazione arriva con F07c.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _modulo = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _azienda = TextEditingController();

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _nome.dispose();
    _azienda.dispose();
    super.dispose();
  }

  Future<void> _creaAzienda() async {
    FocusScope.of(context).unfocus();
    setState(() => _errore = null);
    if (!(_modulo.currentState?.validate() ?? false)) return;

    final email = ref.read(firebaseAuthProvider).currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      setState(() {
        _errore = 'Sessione non valida: accedi di nuovo e riprova.';
      });
      return;
    }

    setState(() => _inCorso = true);
    try {
      final servizio = ref.read(spServiceProvider);
      final profilo = await servizio.assicuraProfilo(email, _nome.text);
      if (profilo == null) {
        if (!mounted) return;
        setState(() {
          _errore = 'Profilo non disponibile: accedi di nuovo e riprova.';
        });
        return;
      }

      final azienda = await servizio.creaAzienda({'nome': _azienda.text});
      final aziendaId = (azienda['id'] as String?) ?? '';
      if (aziendaId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _errore = 'Azienda non creata. Riprova.';
        });
        return;
      }

      await servizio.aggiungiMembro(aziendaId, profilo.id, 'admin');
      await servizio.seedAzienda(aziendaId);

      ref.read(aziendaAttivaProvider.notifier).state = aziendaId;
      // Il profilo è stato creato adesso: senza invalidarlo il `profileProvider`
      // resta `null` in cache e `AuthGate` rimanderebbe all'onboarding.
      ref.invalidate(profileProvider);
      ref.invalidate(aziendeUtenteProvider);

      if (!mounted) return;
      context.go('/');
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErroreOnboarding(errore));
    } finally {
      if (mounted) setState(() => _inCorso = false);
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
              constraints: const BoxConstraints(maxWidth: 480),
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
                              key: const Key('campo-nome'),
                              controller: _nome,
                              enabled: !_inCorso,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Il tuo nome',
                                hintText: 'Mario Rossi',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: validaNomeUtente,
                            ),
                            const SizedBox(height: AppSpazi.m),
                            TextFormField(
                              key: const Key('campo-azienda'),
                              controller: _azienda,
                              enabled: !_inCorso,
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Nome azienda',
                                hintText: 'La mia azienda',
                                prefixIcon: Icon(Icons.business_outlined),
                              ),
                              validator: validaNomeAzienda,
                              onFieldSubmitted: (_) {
                                if (!_inCorso) _creaAzienda();
                              },
                            ),
                            if (_errore != null) ...[
                              const SizedBox(height: AppSpazi.m),
                              AvvisoErrore(
                                key: const Key('messaggio-errore-onboarding'),
                                testo: _errore!,
                              ),
                            ],
                            const SizedBox(height: AppSpazi.l),
                            FilledButton(
                              key: const Key('pulsante-crea-azienda'),
                              onPressed: _inCorso ? null : _creaAzienda,
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
                                        Text('Creazione in corso…'),
                                      ],
                                    )
                                  : const Text('Crea azienda e inizia'),
                            ),
                            const SizedBox(height: AppSpazi.m),
                            Text(
                              'Il profilo usa l\'email con cui hai effettuato l\'accesso.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
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
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.primario,
            borderRadius: BorderRadius.circular(AppRaggi.card),
          ),
          child: const Icon(
            Icons.business_outlined,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: AppSpazi.s),
        Text(
          'Configura la tua azienda',
          style: tema.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpazi.xxs),
        Text(
          'Crea l\'azienda per iniziare a usare Commerciali',
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
