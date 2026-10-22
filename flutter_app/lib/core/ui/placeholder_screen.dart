import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Corpo provvisorio per le schermate non ancora implementate.
///
/// Mostra solo un messaggio neutro: il titolo della pagina resta nella
/// `AppBar` della shell o della pagina autonoma.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    this.icona = Icons.construction_outlined,
  });

  final IconData icona;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpazi.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 48, color: tema.colorScheme.primary),
            const SizedBox(height: AppSpazi.m),
            Text(
              'Schermata in preparazione',
              style: tema.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpazi.xs),
            Text(
              'Questa sezione sarà disponibile nei prossimi task.',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
