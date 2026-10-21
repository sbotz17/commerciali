import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CommercialiApp());
}

class CommercialiApp extends StatelessWidget {
  const CommercialiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Commerciali',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1D4ED8),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
