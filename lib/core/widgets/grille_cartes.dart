import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Des cartes à hauteur naturelle : une colonne sur téléphone, plusieurs
/// sur tablette, sans imposer un carré au texte ou aux commandes.
class GrilleCartes extends StatelessWidget {
  final List<Widget> enfants;
  final double largeurMin;
  final EdgeInsets padding;

  const GrilleCartes({
    super.key,
    required this.enfants,
    this.largeurMin = 280,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, contraintes) {
      final largeur = math.max(0.0, contraintes.maxWidth - padding.horizontal);
      const espace = 16.0;
      final facteurTexte = MediaQuery.textScalerOf(context).scale(20) / 20;
      final minimum = largeurMin * math.max(1.0, facteurTexte);
      final colonnes = ((largeur + espace) / (minimum + espace)).floor().clamp(
        1,
        4,
      );
      final cote = (largeur - espace * (colonnes - 1)) / colonnes;
      return SingleChildScrollView(
        padding: padding,
        child: Wrap(
          spacing: espace,
          runSpacing: espace,
          children: [
            for (final enfant in enfants) SizedBox(width: cote, child: enfant),
          ],
        ),
      );
    },
  );
}
