import '../modele/lexique.dart';
import 'lexique_qc.dart';

/// Lexique France : part du lexique québécois et remplace les mots qui
/// diffèrent réellement (tuque → bonnet, souliers → chaussures…).
///
/// Le deck France n'est servi que quand ses clips existent ; d'ici là,
/// l'app se rabat clip par clip sur le québécois.
///
/// `final` et non `const` : les remplacements ci-dessous reprennent des clés
/// du Québec, et une carte const refuse deux clés égales. L'ordre compte —
/// chaque remplacement écrit APRÈS `...lexiqueQc` gagne.
final lexiqueFr = <String, EntreeLexique>{
  ...lexiqueQc,
  // Écarts France — à remplir au fil du catalogue (vagues suivantes) :
  // 'tuque': EntreeLexique(texte: 'bonnet', illustration: 'tuque.svg'),

  // ── Écarts France — vague 1 ──
  // Seuls les mots réellement différents sont remplacés ; l'illustration
  // reste celle du concept (même objet des deux côtés, même fichier SVG).
  'souliers': EntreeLexique(texte: 'chaussures', illustration: 'souliers.svg'),
  'mitaines': EntreeLexique(texte: 'moufles', illustration: 'mitaines.svg'),
  'gougounes': EntreeLexique(texte: 'sandales', illustration: 'gougounes.svg'),
  // « panier-repas » (et non « boîte à lunch », qui est québécois) : c'est
  // le terme France pour le repas apporté à l'école.
  'lunch': EntreeLexique(texte: 'panier-repas', illustration: 'lunch.svg'),
  // Au Québec on dit « fâché » ; en France, « en colère ».
  'visage_colere': EntreeLexique(
    texte: 'en colère',
    illustration: 'visage_colere.svg',
  ),
};
