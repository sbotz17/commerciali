import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Pagina introduttiva con le istruzioni per installare Commerciali come app.
///
/// Funziona sia come primo avvio (dentro `FirstRunGate`) sia come rotta
/// autonoma `/intro`, aperta dalle impostazioni. Il pulsante finale invoca
/// [onFine]: chi la mostra decide cosa fare (salvare il flag o chiudere la
/// pagina).
class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key, required this.onFine});

  /// Chiamato al tocco su "Ho capito, inizia".
  final VoidCallback onFine;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // Da rotta autonoma (`/intro`) si può tornare indietro; al primo avvio no.
    final puoChiudere = Navigator.of(context).canPop();

    return Scaffold(
      appBar: puoChiudere
          ? AppBar(title: const Text('Come installare l\'app'))
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              key: const Key('intro-lista'),
              padding: const EdgeInsets.fromLTRB(
                AppSpazi.paginaTelefono,
                AppSpazi.l,
                AppSpazi.paginaTelefono,
                AppSpazi.l,
              ),
              children: [
                Center(
                  child: Container(
                    key: const Key('intro-icona-app'),
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: tema.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.storefront,
                      size: 44,
                      color: tema.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpazi.m),
                Text(
                  'Installa Commerciali',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpazi.xs),
                Text(
                  'Puoi usare Commerciali come un\'app: si apre a tutto schermo '
                  'e la trovi tra le applicazioni del dispositivo. '
                  'Scegli le istruzioni per il tuo dispositivo.',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyMedium?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpazi.l),
                const _CardSuggerimento(
                  chiave: Key('intro-suggerimento-android'),
                  icona: Icons.android,
                  piattaforma: 'Android (Chrome)',
                  passi:
                      'Apri il menu ⋮ in alto a destra e scegli '
                      '"Installa app" oppure "Aggiungi a schermata Home".',
                ),
                const SizedBox(height: AppSpazi.s),
                const _CardSuggerimento(
                  chiave: Key('intro-suggerimento-iphone'),
                  icona: Icons.phone_iphone,
                  piattaforma: 'iPhone e iPad (Safari)',
                  passi:
                      'Tocca Condividi, poi scegli "Aggiungi a Home" e '
                      'conferma con "Aggiungi".',
                ),
                const SizedBox(height: AppSpazi.s),
                const _CardSuggerimento(
                  chiave: Key('intro-suggerimento-desktop'),
                  icona: Icons.computer,
                  piattaforma: 'Computer (Chrome o Edge)',
                  passi:
                      'Clicca l\'icona di installazione nella barra degli '
                      'indirizzi e conferma "Installa".',
                ),
                const SizedBox(height: AppSpazi.l),
                FilledButton.icon(
                  key: const Key('intro-ho-capito'),
                  onPressed: onFine,
                  icon: const Icon(Icons.check),
                  label: const Text('Ho capito, inizia'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card con il nome della piattaforma e i passi per installare l'app.
class _CardSuggerimento extends StatelessWidget {
  const _CardSuggerimento({
    required this.chiave,
    required this.icona,
    required this.piattaforma,
    required this.passi,
  });

  final Key chiave;
  final IconData icona;
  final String piattaforma;
  final String passi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      key: chiave,
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.internoCard),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tema.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRaggi.chip),
              ),
              child: Icon(
                icona,
                size: 22,
                color: tema.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: AppSpazi.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    piattaforma,
                    style: tema.textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpazi.xxs),
                  Text(
                    passi,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
