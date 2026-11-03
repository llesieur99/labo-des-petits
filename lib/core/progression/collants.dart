import 'modele.dart';

/// Un type de collant du mur. Quatre par activité.
///
/// Les collants se DÉDUISENT de l'état (jamais stockés à part) : ils ne se
/// perdent pas quand l'historique glisse, parce que [EtatActivite.partiesJouees]
/// et [EtatActivite.meilleureEtoile] ne redescendent jamais.
enum TypeCollant {
  /// Jouer l'activité une première fois.
  decouverte('decouverte'),

  /// Réussir une partie à 2 étoiles ou plus.
  deuxEtoiles('deuxEtoiles'),

  /// Réussir une partie à 3 étoiles (sans aucune erreur).
  troisEtoiles('troisEtoiles'),

  /// Jouer l'activité 5 fois.
  perseverance('perseverance');

  final String id;

  const TypeCollant(this.id);

  /// Le collant est-il gagné ?
  bool gagne(EtatActivite? etat) => switch (this) {
        TypeCollant.decouverte => (etat?.partiesJouees ?? 0) >= 1,
        TypeCollant.deuxEtoiles => (etat?.meilleureEtoile ?? 0) >= 2,
        TypeCollant.troisEtoiles => (etat?.meilleureEtoile ?? 0) >= 3,
        TypeCollant.perseverance => (etat?.partiesJouees ?? 0) >= 5,
      };

  /// Texte pour l'espace parent (jamais montré à l'enfant).
  String get titre => switch (this) {
        TypeCollant.decouverte => 'Première partie',
        TypeCollant.deuxEtoiles => '2 étoiles dans une partie',
        TypeCollant.troisEtoiles => '3 étoiles, sans erreur',
        TypeCollant.perseverance => 'Jouer 5 fois',
      };
}
