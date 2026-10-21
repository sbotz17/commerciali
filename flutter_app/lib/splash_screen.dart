import 'package:flutter/material.dart';

/// Schermata iniziale mostrata durante l'avvio dell'app.
///
/// Nessuna logica di auth o dati: solo il nome dell'app e un testo di
/// caricamento. Verrà sostituita dalla navigazione reale nei task successivi.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Commerciali',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            const Text('Caricamento…'),
          ],
        ),
      ),
    );
  }
}
