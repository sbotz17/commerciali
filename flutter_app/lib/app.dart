import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'routing/app_router.dart';

/// Radice dell'app: tema Material 3 e router.
///
/// Non inizializza Firebase: lo fa `main.dart`, così i test possono montare
/// l'app senza servizi esterni.
class CloserApp extends StatefulWidget {
  const CloserApp({super.key, this.initialLocation});

  /// Rotta iniziale opzionale, utile nei test.
  final String? initialLocation;

  @override
  State<CloserApp> createState() => _CloserAppState();
}

class _CloserAppState extends State<CloserApp> {
  late final GoRouter _router = creaAppRouter(
    initialLocation: widget.initialLocation,
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Closer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
    );
  }
}
