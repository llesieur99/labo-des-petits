import 'package:flutter/material.dart';

import '../../theme/palette.dart';
import '../contenu/modele/lexique.dart';
import 'image_concept.dart';

/// L'image et son mot partagent la place disponible dans la carte.
/// La cible garde sa taille même quand le mot est long ou la police agrandie.
class ContenuCarteConcept extends StatelessWidget {
  final String concept;
  final EntreeLexique? entree;
  final double cote;
  final bool afficherMot;

  const ContenuCarteConcept({
    super.key,
    required this.concept,
    required this.entree,
    required this.cote,
    required this.afficherMot,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Flexible(
        flex: 3,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: ImageConcept(
            concept: concept,
            fichier: entree?.illustrationPour(concept) ?? '',
            taille: cote * 0.62,
          ),
        ),
      ),
      if (afficherMot) ...[
        const SizedBox(height: 6),
        Flexible(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              entree?.texte ?? concept,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Palette.encre,
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
