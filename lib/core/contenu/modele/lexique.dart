/// Une entrée de lexique : comment un concept se dit dans un deck donné.
///
/// Le contenu ne contient JAMAIS de mot : il référence des concepts.
/// C'est ce qui permet de passer du québécois à la France sans dupliquer
/// le contenu — seulement le lexique et les clips.
class EntreeLexique {
  /// Le mot tel qu'il est écrit et dit ('chapeau', 'tuque'…).
  final String texte;

  /// Identifiant du clip audio. Par défaut : `lex.<concept>`.
  final String? clipId;

  /// Fichier d'illustration (sans chemin). Par défaut : `<concept>.svg`.
  /// Deux decks qui désignent le même objet partagent la même illustration.
  final String? illustration;

  const EntreeLexique({required this.texte, this.clipId, this.illustration});

  String clipPour(String concept) => clipId ?? 'lex.$concept';

  String illustrationPour(String concept) => illustration ?? '$concept.svg';
}

/// Le lexique d'un deck : concept → entrée.
typedef Lexique = Map<String, EntreeLexique>;
