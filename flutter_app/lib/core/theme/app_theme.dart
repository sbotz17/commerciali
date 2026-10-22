import 'package:flutter/material.dart';

/// Colori del progetto allineati a `docs/progetto/design.md` (§ Design Flutter).
///
/// Il tema nasce da [primario]; i colori semantici restano costanti e vanno
/// usati per gli stati (attesa, accettato, errore, super admin).
abstract final class AppColors {
  static const Color primario = Color(0xFF1D4ED8);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color sfondo = Color(0xFFF8FAFC);
  static const Color bordo = Color(0xFFE2E8F0);

  static const Color attesa = Color(0xFFD97706);
  static const Color accettato = Color(0xFF16A34A);
  static const Color errore = Color(0xFFDC2626);
  static const Color superAdmin = Color(0xFF7E22CE);
}

/// Spazi su scala 4/8.
abstract final class AppSpazi {
  static const double xxs = 4;
  static const double xs = 8;
  static const double s = 12;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;

  /// Padding pagina: telefono.
  static const double paginaTelefono = 16;

  /// Padding pagina: tablet e desktop.
  static const double paginaDesktop = 24;

  /// Padding pagina: desktop largo.
  static const double paginaDesktopLargo = 32;

  /// Distanza tra le card.
  static const double gapCard = 16;

  /// Padding interno delle card.
  static const double internoCard = 20;
}

/// Raggi degli elementi Material 3.
abstract final class AppRaggi {
  static const double card = 16;
  static const double campo = 12;
  static const double pulsante = 12;
  static const double chip = 8;
}

/// Punti di rottura della shell responsive.
abstract final class AppBreakpoints {
  /// Sotto questa larghezza si usa la `NavigationBar` (telefono).
  static const double telefono = 600;

  /// Da questa larghezza la `NavigationRail` può essere estesa (desktop).
  static const double tablet = 1024;
}

/// Tema unico dell'app (Material 3).
abstract final class AppTheme {
  static ThemeData get light {
    final schema = ColorScheme.fromSeed(
      seedColor: AppColors.primario,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppColors.superficie,
      error: AppColors.errore,
      outline: AppColors.bordo,
      outlineVariant: AppColors.bordo,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: schema);
    final testi = base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.sfondo,
      textTheme: testi,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.superficie,
        foregroundColor: schema.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: testi.titleLarge?.copyWith(color: schema.onSurface),
      ),
      cardTheme: CardThemeData(
        color: AppColors.superficie,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRaggi.card),
          side: const BorderSide(color: AppColors.bordo),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.superficie,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRaggi.campo),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRaggi.campo),
          borderSide: const BorderSide(color: AppColors.bordo),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRaggi.campo),
          borderSide: BorderSide(color: schema.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRaggi.pulsante),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRaggi.pulsante),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRaggi.chip),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.superficie,
        elevation: 0,
        height: 72,
        indicatorColor: schema.primaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.superficie,
        indicatorColor: schema.primaryContainer,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.bordo),
    );
  }
}
