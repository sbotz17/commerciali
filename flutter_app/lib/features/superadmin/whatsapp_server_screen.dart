// Configurazione del server WhatsApp di piattaforma.
//
// Schermata riservata al super admin: salva URL e API key in
// `whatsapp_config/1` e permette di verificare la connessione e mostrare il
// QR di pairing del server. La chiave non viene mai mostrata nei log.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/services/sp_service.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

/// Schermata Super Admin → Server WhatsApp.
class WhatsappServerScreen extends ConsumerStatefulWidget {
  const WhatsappServerScreen({super.key});

  @override
  ConsumerState<WhatsappServerScreen> createState() =>
      _WhatsappServerScreenState();
}

class _WhatsappServerScreenState extends ConsumerState<WhatsappServerScreen> {
  final _url = TextEditingController();
  final _apiKey = TextEditingController();

  bool _caricamento = true;
  bool _salvataggio = false;
  bool _verifica = false;
  bool _mostraApiKey = false;
  bool? _connesso;
  String? _numero;
  String? _qr;
  String? _errore;
  String? _messaggio;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _url.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final servizio = ref.read(spServiceProvider);
      final config = await servizio.getWhatsappConfig();
      if (!mounted) return;
      setState(() {
        _url.text = (config?['url'] ?? '').toString();
        _apiKey.text = (config?['api_key'] ?? '').toString();
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
    if (errore is StateError) {
      final testo = errore.message.trim();
      if (testo.isNotEmpty) return testo;
    }
    final testo = errore.toString().toLowerCase();
    if (testo.contains('permission-denied')) {
      return 'Non hai i permessi per configurare WhatsApp.';
    }
    if (testo.contains('unavailable') || testo.contains('network')) {
      return 'Connessione assente. Controlla la rete e riprova.';
    }
    return 'Operazione non riuscita. Riprova.';
  }

  /// Salva la configurazione. Se [silenzioso] non mostra il messaggio di
  /// conferma (usato prima della verifica).
  Future<bool> _salva({bool silenzioso = false}) async {
    final url = _url.text.trim();
    final chiave = _apiKey.text.trim();
    if (uriInvioWhatsapp(url) == null) {
      setState(() => _errore = 'Inserisci un indirizzo http/https valido.');
      return false;
    }
    if (chiave.isEmpty) {
      setState(() => _errore = 'Inserisci la API key del server WhatsApp.');
      return false;
    }

    setState(() {
      _salvataggio = true;
      _errore = null;
      _messaggio = null;
      _qr = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      await servizio.salvaWhatsappConfig(url: url, apiKey: chiave);
      if (!mounted) return false;
      setState(() {
        _salvataggio = false;
        if (!silenzioso) _messaggio = 'Configurazione salvata.';
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

  Future<void> _verificaConnessione() async {
    if (!await _salva(silenzioso: true)) return;
    if (!mounted) return;
    setState(() {
      _verifica = true;
      _errore = null;
      _messaggio = null;
      _qr = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      final stato = await servizio.statoWhatsapp();
      if (!mounted) return;
      setState(() {
        _verifica = false;
        _connesso = stato['connected'] == true;
        _numero = stato['number']?.toString();
        _messaggio = _connesso == true
            ? 'Server connesso.'
            : 'Server raggiungibile ma non connesso a WhatsApp.';
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _verifica = false;
        _errore = _messaggioErrore(errore);
      });
    }
  }

  Future<void> _mostraQr() async {
    if (!await _salva(silenzioso: true)) return;
    if (!mounted) return;
    setState(() {
      _verifica = true;
      _errore = null;
      _messaggio = null;
      _qr = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      final qr = await servizio.qrWhatsapp();
      if (!mounted) return;
      setState(() {
        _verifica = false;
        _qr = qr;
        _messaggio = qr == null
            ? 'Il server è già connesso oppure non ha restituito un QR.'
            : 'Scansiona il QR da WhatsApp → Dispositivi collegati.';
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _verifica = false;
        _errore = _messaggioErrore(errore);
      });
    }
  }

  Widget _qrImage(String qr) {
    try {
      if (qr.startsWith('data:')) {
        return Image.memory(
          UriData.parse(qr).contentAsBytes(),
          width: 220,
          height: 220,
        );
      }
      if (qr.startsWith('http')) {
        return Image.network(qr, width: 220, height: 220);
      }
      return Image.memory(base64Decode(qr), width: 220, height: 220);
    } catch (_) {
      return const Text('QR non leggibile. Riprova dal server WhatsApp.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilo = ref.watch(profileProvider);
    if (profilo.isLoading) {
      return const Center(
        key: Key('whatsapp-config-caricamento-profilo'),
        child: CircularProgressIndicator(),
      );
    }
    if (profilo.asData?.value?.superAdmin != true) {
      return const StatoCentrato(
        key: Key('whatsapp-config-riservato'),
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
          key: const Key('whatsapp-config-screen'),
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
                        key: const Key('whatsapp-config-indietro'),
                        tooltip: 'Torna al pannello',
                        onPressed: () => context.go('/superadmin'),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: AppSpazi.xs),
                      Expanded(
                        child: Text(
                          'Server WhatsApp',
                          style: tema.textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpazi.s),
                  if (_caricamento)
                    const Padding(
                      padding: EdgeInsets.all(AppSpazi.l),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.internoCard),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'CONFIGURAZIONE',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            Text(
                              'Il server WhatsApp è unico per tutta la '
                              'piattaforma. URL e API key vengono salvati in '
                              'Firebase e usati solo per parlare con il tuo '
                              'server.',
                              style: tema.textTheme.bodySmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.m),
                            TextField(
                              key: const Key('whatsapp-config-url'),
                              controller: _url,
                              enabled: !_salvataggio && !_verifica,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'URL del server',
                                hintText: 'https://wa.tuodominio.it',
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            TextField(
                              key: const Key('whatsapp-config-api-key'),
                              controller: _apiKey,
                              enabled: !_salvataggio && !_verifica,
                              obscureText: !_mostraApiKey,
                              decoration: InputDecoration(
                                labelText: 'API key',
                                suffixIcon: IconButton(
                                  key: const Key(
                                    'whatsapp-config-mostra-api-key',
                                  ),
                                  tooltip: _mostraApiKey
                                      ? 'Nascondi API key'
                                      : 'Mostra API key',
                                  onPressed: () => setState(
                                    () => _mostraApiKey = !_mostraApiKey,
                                  ),
                                  icon: Icon(
                                    _mostraApiKey
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpazi.m),
                            Wrap(
                              spacing: AppSpazi.xs,
                              runSpacing: AppSpazi.xs,
                              children: [
                                FilledButton.icon(
                                  key: const Key('whatsapp-config-salva'),
                                  onPressed: _salvataggio || _verifica
                                      ? null
                                      : _salva,
                                  icon: _salvataggio
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.save_outlined),
                                  label: const Text('Salva'),
                                ),
                                OutlinedButton.icon(
                                  key: const Key('whatsapp-config-verifica'),
                                  onPressed: _salvataggio || _verifica
                                      ? null
                                      : _verificaConnessione,
                                  icon: _verifica
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.wifi_tethering),
                                  label: const Text('Verifica connessione'),
                                ),
                                OutlinedButton.icon(
                                  key: const Key('whatsapp-config-qr'),
                                  onPressed: _salvataggio || _verifica
                                      ? null
                                      : _mostraQr,
                                  icon: const Icon(Icons.qr_code_2),
                                  label: const Text('Mostra QR'),
                                ),
                              ],
                            ),
                            if (_errore != null) ...[
                              const SizedBox(height: AppSpazi.s),
                              AvvisoErrore(
                                key: const Key('whatsapp-config-errore'),
                                testo: _errore!,
                              ),
                            ],
                            if (_messaggio != null) ...[
                              const SizedBox(height: AppSpazi.s),
                              Text(
                                _messaggio!,
                                key: const Key('whatsapp-config-messaggio'),
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpazi.m),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpazi.internoCard),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'CONNESSIONE',
                              style: tema.textTheme.labelSmall?.copyWith(
                                color: tema.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpazi.s),
                            Row(
                              children: [
                                Icon(
                                  _connesso == null
                                      ? Icons.help_outline
                                      : _connesso == true
                                      ? Icons.check_circle_outline
                                      : Icons.error_outline,
                                  color: _connesso == null
                                      ? tema.colorScheme.onSurfaceVariant
                                      : _connesso == true
                                      ? AppColors.accettato
                                      : AppColors.attesa,
                                ),
                                const SizedBox(width: AppSpazi.xs),
                                Expanded(
                                  child: Text(
                                    _connesso == null
                                        ? 'Stato non verificato'
                                        : _connesso == true
                                        ? 'Connesso'
                                        : 'Non connesso',
                                    style: tema.textTheme.titleSmall,
                                  ),
                                ),
                                if (_numero != null && _numero!.isNotEmpty)
                                  Text(
                                    'Numero $_numero',
                                    style: tema.textTheme.bodySmall?.copyWith(
                                      color: tema.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            if (_qr != null) ...[
                              const SizedBox(height: AppSpazi.m),
                              Center(child: _qrImage(_qr!)),
                              const SizedBox(height: AppSpazi.xs),
                              Text(
                                'Apri WhatsApp sul telefono del numero che '
                                'invia i messaggi → Dispositivi collegati → '
                                'Collega un dispositivo, e inquadra il QR.',
                                textAlign: TextAlign.center,
                                style: tema.textTheme.bodySmall?.copyWith(
                                  color: tema.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
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
