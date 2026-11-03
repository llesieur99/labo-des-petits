import 'package:flutter/foundation.dart';

import 'lecteur_audio.dart';
import 'manifeste_audio.dart';

/// « Dire un clip » : le point par lequel toute la voix de l'app passe.
///
/// Un identifiant introuvable ne plante jamais : on le journalise en debug
/// et on continue — un enfant ne doit pas voir une erreur parce qu'un
/// enregistrement manque.
class SayKit {
  final RepertoireClips repertoire;
  final LecteurClips lecteur;
  final Set<String> _signales = {};

  SayKit({required this.repertoire, required this.lecteur});

  /// Dit un seul clip.
  Future<void> dire(String id) => direSequence([id]);

  /// Change la voix en cours d'app (bascule femme/homme de l'espace parent).
  /// Coupe la voix en cours pour que le changement s'entende tout de suite.
  Future<void> changerVoix(String voix) async {
    await stopper();
    repertoire.voixActive = voix;
  }

  /// Dit une suite de clips (ex. gabarit de consigne + mot entendu).
  Future<void> direSequence(List<String> ids) async {
    final chemins = <String>[];
    for (final id in ids) {
      final entree = repertoire.pour(id);
      if (entree == null) {
        _signaler(id);
        continue;
      }
      chemins.add(entree.cheminAsset);
    }
    await lecteur.jouerSequence(chemins);
  }

  /// Joue un son NON VERBAL embarqué (tambour, note, grelot) : un chemin
  /// d'asset direct sous assets/audio/neutre/, sans passer par le manifeste
  /// des voix.
  Future<void> jouerAsset(String cheminAsset) =>
      lecteur.jouerSequence([cheminAsset]);

  /// Coupe la voix en cours.
  Future<void> stopper() => lecteur.stopper();

  void _signaler(String id) {
    if (_signales.add(id)) {
      debugPrint('SayKit : clip « $id » introuvable (ignoré, l\'app continue).');
    }
  }
}
