import 'catalogue.dart';
import 'clips_chrome.dart';
import 'modele/activite.dart';

/// Un clip à générer, avec son texte source et sa provenance.
class ClipDeclare {
  final String id;
  final String texte;

  /// consigne | retour | lexique | phrase | chanson
  final String categorie;

  /// Activité d'origine, si le clip vient d'une activité.
  final String? activite;

  /// Concept d'origine, si le clip vient du lexique.
  final String? concept;

  final String? rate;
  final String? pitch;

  const ClipDeclare({
    required this.id,
    required this.texte,
    required this.categorie,
    this.activite,
    this.concept,
    this.rate,
    this.pitch,
  });
}

/// Tous les clips d'un deck : chrome de l'app + clips des activités +
/// lexique du deck. Un même id n'apparaît qu'une fois (le premier gagne).
///
/// C'est la source unique de l'export audio et du validateur : ce que
/// l'app peut demander, et rien d'autre.
List<ClipDeclare> clipsDuDeck(Deck deck) {
  final vus = <String>{};
  final clips = <ClipDeclare>[];

  void ajouter(ClipDeclare clip) {
    if (vus.add(clip.id)) clips.add(clip);
  }

  for (final clip in clipsChrome) {
    ajouter(ClipDeclare(
      id: clip.id,
      texte: clip.texte,
      categorie: clip.categorie,
      rate: clip.rate,
      pitch: clip.pitch,
    ));
  }

  for (final activite in catalogueActivites) {
    for (final clip in activite.clips) {
      ajouter(ClipDeclare(
        id: clip.id,
        texte: clip.texte,
        categorie: clip.categorie,
        activite: activite.id,
        rate: clip.rate,
        pitch: clip.pitch,
      ));
    }
  }

  final lexique = lexiquePour(deck);
  for (final entree in lexique.entries) {
    ajouter(ClipDeclare(
      id: entree.value.clipPour(entree.key),
      texte: entree.value.texte,
      categorie: 'lexique',
      concept: entree.key,
    ));
  }

  return clips;
}

/// Les clips du lexique seulement (pour le CSV d'enregistrement).
List<ClipDeclare> clipsLexiqueDuDeck(Deck deck) =>
    clipsDuDeck(deck).where((c) => c.categorie == 'lexique').toList();
