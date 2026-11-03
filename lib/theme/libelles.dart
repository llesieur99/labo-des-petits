import '../core/contenu/modele/activite.dart';

/// Repères écrits pour le parent qui accompagne l'enfant.
String libelleFamille(Famille famille) => switch (famille) {
  Famille.langue => 'Langage',
  Famille.maths => 'Maths',
  Famille.logique => 'Logique',
  Famille.monde => 'Découvertes',
  Famille.emotions => 'Émotions',
  Famille.creation => 'Création',
  Famille.autonomie => 'Autonomie',
};
