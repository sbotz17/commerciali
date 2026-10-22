import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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
