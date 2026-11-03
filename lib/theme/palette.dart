import 'package:flutter/material.dart';

/// La palette de l'app : crème chaude, encre brune, accents doux.
/// Jamais de noir pur, jamais de rouge alarmant.
abstract final class Palette {
  static const creme = Color(0xFFFDF6E3);
  static const cremeFonce = Color(0xFFF3E8CF);
  static const encre = Color(0xFF4A3B2A);
  static const encreDouce = Color(0xFF7A6A56);

  static const corail = Color(0xFFE8734A);
  static const soleil = Color(0xFFF6C445);
  static const verdure = Color(0xFF4CAF7D);
  static const ciel = Color(0xFF4A90D9);
  static const prune = Color(0xFF9C6BAF);

  static const grisDoux = Color(0xFFC9BCA4);

  /// Une couleur d'accent par famille d'activités.
  static const familles = [corail, ciel, verdure, soleil, prune, corail, ciel];

  /// Une couleur de tuile pour un concept, stable d'un affichage à l'autre.
  static Color tuilePour(String concept) {
    const teintes = [soleil, corail, verdure, ciel, prune];
    return teintes[concept.hashCode.abs() % teintes.length];
  }
}
