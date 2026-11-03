import 'package:flutter/material.dart';

import 'palette.dart';

/// Le thème de l'app : rond, doux, lisible par des enfants qui ne lisent pas.
ThemeData themeEnfant() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Andika',
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.ciel,
      surface: Palette.creme,
      primary: Palette.ciel,
    ),
    scaffoldBackgroundColor: Palette.creme,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: Palette.encre,
      displayColor: Palette.encre,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.encre,
        textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: const BorderSide(color: Palette.cremeFonce, width: 3),
      ),
    ),
  );
}

/// Transition douce entre les écrans : fondu + léger zoom, 300 ms.
Route<T> routeDouce<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final courbe = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: courbe,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1).animate(courbe),
            child: child,
          ),
        );
      },
    );
