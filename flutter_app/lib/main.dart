import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'firebase_options_prod.dart';

/// `staging` (default) oppure `prod`, scelto con
/// `--dart-define=APP_ENV=prod`.
const String _ambiente = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'staging',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: _ambiente == 'prod'
        ? DefaultFirebaseOptionsProd.currentPlatform
        : DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ProviderScope(
      child: CloserApp(initialLocation: _rottaIniziale()),
    ),
  );
}

/// Legge la rotta dal browser: path (`/intro`) o hash (`#/intro`).
String? _rottaIniziale() {
  final base = Uri.base;
  if (base.fragment.startsWith('/')) return base.fragment;
  if (base.path.isNotEmpty && base.path != '/') return base.path;
  return null;
}
