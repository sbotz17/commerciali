import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/passkey_service.dart';
import '../../state/auth_providers.dart';

/// Impostazioni → Accesso con Face ID.
///
/// Attiva una passkey per l'utente collegato, elenca i dispositivi e permette
/// di rimuoverli. La richiesta di Face ID la mostra il sistema.
class AccessoFaceIdCard extends ConsumerStatefulWidget {
  const AccessoFaceIdCard({super.key});

  @override
  ConsumerState<AccessoFaceIdCard> createState() => _AccessoFaceIdCardState();
}

class _AccessoFaceIdCardState extends ConsumerState<AccessoFaceIdCard> {
  late final PasskeyService _servizio = ref.read(passkeyServiceProvider);
  bool _supportato = false;
  bool _caricamento = true;
  bool _attivando = false;
  String? _errore;
  String? _esito;
  List<PasskeyInfo> _passkeys = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final supportato = await _servizio.disponibile();
    if (!mounted) return;
    if (!supportato) {
      setState(() {
        _supportato = false;
        _caricamento = false;
      });
      return;
    }
    setState(() => _supportato = true);
    await _carica();
  }

  Future<void> _carica() async {
    try {
      final elenco = await _servizio.elenco();
      if (!mounted) return;
      setState(() {
        _passkeys = elenco;
        _caricamento = false;
        _errore = null;
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _caricamento = false;
        _errore = messaggioErrorePasskey(errore);
      });
    }
  }

  Future<void> _attiva() async {
    setState(() {
      _attivando = true;
      _errore = null;
      _esito = null;
    });
    try {
      await _servizio.registra();
      if (!mounted) return;
      setState(() => _esito = 'Accesso con Face ID attivato su questo dispositivo.');
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = messaggioErrorePasskey(errore));
    } finally {
      if (mounted) setState(() => _attivando = false);
    }
  }

  Future<void> _rimuovi(PasskeyInfo passkey) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovere Face ID?'),
        content: Text(
          'Per usare di nuovo Face ID su «${passkey.nome}» dovrai riattivarlo '
          'con email e password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;
    setState(() {
      _caricamento = true;
      _errore = null;
      _esito = null;
    });
    try {
      await _servizio.rimuovi(passkey.id);
      if (!mounted) return;
      setState(() => _esito = 'Accesso con Face ID rimosso.');
      await _carica();
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _caricamento = false;
        _errore = messaggioErrorePasskey(errore);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      key: const Key('face-id-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.face_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: AppSpazi.s),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accesso con Face ID',
                        style: tema.textTheme.titleMedium,
                      ),
                      Text(
                        'Entra senza digitare email e password',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.m),
            if (_caricamento)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpazi.s),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              ),
            if (!_caricamento && !_supportato)
              Text(
                'Disponibile nella web app, su un telefono o computer con '
                'Face ID, Touch ID o il PIN del dispositivo.',
                style: tema.textTheme.bodySmall,
              ),
            if (!_caricamento && _supportato) ...[
              Text(
                'Email e password restano sempre disponibili: Face ID è in più.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpazi.s),
              if (_passkeys.isEmpty)
                Text(
                  'Nessun accesso con Face ID attivo su questo account.',
                  key: const Key('face-id-nessuno'),
                  style: tema.textTheme.bodyMedium,
                )
              else
                Column(
                  key: const Key('face-id-lista'),
                  children: [
                    for (final passkey in _passkeys)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.smartphone_outlined),
                        title: Text(passkey.nome),
                        subtitle: Text(
                          passkey.creato == null
                              ? 'Attivo'
                              : 'Attivato il '
                                  '${DateFormat('dd/MM/yyyy').format(passkey.creato!)}',
                        ),
                        trailing: IconButton(
                          key: Key('face-id-rimuovi-${passkey.id}'),
                          tooltip: 'Rimuovi',
                          onPressed: _attivando
                              ? null
                              : () => _rimuovi(passkey),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                  ],
                ),
              if (_errore != null) ...[
                const SizedBox(height: AppSpazi.s),
                _Avviso(
                  key: const Key('face-id-errore'),
                  testo: _errore!,
                  colore: tema.colorScheme.errorContainer,
                  testoColore: tema.colorScheme.onErrorContainer,
                  icona: Icons.error_outline,
                ),
              ],
              if (_esito != null) ...[
                const SizedBox(height: AppSpazi.s),
                _Avviso(
                  key: const Key('face-id-esito'),
                  testo: _esito!,
                  colore: tema.colorScheme.primaryContainer,
                  testoColore: tema.colorScheme.onPrimaryContainer,
                  icona: Icons.check_circle_outline,
                ),
              ],
              const SizedBox(height: AppSpazi.m),
              FilledButton.icon(
                key: const Key('face-id-attiva'),
                onPressed: _attivando ? null : _attiva,
                icon: _attivando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.face_outlined),
                label: Text(
                  _attivando ? 'Attendo Face ID…' : 'Attiva Face ID',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Avviso extends StatelessWidget {
  const _Avviso({
    super.key,
    required this.testo,
    required this.colore,
    required this.testoColore,
    required this.icona,
  });

  final String testo;
  final Color colore;
  final Color testoColore;
  final IconData icona;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpazi.s),
        decoration: BoxDecoration(
          color: colore,
          borderRadius: BorderRadius.circular(AppRaggi.chip),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icona, size: 18, color: testoColore),
            const SizedBox(width: AppSpazi.xs),
            Expanded(
              child: Text(
                testo,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: testoColore),
              ),
            ),
          ],
        ),
      );
}
