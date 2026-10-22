import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Messaggio di errore in italiano, riusabile dalle schermate di autenticazione.
///
/// Usa i colori semantici del tema (`errorContainer`) e viene annunciato dai
/// lettori di schermo (`liveRegion`). La chiave va passata al widget
/// (`AvvisoErrore(key: ...)`) così i test possono individuarlo.
class AvvisoErrore extends StatelessWidget {
  const AvvisoErrore({super.key, required this.testo});

  /// Testo dell'errore, già tradotto in italiano.
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Container(
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
