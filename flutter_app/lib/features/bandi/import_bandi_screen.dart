// Importazione dei bandi open data di incentivi.gov.it.
//
// La schermata è riservata al super admin: chi non lo è vede "Accesso
// riservato" e nessuna richiesta di import parte. Il file può arrivare da un
// URL oppure dal disco; in entrambi i casi il testo viene decodificato,
// normalizzato con `data/bandi_import.dart` e scritto in `bandi_incentivi`
// tramite `SpService.importaBandi`.

import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/bandi_import.dart';
import '../../state/auth_providers.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase né UI)
// ---------------------------------------------------------------------------

/// Errore di importazione con un messaggio già pronto per l'utente.
class ImportBandiException implements Exception {
  const ImportBandiException(this.messaggio);

  final String messaggio;

  @override
  String toString() => messaggio;
}

/// Messaggio in italiano per gli errori di importazione dei bandi.
///
/// Distingue JSON non valido, problemi di rete/CORS e permessi mancanti; per
/// tutto il resto usa un messaggio generico senza dettagli tecnici.
String messaggioErroreImportBandi(Object errore) {
  if (errore is ImportBandiException) return errore.messaggio;

  if (errore is FormatException) {
    return 'Il file non contiene un JSON valido. Controlla di aver scelto '
        'il file open data di incentivi.gov.it.';
  }

  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per importare i bandi. '
            'Contatta l\'amministratore.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      default:
        return 'Importazione non riuscita. Riprova.';
    }
  }

  if (errore is http.ClientException || errore is TimeoutException) {
    return 'Non è stato possibile scaricare il file. Controlla la '
        'connessione. Se il problema continua, il server potrebbe bloccare '
        'le richieste dal browser (CORS): scarica il file JSON e usa '
        '«Scegli file JSON».';
  }

  return 'Importazione non riuscita. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata
// ---------------------------------------------------------------------------

/// Importa i bandi da un file JSON open data o da un URL.
class ImportBandiScreen extends ConsumerStatefulWidget {
  const ImportBandiScreen({super.key});

  @override
  ConsumerState<ImportBandiScreen> createState() => _ImportBandiScreenState();
}

class _ImportBandiScreenState extends ConsumerState<ImportBandiScreen> {
  static final Uri _uriOpenData =
      Uri.parse('https://www.incentivi.gov.it/it/open-data');

  final TextEditingController _url = TextEditingController();

  /// Vero mentre scarica, legge o scrive: i pulsanti restano disabilitati.
  bool _inCorso = false;

  /// Avanzamento 0–1; `null` quando la barra è indeterminata.
  double? _progresso;

  /// Testo di stato sopra la barra ("Download del file…", "Importati …").
  String _fase = '';

  Object? _errore;
  _RisultatoImport? _risultato;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _apriOpenData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final aperto = await launchUrl(
        _uriOpenData,
        mode: LaunchMode.externalApplication,
      );
      if (!aperto) throw Exception('link non aperto');
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Non è stato possibile aprire la pagina open data.'),
        ),
      );
    }
  }

  /// Scarica il JSON dall'URL indicato e lo importa.
  Future<void> _importaDaUrl() async {
    final testo = _url.text.trim();
    if (testo.isEmpty) {
      setState(() {
        _risultato = null;
        _errore = const ImportBandiException(
          'Inserisci l\'indirizzo del file JSON da importare.',
        );
      });
      return;
    }

    final uri = Uri.tryParse(testo);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() {
        _risultato = null;
        _errore = const ImportBandiException(
          'L\'indirizzo non è valido: serve un link http o https a un file '
          'JSON.',
        );
      });
      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
      _risultato = null;
      _progresso = null;
      _fase = 'Download del file in corso…';
    });

    try {
      final risposta = await http
          .get(uri)
          .timeout(const Duration(seconds: 30));
      if (risposta.statusCode != 200) {
        throw ImportBandiException(
          'Il server ha risposto con codice ${risposta.statusCode}. '
          'Se il problema continua, il server potrebbe bloccare le richieste '
          'dal browser (CORS): scarica il file JSON e usa «Scegli file '
          'JSON».',
        );
      }

      final testoJson = utf8.decode(risposta.bodyBytes, allowMalformed: true);
      if (!mounted) return;
      await _importaDaTesto(testoJson, fonte: 'incentivi.gov.it');
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _inCorso = false;
        _progresso = null;
        _fase = '';
        _errore = errore;
        _risultato = null;
      });
    }
  }

  /// Apre il selettore file e importa il JSON scelto.
  Future<void> _scegliFile() async {
    try {
      final scelta = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (scelta.isEmpty) return;

      final file = scelta.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const ImportBandiException(
          'Non è stato possibile leggere il file scelto. Riprova.',
        );
      }

      final nome = file.name.trim();
      final testo = utf8.decode(bytes, allowMalformed: true);
      if (!mounted) return;
      await _importaDaTesto(
        testo,
        fonte: nome.isEmpty ? 'incentivi.gov.it' : nome,
      );
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _inCorso = false;
        _progresso = null;
        _fase = '';
        _errore = errore;
        _risultato = null;
      });
    }
  }

  /// Decodifica, normalizza e scrive i bandi contenuti in [testo].
  Future<void> _importaDaTesto(
    String testo, {
    required String fonte,
  }) async {
    setState(() {
      _inCorso = true;
      _errore = null;
      _risultato = null;
      _progresso = null;
      _fase = 'Lettura del file…';
    });

    try {
      final json = jsonDecode(testo);
      final records = estraiRecordsBandi(json);
      final bandi = normalizzaBandiIncentivi(records, fonte: fonte);

      if (bandi.isEmpty) {
        throw const ImportBandiException(
          'Il file non contiene bandi riconoscibili. Usa l\'open data di '
          'incentivi.gov.it.',
        );
      }

      final totali = bandi.length;
      final attivi = bandi
          .where((bando) => (bando['stato'] as String?) != 'scaduto')
          .length;

      if (!mounted) return;
      setState(() {
        _progresso = 0;
        _fase = 'Importazione in corso…';
      });

      final sp = ref.read(spServiceProvider);
      final importati = await sp.importaBandi(
        bandi,
        onProgresso: (fatti, totale) {
          if (!mounted) return;
          setState(() {
            _progresso =
                totale <= 0 ? 1 : (fatti / totale).clamp(0.0, 1.0).toDouble();
            _fase = 'Importati $fatti di $totale';
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _inCorso = false;
        _progresso = 1;
        _fase = 'Importazione completata';
        _risultato = _RisultatoImport(
          importati: importati,
          attivi: attivi,
          totali: totali,
        );
      });
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _inCorso = false;
        _progresso = null;
        _fase = '';
        _errore = errore;
        _risultato = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profilo = ref.watch(profileProvider);

    if (profilo.isLoading) {
      return const Center(
        key: Key('import-bandi-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (profilo.hasError) {
      return StatoCentrato(
        key: const Key('import-bandi-errore-profilo'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Profilo non disponibile',
        sottotitolo: 'Non è stato possibile verificare i permessi. '
            'Controlla la connessione e riprova.',
        azione: OutlinedButton.icon(
          key: const Key('import-bandi-riprova-profilo'),
          onPressed: () => ref.invalidate(profileProvider),
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    if (profilo.asData?.value?.superAdmin != true) {
      return const StatoCentrato(
        key: Key('import-bandi-riservato'),
        icona: Icons.lock_outline,
        titolo: 'Accesso riservato',
        sottotitolo: 'L\'importazione dei bandi è riservata al super admin '
            'della piattaforma.',
      );
    }

    final tema = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final largo = constraints.maxWidth >= AppBreakpoints.telefono;
        final orizzontale =
            largo ? AppSpazi.paginaDesktop : AppSpazi.paginaTelefono;

        return SingleChildScrollView(
          padding: EdgeInsets.all(orizzontale),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Importa bandi',
                    key: const Key('import-bandi-titolo'),
                    style: tema.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpazi.xs),
                  Text(
                    'I bandi arrivano dagli open data di incentivi.gov.it. '
                    'Scarica il file JSON dalla pagina open data oppure '
                    'incolla l\'indirizzo diretto del file: i bandi già '
                    'presenti vengono aggiornati, gli altri aggiunti.',
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpazi.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('import-bandi-link-open-data'),
                      onPressed: _apriOpenData,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text(
                        'Pagina open data di incentivi.gov.it',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpazi.s),
                  _CardImportUrl(
                    controller: _url,
                    inCorso: _inCorso,
                    onImporta: _importaDaUrl,
                  ),
                  const SizedBox(height: AppSpazi.gapCard),
                  _CardImportFile(inCorso: _inCorso, onScegli: _scegliFile),
                  if (_inCorso) ...[
                    const SizedBox(height: AppSpazi.gapCard),
                    _CardAvanzamento(
                      fase: _fase,
                      progresso: _progresso,
                    ),
                  ],
                  if (_risultato != null) ...[
                    const SizedBox(height: AppSpazi.gapCard),
                    _CardRisultato(risultato: _risultato!),
                  ],
                  if (_errore != null) ...[
                    const SizedBox(height: AppSpazi.gapCard),
                    _CardErrore(errore: _errore!),
                  ],
                  const SizedBox(height: AppSpazi.l),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Widget di supporto
// ---------------------------------------------------------------------------

/// Risultato dell'importazione: bandi scritti, attivi e totali.
class _RisultatoImport {
  const _RisultatoImport({
    required this.importati,
    required this.attivi,
    required this.totali,
  });

  final int importati;
  final int attivi;
  final int totali;
}

/// Card con il campo URL e il pulsante "Importa da URL".
class _CardImportUrl extends StatelessWidget {
  const _CardImportUrl({
    required this.controller,
    required this.inCorso,
    required this.onImporta,
  });

  final TextEditingController controller;
  final bool inCorso;
  final VoidCallback onImporta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: const Key('import-bandi-url-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Importa da URL', style: tema.textTheme.titleSmall),
            const SizedBox(height: AppSpazi.xxs),
            Text(
              'Incolla l\'indirizzo del file JSON, ad esempio quello '
              'pubblicato nella pagina open data.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            TextField(
              key: const Key('import-bandi-url'),
              controller: controller,
              enabled: !inCorso,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) {
                if (!inCorso) onImporta();
              },
              decoration: const InputDecoration(
                labelText: 'Indirizzo del file JSON',
                hintText: 'https://…/bandi.json',
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: const Key('import-bandi-url-avvia'),
                onPressed: inCorso ? null : onImporta,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Importa da URL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card con il pulsante "Scegli file JSON".
class _CardImportFile extends StatelessWidget {
  const _CardImportFile({required this.inCorso, required this.onScegli});

  final bool inCorso;
  final VoidCallback onScegli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: const Key('import-bandi-file-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Importa da file', style: tema.textTheme.titleSmall),
            const SizedBox(height: AppSpazi.xxs),
            Text(
              'Scegli dal dispositivo il file JSON scaricato dalla pagina '
              'open data.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpazi.s),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('import-bandi-file'),
                onPressed: inCorso ? null : onScegli,
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Scegli file JSON'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card con la barra di avanzamento dell'importazione.
class _CardAvanzamento extends StatelessWidget {
  const _CardAvanzamento({required this.fase, required this.progresso});

  final String fase;
  final double? progresso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: const Key('import-bandi-avanzamento'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              fase.isEmpty ? 'Importazione in corso…' : fase,
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpazi.s),
            LinearProgressIndicator(
              key: const Key('import-bandi-progresso'),
              value: progresso,
              minHeight: 6,
            ),
            if (progresso != null) ...[
              const SizedBox(height: AppSpazi.xxs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${(progresso! * 100).round()}%',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card di riepilogo con importati, attivi e totali.
class _CardRisultato extends StatelessWidget {
  const _CardRisultato({required this.risultato});

  final _RisultatoImport risultato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final numeri = NumberFormat.decimalPattern('it_IT');

    return Card(
      key: const Key('import-bandi-risultato'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.accettato,
                ),
                const SizedBox(width: AppSpazi.xs),
                Expanded(
                  child: Text(
                    'Importazione completata',
                    style: tema.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.m),
            Wrap(
              spacing: AppSpazi.l,
              runSpacing: AppSpazi.s,
              children: [
                _StatisticaImport(
                  chiave: const Key('import-bandi-importati'),
                  testo: '${numeri.format(risultato.importati)} importati',
                ),
                _StatisticaImport(
                  chiave: const Key('import-bandi-attivi'),
                  testo: '${numeri.format(risultato.attivi)} attivi',
                ),
                _StatisticaImport(
                  chiave: const Key('import-bandi-totali'),
                  testo: '${numeri.format(risultato.totali)} totali',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Singola statistica del riepilogo ("12 importati").
class _StatisticaImport extends StatelessWidget {
  const _StatisticaImport({required this.chiave, required this.testo});

  final Key chiave;
  final String testo;

  @override
  Widget build(BuildContext context) {
    return Text(
      testo,
      key: chiave,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

/// Card di errore con messaggio in italiano.
class _CardErrore extends StatelessWidget {
  const _CardErrore({required this.errore});

  final Object errore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: const Key('import-bandi-errore'),
      color: AppColors.errore.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.errore),
            const SizedBox(width: AppSpazi.xs),
            Expanded(
              child: Text(
                messaggioErroreImportBandi(errore),
                key: const Key('import-bandi-errore-messaggio'),
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
