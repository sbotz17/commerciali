import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../splash_screen.dart';
import 'intro_screen.dart';

/// Chiave locale che ricorda se la pagina introduttiva è già stata vista.
const String chiaveIntroVista = 'intro_dispositivi_vista';

/// Mostra la pagina introduttiva solo al primo avvio del dispositivo.
///
/// - mentre legge `SharedPreferences` mostra [SplashScreen];
/// - se il flag [chiaveIntroVista] è falso mostra [IntroScreen] e, al tocco su
///   "Ho capito, inizia", salva il flag e mostra [child];
/// - se il flag è vero (o la lettura fallisce) mostra subito [child].
class FirstRunGate extends StatefulWidget {
  const FirstRunGate({super.key, required this.child});

  /// Contenuto mostrato dopo la pagina introduttiva.
  final Widget child;

  @override
  State<FirstRunGate> createState() => _FirstRunGateState();
}

class _FirstRunGateState extends State<FirstRunGate> {
  /// `null` finché la lettura delle preferenze non è conclusa.
  bool? _introVista;

  @override
  void initState() {
    super.initState();
    _leggiFlag();
  }

  Future<void> _leggiFlag() async {
    var vista = false;
    try {
      final preferenze = await SharedPreferences.getInstance();
      vista = preferenze.getBool(chiaveIntroVista) ?? false;
    } catch (_) {
      // Preferenze non disponibili: non si blocca l'app con la pagina
      // introduttiva, che senza storage ricomparirebbe a ogni avvio.
      vista = true;
    }
    if (!mounted) return;
    setState(() => _introVista = vista);
  }

  Future<void> _concludiIntro() async {
    // Si prosegue subito: l'eventuale errore di salvataggio non deve bloccare
    // l'accesso all'app.
    setState(() => _introVista = true);
    try {
      final preferenze = await SharedPreferences.getInstance();
      await preferenze.setBool(chiaveIntroVista, true);
    } catch (_) {
      // Nessuna azione: il flag verrà ritentato al prossimo avvio.
    }
  }

  @override
  Widget build(BuildContext context) {
    final vista = _introVista;
    if (vista == null) return const SplashScreen();
    if (vista) return widget.child;
    return IntroScreen(onFine: _concludiIntro);
  }
}
