import 'package:flutter/material.dart';

import '../progression/collants.dart';
import '../../theme/palette.dart';

/// Le même collant sur le mur et en miniature sur les cartes de jeu.
class Collant extends StatelessWidget {
  final TypeCollant type;
  final bool gagne;
  final double taille;

  const Collant({
    super.key,
    required this.type,
    required this.gagne,
    this.taille = 84,
  });

  @override
  Widget build(BuildContext context) {
    final icone = switch (type) {
      TypeCollant.decouverte => Icons.flag_rounded,
      TypeCollant.deuxEtoiles => Icons.star_rounded,
      TypeCollant.troisEtoiles => Icons.emoji_events_rounded,
      TypeCollant.perseverance => Icons.favorite_rounded,
    };
    final couleur = switch (type) {
      TypeCollant.decouverte => Palette.verdure,
      TypeCollant.deuxEtoiles => Palette.soleil,
      TypeCollant.troisEtoiles => Palette.corail,
      TypeCollant.perseverance => Palette.prune,
    };
    return Semantics(
      label: '${type.titre} : ${gagne ? 'obtenu' : 'à gagner'}',
      child: Container(
        width: taille,
        height: taille,
        decoration: BoxDecoration(
          color: gagne ? couleur.withValues(alpha: 0.22) : Palette.cremeFonce,
          shape: BoxShape.circle,
          border: Border.all(
            color: gagne ? couleur : Palette.grisDoux,
            width: taille * 0.06,
          ),
        ),
        child: Icon(
          icone,
          size: taille * 0.5,
          color: gagne ? couleur : Palette.grisDoux,
        ),
      ),
    );
  }
}
