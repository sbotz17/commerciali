// Impostazioni delle integrazioni aziendali.
//
// I dati vivono in `integrazioni_azienda/{aziendaId}` e sono letti/scritti con
// `getIntegrazioneAzienda()` e `salvaIntegrazioneAzienda()`. Il corpo
// ([CorpoIntegrazioni]) è puro: riceve l'integrazione e la callback di
// salvataggio, così resta verificabile senza Firebase.
//
// Regola di sicurezza: il Client Secret non viene mai salvato in Firestore.
// Il campo nei dialog è disabilitato e i modelli non hanno alcun campo
// `client_secret`.

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/avviso_errore.dart';
import '../../core/ui/stato_centrato.dart';
import '../../data/models/integrazione_azienda.dart';
import '../../state/azienda_providers.dart';

// ---------------------------------------------------------------------------
// Funzioni pure (verificabili senza Firebase)
// ---------------------------------------------------------------------------

/// Messaggio mostrato quando il provider non ha ancora un redirect URI.
const String redirectDaGenerare = 'Verrà generato dal Worker';

/// Testo del campo Client Secret, volutamente disabilitato.
const String testoClientSecret = 'Il Client Secret verrà inserito quando il '
    'collegamento al Worker sarà attivo. Non viene salvato in Firestore.';

/// Un provider è configurato solo se è attivo e lo stato è `configurata`.
bool providerConfigurato(ConfigIntegrazioneProvider? configurazione) {
  return configurazione?.attivo == true &&
      configurazione?.stato == 'configurata';
}

/// Etichetta dello stato di un provider.
String etichettaStatoProvider(ConfigIntegrazioneProvider? configurazione) {
  return providerConfigurato(configurazione) ? 'Configurato' : 'Da configurare';
}

/// Indica se, salvando, la configurazione risulta attiva.
///
/// È attiva se si usano le credenziali Closer oppure se è stato inserito un
/// Client ID proprio.
bool configurazioneAttiva(String modalita, String clientId) {
  return modalita == 'closer' || clientId.trim().isNotEmpty;
}

/// Messaggio in italiano per gli errori di caricamento/salvataggio.
String messaggioErroreIntegrazioni(Object errore) {
  if (errore is FirebaseException) {
    switch (errore.code) {
      case 'permission-denied':
        return 'Non hai i permessi per cambiare le integrazioni. '
            'Contatta l\'amministratore.';
      case 'unavailable':
      case 'network-request-failed':
        return 'Connessione assente. Controlla la rete e riprova.';
      case 'unauthenticated':
        return 'Sessione scaduta. Accedi di nuovo e riprova.';
      default:
        return 'Integrazioni non disponibili. Riprova.';
    }
  }
  return 'Integrazioni non disponibili. Controlla la connessione e riprova.';
}

// ---------------------------------------------------------------------------
// Schermata con provider
// ---------------------------------------------------------------------------

/// Schermata `/impostazioni/integrazioni`: provider di calendario e servizi.
class ImpostazioniIntegrazioniScreen extends ConsumerStatefulWidget {
  const ImpostazioniIntegrazioniScreen({super.key});

  @override
  ConsumerState<ImpostazioniIntegrazioniScreen> createState() =>
      _ImpostazioniIntegrazioniScreenState();
}

class _ImpostazioniIntegrazioniScreenState
    extends ConsumerState<ImpostazioniIntegrazioniScreen> {
  IntegrazioneAzienda _integrazione = IntegrazioneAzienda.vuota('');
  bool _caricamento = true;
  bool _salvataggio = false;
  Object? _errore;
  String? _erroreSalvataggio;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  /// Passa l'azienda attiva al servizio e legge l'integrazione.
  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
      _erroreSalvataggio = null;
    });
    try {
      final servizio = ref.read(spServiceProvider);
      final aziendaId = ref.read(aziendaAttivaProvider);
      servizio.setAziendaAttiva(aziendaId);
      final dati = await servizio.getIntegrazioneAzienda();
      if (!mounted) return;
      setState(() {
        _integrazione = dati ?? IntegrazioneAzienda.vuota(aziendaId ?? '');
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

  /// Salva l'integrazione ricevuta dal corpo e mostra la conferma.
  Future<void> _salva(IntegrazioneAzienda integrazione) async {
    setState(() {
      _integrazione = integrazione;
      _salvataggio = true;
      _erroreSalvataggio = null;
    });
    try {
      await ref.read(spServiceProvider).salvaIntegrazioneAzienda(integrazione);
      if (!mounted) return;
      setState(() => _salvataggio = false);
      _avviso('Integrazione salvata');
    } catch (errore) {
      if (!mounted) return;
      final messaggio = messaggioErroreIntegrazioni(errore);
      setState(() {
        _salvataggio = false;
        _erroreSalvataggio = messaggio;
      });
      _avviso(messaggio);
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
          child: CorpoIntegrazioni(
            integrazione: _integrazione,
            caricamento: _caricamento,
            salvataggio: _salvataggio,
            errore: _errore,
            messaggioErroreSalvataggio: _erroreSalvataggio,
            onRiprova: _carica,
            onSalva: _salva,
            onVoce: (rotta) => context.go(rotta),
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
class CorpoIntegrazioni extends StatelessWidget {
  const CorpoIntegrazioni({
    super.key,
    required this.integrazione,
    required this.onSalva,
    required this.onRiprova,
    this.caricamento = false,
    this.salvataggio = false,
    this.errore,
    this.messaggioErroreSalvataggio,
    this.onVoce,
  });

  final IntegrazioneAzienda integrazione;

  /// Riceve l'integrazione completa aggiornata (Google o Microsoft).
  final void Function(IntegrazioneAzienda) onSalva;
  final VoidCallback onRiprova;
  final bool caricamento;
  final bool salvataggio;
  final Object? errore;

  /// Messaggio di errore del salvataggio, già in italiano.
  final String? messaggioErroreSalvataggio;

  /// Naviga verso una rotta dell'app (usata dalla card Push).
  final void Function(String rotta)? onVoce;

  /// Apre il dialog del provider e salva la configurazione scelta.
  Future<void> _apriProvider(
    BuildContext context, {
    required bool microsoft,
  }) async {
    final attuale = microsoft ? integrazione.microsoft : integrazione.google;
    final risultato = await showDialog<ConfigIntegrazioneProvider>(
      context: context,
      useSafeArea: true,
      builder: (dialogContext) => _contenitoreDialog(
        dialogContext,
        microsoft: microsoft,
        configurazione: attuale,
      ),
    );
    if (risultato == null) return;
    onSalva(
      microsoft
          ? integrazione.copyWith(microsoft: risultato)
          : integrazione.copyWith(google: risultato),
    );
  }

  /// Su telefono il dialog occupa tutto lo schermo, su desktop resta un Dialog.
  Widget _contenitoreDialog(
    BuildContext dialogContext, {
    required bool microsoft,
    required ConfigIntegrazioneProvider? configurazione,
  }) {
    final contenuto = _DialogProvider(
      microsoft: microsoft,
      configurazione: configurazione,
      onAnnulla: () => Navigator.of(dialogContext).pop(),
      onSalva: (nuova) => Navigator.of(dialogContext).pop(nuova),
    );
    final larghezza = MediaQuery.sizeOf(dialogContext).width;

    if (larghezza < AppBreakpoints.telefono) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(microsoft ? 'Microsoft' : 'Google'),
            leading: IconButton(
              tooltip: 'Chiudi',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpazi.m),
              child: contenuto,
            ),
          ),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpazi.l),
          child: contenuto,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (caricamento) {
      return const Center(
        key: Key('integrazioni-caricamento'),
        child: CircularProgressIndicator(),
      );
    }

    if (errore != null) {
      return StatoCentrato(
        key: const Key('integrazioni-errore-caricamento'),
        icona: Icons.cloud_off_outlined,
        titolo: 'Integrazioni non disponibili',
        sottotitolo: messaggioErroreIntegrazioni(errore!),
        azione: OutlinedButton.icon(
          key: const Key('integrazioni-riprova'),
          onPressed: onRiprova,
          icon: const Icon(Icons.refresh),
          label: const Text('Riprova'),
        ),
      );
    }

    final messaggioErrore = messaggioErroreSalvataggio;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (messaggioErrore != null) ...[
                AvvisoErrore(
                  key: const Key('integrazioni-errore'),
                  testo: messaggioErrore,
                ),
                const SizedBox(height: AppSpazi.s),
              ],
              _CardProvider(
                chiave: const Key('integrazioni-card-google'),
                titolo: 'Google',
                icona: Icons.event_note_outlined,
                descrizione: 'Collega il calendario Google per gli impegni '
                    'e le call Meet.',
                configurazione: integrazione.google,
                chiavePulsante: const Key('integrazioni-google-configura'),
                onConfigura: () => _apriProvider(context, microsoft: false),
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardProvider(
                chiave: const Key('integrazioni-card-microsoft'),
                titolo: 'Microsoft',
                icona: Icons.business_center_outlined,
                descrizione: 'Collega Microsoft 365 per il calendario Outlook '
                    'e le call Teams.',
                configurazione: integrazione.microsoft,
                chiavePulsante: const Key('integrazioni-microsoft-configura'),
                onConfigura: () => _apriProvider(context, microsoft: true),
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardServizio(
                chiave: const Key('integrazioni-card-smtp'),
                chiavePulsante: const Key('integrazioni-smtp-configura'),
                titolo: 'Email SMTP',
                icona: Icons.alternate_email,
                descrizione: 'Invia preventivi e comunicazioni dal tuo server '
                    'di posta.',
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardServizio(
                chiave: const Key('integrazioni-card-whatsapp'),
                chiavePulsante: const Key('integrazioni-whatsapp-configura'),
                titolo: 'WhatsApp',
                icona: Icons.chat_outlined,
                descrizione: 'Invia conferme appuntamento e messaggi ai '
                    'clienti su WhatsApp.',
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardServizio(
                chiave: const Key('integrazioni-card-r2'),
                chiavePulsante: const Key('integrazioni-r2-configura'),
                titolo: 'Storage R2',
                icona: Icons.cloud_outlined,
                descrizione: 'Archivia allegati e documenti su Cloudflare R2.',
              ),
              const SizedBox(height: AppSpazi.gapCard),
              _CardPush(
                onVoce: onVoce,
              ),
              const SizedBox(height: AppSpazi.l),
              if (salvataggio)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: AppSpazi.xs),
                    child: Text('Salvataggio in corso…'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card di un provider di calendario (Google o Microsoft).
class _CardProvider extends StatelessWidget {
  const _CardProvider({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.descrizione,
    required this.configurazione,
    required this.chiavePulsante,
    required this.onConfigura,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final String descrizione;
  final ConfigIntegrazioneProvider? configurazione;
  final Key chiavePulsante;
  final VoidCallback onConfigura;

  @override
  Widget build(BuildContext context) {
    return _CardIntegrazione(
      chiave: chiave,
      titolo: titolo,
      icona: icona,
      descrizione: descrizione,
      configurato: providerConfigurato(configurazione),
      azioni: [
        FilledButton.tonalIcon(
          key: chiavePulsante,
          onPressed: onConfigura,
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Configura'),
        ),
      ],
    );
  }
}

/// Card di un servizio non ancora configurabile dall'app.
class _CardServizio extends StatelessWidget {
  const _CardServizio({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.descrizione,
    this.nota,
    this.chiavePulsante,
    this.etichettaPulsante = 'Richiede la configurazione del server',
    this.onAzione,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final String descrizione;
  final String? nota;
  final Key? chiavePulsante;
  final String etichettaPulsante;
  final VoidCallback? onAzione;

  @override
  Widget build(BuildContext context) {
    return _CardIntegrazione(
      chiave: chiave,
      titolo: titolo,
      icona: icona,
      descrizione: descrizione,
      configurato: false,
      nota: nota,
      etichettaStato: 'Non attiva',
      azioni: [
        OutlinedButton(
          key: chiavePulsante,
          onPressed: onAzione,
          child: Text(etichettaPulsante),
        ),
      ],
    );
  }
}

/// Card della push: rimanda alle preferenze di notifica.
class _CardPush extends StatelessWidget {
  const _CardPush({this.onVoce});

  final void Function(String rotta)? onVoce;

  @override
  Widget build(BuildContext context) {
    return _CardServizio(
      chiave: const Key('integrazioni-card-push'),
      titolo: 'Push',
      icona: Icons.notifications_active_outlined,
      descrizione: 'Ricevi avvisi su appuntamenti, preventivi e scadenze.',
      nota: 'Gestisci da Notifiche',
      chiavePulsante: const Key('integrazioni-push-apri'),
      etichettaPulsante: 'Apri notifiche',
      onAzione:
          onVoce == null ? null : () => onVoce!('/impostazioni/notifiche'),
    );
  }
}

/// Struttura comune delle card: intestazione, stato, descrizione e azioni.
class _CardIntegrazione extends StatelessWidget {
  const _CardIntegrazione({
    required this.chiave,
    required this.titolo,
    required this.icona,
    required this.descrizione,
    required this.configurato,
    required this.azioni,
    this.nota,
    this.etichettaStato,
  });

  final Key chiave;
  final String titolo;
  final IconData icona;
  final String descrizione;
  final bool configurato;
  final String? nota;

  /// Etichetta di stato alternativa (es. `Non attiva` per i servizi).
  final String? etichettaStato;
  final List<Widget> azioni;

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
                _IndicatoreStato(
                  configurato: configurato,
                  etichetta: etichettaStato,
                ),
              ],
            ),
            const SizedBox(height: AppSpazi.xs),
            Text(
              descrizione,
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            if (nota != null) ...[
              const SizedBox(height: AppSpazi.xxs),
              Text(
                nota!,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: AppSpazi.s),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpazi.xs,
              runSpacing: AppSpazi.xs,
              children: azioni,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pallino e testo dello stato: verde se configurato, ambra se da configurare.
class _IndicatoreStato extends StatelessWidget {
  const _IndicatoreStato({required this.configurato, this.etichetta});

  final bool configurato;
  final String? etichetta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final testo =
        etichetta ?? (configurato ? 'Configurato' : 'Da configurare');
    final colore = etichetta != null
        ? tema.colorScheme.onSurfaceVariant
        : (configurato ? AppColors.accettato : AppColors.attesa);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          configurato ? Icons.check_circle : Icons.circle,
          size: configurato ? 14 : 9,
          color: colore,
        ),
        const SizedBox(width: AppSpazi.xxs),
        Text(
          testo,
          style: tema.textTheme.bodySmall?.copyWith(
            color: colore,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Dialog di configurazione del provider
// ---------------------------------------------------------------------------

/// Dialog con modalità, credenziali e redirect URI del provider.
///
/// Restituisce una [ConfigIntegrazioneProvider] senza alcun secret: il campo
/// Client Secret è disabilitato e non viene letto.
class _DialogProvider extends StatefulWidget {
  const _DialogProvider({
    required this.microsoft,
    required this.configurazione,
    required this.onAnnulla,
    required this.onSalva,
  });

  final bool microsoft;
  final ConfigIntegrazioneProvider? configurazione;
  final VoidCallback onAnnulla;
  final void Function(ConfigIntegrazioneProvider) onSalva;

  @override
  State<_DialogProvider> createState() => _DialogProviderState();
}

class _DialogProviderState extends State<_DialogProvider> {
  late String _modalita;
  late final TextEditingController _clientId;
  late final TextEditingController _tenantId;
  late final TextEditingController _redirect;
  late final TextEditingController _secret;

  String get _prefisso => widget.microsoft ? 'microsoft' : 'google';

  @override
  void initState() {
    super.initState();
    final base = widget.configurazione;
    _modalita = base?.modalita == 'personalizzata'
        ? 'personalizzata'
        : 'closer';
    _clientId = TextEditingController(text: base?.clientId ?? '');
    _tenantId = TextEditingController(text: base?.tenantId ?? '');
    final redirect = base?.redirectUri?.trim() ?? '';
    _redirect = TextEditingController(
      text: redirect.isEmpty ? redirectDaGenerare : redirect,
    );
    _secret = TextEditingController(text: testoClientSecret);
  }

  @override
  void dispose() {
    _clientId.dispose();
    _tenantId.dispose();
    _redirect.dispose();
    _secret.dispose();
    super.dispose();
  }

  /// Costruisce la configurazione da salvare (senza secret) e la restituisce.
  void _salva() {
    final clientId = _clientId.text.trim();
    final tenantId = _tenantId.text.trim();
    final attiva = configurazioneAttiva(_modalita, clientId);
    final base = widget.configurazione ?? ConfigIntegrazioneProvider();

    widget.onSalva(
      base.copyWith(
        modalita: _modalita,
        attivo: attiva,
        clientId: clientId.isEmpty ? null : clientId,
        tenantId: widget.microsoft ? (tenantId.isEmpty ? null : tenantId) : null,
        redirectUri: widget.configurazione?.redirectUri,
        stato: attiva ? 'configurata' : 'non_configurata',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(
              widget.microsoft
                  ? Icons.business_center_outlined
                  : Icons.event_note_outlined,
              color: tema.colorScheme.primary,
            ),
            const SizedBox(width: AppSpazi.xs),
            Expanded(
              child: Text(
                widget.microsoft
                    ? 'Configura Microsoft'
                    : 'Configura Google',
                style: tema.textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpazi.m),
        Text('Modalità', style: tema.textTheme.titleSmall),
        const SizedBox(height: AppSpazi.xs),
        SegmentedButton<String>(
          key: Key('integrazione-$_prefisso-modalita'),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 'closer',
              label: Text('Usa app Closer'),
            ),
            ButtonSegment(
              value: 'personalizzata',
              label: Text('Usa app propria'),
            ),
          ],
          selected: {_modalita},
          onSelectionChanged: (selezione) {
            if (selezione.isEmpty) return;
            setState(() => _modalita = selezione.first);
          },
        ),
        const SizedBox(height: AppSpazi.m),
        TextField(
          key: Key('integrazione-$_prefisso-client-id'),
          controller: _clientId,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Client ID',
            helperText: 'Identificativo OAuth dell\'applicazione.',
          ),
        ),
        if (widget.microsoft) ...[
          const SizedBox(height: AppSpazi.s),
          TextField(
            key: const Key('integrazione-microsoft-tenant'),
            controller: _tenantId,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tenant ID',
              helperText: 'Identificativo della directory Microsoft 365.',
            ),
          ),
        ],
        const SizedBox(height: AppSpazi.s),
        TextField(
          key: Key('integrazione-$_prefisso-redirect'),
          controller: _redirect,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Redirect URI',
            helperText: 'Indirizzo di ritorno usato dal Worker.',
          ),
        ),
        const SizedBox(height: AppSpazi.s),
        TextField(
          key: Key('integrazione-$_prefisso-secret'),
          controller: _secret,
          enabled: false,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Client Secret',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpazi.l),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              key: Key('integrazione-$_prefisso-annulla'),
              onPressed: widget.onAnnulla,
              child: const Text('Annulla'),
            ),
            const SizedBox(width: AppSpazi.xs),
            FilledButton(
              key: Key('integrazione-$_prefisso-salva'),
              onPressed: _salva,
              child: const Text('Salva'),
            ),
          ],
        ),
      ],
    );
  }
}
