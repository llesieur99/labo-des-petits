import 'donnees_manche.dart';

/// Une option présentée dans une manche.
///
/// Une option ne porte jamais de mot : elle porte un CONCEPT, que le lexique
/// traduit en texte (québécois ou France), en clip audio et en illustration.
class OptionManche {
  /// Identifiant stable dans la manche.
  final String id;

  /// Clé de concept du lexique ('chapeau', 'bateau'…).
  final String concept;

  const OptionManche({required this.id, required this.concept});
}

/// Une manche : un item de jeu, tel que le moteur le dessine.
///
/// La consigne est une SÉQUENCE de clips déjà générés
/// (ex. « Trouve l'image qui rime avec » + « chapeau »), ce qui évite
/// d'avoir un clip par combinaison possible.
class Manche {
  /// Identifiant stable de la manche (sert au journal et aux tests).
  final String id;

  /// Clips à dire dans l'ordre pour la consigne.
  final List<String> clipsConsigne;

  final List<OptionManche> options;

  /// Référence visuelle distincte des réponses (rime ou situation).
  final List<String> reperes;

  /// L'option correcte parmi [options] (moteur M1 seulement).
  final String? bonneOptionId;

  /// Clip dit pour expliquer la réponse (ex. « Ça, c'est un intrus »).
  final String? explicationCle;

  /// Ce que le moteur a besoin de savoir en plus (M2, M4, M5…).
  final DonneesMoteur? donnees;

  const Manche({
    required this.id,
    required this.clipsConsigne,
    this.options = const [],
    this.reperes = const [],
    this.bonneOptionId,
    this.explicationCle,
    this.donnees,
  });

  /// L'option correcte (moteur M1).
  OptionManche get bonneOption =>
      options.firstWhere((o) => o.id == bonneOptionId);
}
