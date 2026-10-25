// Configurazione del servizio email di piattaforma.
//
// La schermata è riservata al super admin: salva mittente e API key in un KV
// del Worker, che è l'unico a parlare con il provider. La chiave non viene
// mai scritta su Firestore né mostrata nei log.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

/// Schermata Super Admin → Server email.
class EmailServerScreen extends ConsumerStatefulWidget {
  const EmailServerScreen({super.key});

  @override
  ConsumerState<EmailServerScreen> createState() => _EmailServerScreenState();
}

class _EmailServerScreenState extends ConsumerState<EmailServerScreen> {
  final _from = TextEditingController();
  final _nome = TextEditingController();
  final _apiKey = TextEditingController();
  final _provaA = TextEditingController();

  bool _caricamento = true;
  bool _salvataggio = false;
  bool _prova = false;
  bool _mostraApiKey = false;
  bool _configurata = false;
  String? _errore;
  String? _messaggio;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _from.dispose();
    _nome.dispose();
    _apiKey.dispose();
    _provaA.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final servizio = ref.read(spServiceProvider);
      final config = await servizio.getEmailConfig();
      if (!mounted) return;
      final emailProfilo =
          ref.read(profileProvider).asData?.value?.email?.trim() ?? '';
      setState(() {
        _from.text = (config?['from'] ?? '').toString();
        _nome.text = (config?['nome'] ?? '').toString();
        _apiKey.text = (config?['apiKey'] ?? '').toString();
        _provaA.text = emailProfilo;
        _configurata = _from.text.trim().isNotEmpty && _apiKey.text.isNotEmpty;
        _caricamento = false;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = _messaggioErrore(errore);
        _caricamento = false;
      });
    }
  }

  String _messaggioErrore(Object errore) {
    final testo = errore.toString().toLowerCase();
    if (testo.contains('riservato') || testo.contains('super admin')) {
      return 'Questa configurazione è riservata al super admin.';
    }
    if (testo.contains('unavailable') || testo.contains('network')) {
      return 'Connessione assente. Controlla la rete e riprova.';
    }
    if (errore is StateError && errore.message.trim().isNotEmpty) {
      return errore.message.trim();
    }
    return 'Operazione non riuscita. Riprova.';
  }

  Future<bool> _salva({bool silenzioso = false}) async {
    setState(() {
      _salvataggio = true;
      _errore = null;
      _messaggio = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      await servizio.salvaEmailConfig(
        from: _from.text,
        nome: _nome.text,
        apiKey: _apiKey.text,
      );
      if (!mounted) return false;
      setState(() {
        _salvataggio = false;
        _configurata = true;
        if (!silenzioso) _messaggio = 'Configurazione email salvata.';
      });
      return true;
    } catch (errore) {
      if (!mounted) return false;
      setState(() {
        _salvataggio = false;
        _errore = _messaggioErrore(errore);
      });
      return false;
    }
  }

  Future<void> _inviaProva() async {
    if (!await _salva(silenzioso: true)) return;
    setState(() {
      _prova = true;
      _errore = null;
      _messaggio = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      await servizio.inviaEmailProva(_provaA.text);
      if (!mounted) return;
      setState(() {
        _prova = false;
        _messaggio = 'Email di prova inviata a ${_provaA.text.trim()}.';
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _prova = false;
        _errore = _messaggioErrore(errore);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilo = ref.watch(profileProvider);
    if (profilo.isLoading) {
      return const Center(
        key: Key('email-config-caricamento-profilo'),
        child: CircularProgressIndicator(),
      );
    }
    if (profilo.asData?.value?.superAdmin != true) {
      return const StatoCentrato(
        key: Key('email-config-riservato'),
        icona: Icons.lock_outline,
        titolo: 'Accesso riservato',
        sottotitolo:
            'Questa configurazione è visibile solo al super admin '
            'della piattaforma.',
      );
    }

    final tema = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final orizzontale = constraints.maxWidth >= AppBreakpoints.telefono
            ? AppSpazi.paginaDesktop
            : AppSpazi.paginaTelefono;
        return SingleChildScrollView(
          key: const Key('email-config-screen'),
          padding: EdgeInsets.all(orizzontale),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const Key('email-config-indietro'),
                        tooltip: 'Torna al pannello',
                        onPressed: () => context.go('/superadmin'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: AppSpazi.xs),
                      Expanded(
                        child: Text(
                          'Server email',
                          style: tema.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpazi.s),
                  Text(
                    'Le email ai clienti partono da questo indirizzo. '
                    'Serve un account Resend con il dominio verificato: la '
                    'API key resta nel Worker e non viene salvata in Firestore.',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpazi.m),
                  if (_errore != null) ...[
                    AvvisoErrore(
                      key: const Key('email-config-errore'),
                      testo: _errore!,
                    ),
                    const SizedBox(height: AppSpazi.s),
                  ],
                  if (_messaggio != null) ...[
                    Card(
                      key: const Key('email-config-messaggio'),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.m),
                        child: Text(_messaggio!),
                      ),
                    ),
                    const SizedBox(height: AppSpazi.s),
                  ],
                  if (_configurata)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        key: const Key('email-config-stato'),
                        avatar: const Icon(
                          Icons.check_circle_outline,
                          size: 18,
                        ),
                        label: const Text('Email configurata'),
                      ),
                    ),
                  const SizedBox(height: AppSpazi.s),
                  if (_caricamento)
                    const Center(
                      key: Key('email-config-caricamento'),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpazi.l),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    TextField(
                      key: const Key('email-config-from'),
                      controller: _from,
                      enabled: !_salvataggio && !_prova,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email mittente',
                        hintText: 'noreply@tuodominio.it',
                        helperText:
                            'Deve essere un dominio verificato su Resend.',
                      ),
                    ),
                    const SizedBox(height: AppSpazi.s),
                    TextField(
                      key: const Key('email-config-nome'),
                      controller: _nome,
                      enabled: !_salvataggio && !_prova,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome mittente',
                        hintText: 'Closer',
                      ),
                    ),
                    const SizedBox(height: AppSpazi.s),
                    TextField(
                      key: const Key('email-config-api-key'),
                      controller: _apiKey,
                      enabled: !_salvataggio && !_prova,
                      obscureText: !_mostraApiKey,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API key Resend',
                        hintText: 're_...',
                        suffixIcon: IconButton(
                          key: const Key('email-config-mostra-key'),
                          tooltip: _mostraApiKey
                              ? 'Nascondi API key'
                              : 'Mostra API key',
                          onPressed: () =>
                              setState(() => _mostraApiKey = !_mostraApiKey),
                          icon: Icon(
                            _mostraApiKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('email-config-salva'),
                            onPressed: _salvataggio || _prova ? null : _salva,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Salva'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpazi.l),
                    Text('Prova di invio', style: tema.textTheme.titleSmall),
                    const SizedBox(height: AppSpazi.s),
                    TextField(
                      key: const Key('email-config-prova-a'),
                      controller: _provaA,
                      enabled: !_salvataggio && !_prova,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Invia la prova a',
                        hintText: 'tua@email.it',
                      ),
                    ),
                    const SizedBox(height: AppSpazi.s),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('email-config-prova'),
                        onPressed: _salvataggio || _prova ? null : _inviaProva,
                        icon: _prova
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text('Invia email di prova'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
