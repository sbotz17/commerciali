import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stato centrato con icona, titolo, sottotitolo e azione facoltativa.
///
/// Usato dalle schermate di elenco per gli stati vuoto, errore e "nessun
/// risultato". Le chiavi dei pulsanti le passa il chiamante, così i test
/// possono individuare l'azione.
class StatoCentrato extends StatelessWidget {
  const StatoCentrato({
    super.key,
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    this.azione,
  });

  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final Widget? azione;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpazi.l),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icona, size: 48, color: tema.colorScheme.onSurfaceVariant),
              const SizedBox(height: AppSpazi.m),
              Text(
                titolo,
                style: tema.textTheme.titleMedium,
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
              if (azione != null) ...[
                const SizedBox(height: AppSpazi.m),
                azione!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
