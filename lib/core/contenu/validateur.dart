import 'dart:math';
import 'dart:collection';

import 'catalogue.dart';
import 'lettres/chemins_lettres.dart';
import 'modele/activite.dart';
import 'modele/donnees_manche.dart';
import 'preparer_partie.dart';
import 'modele/manche.dart';
import 'registre_clips.dart';

/// Valide tout le contenu et rend la liste des problèmes trouvés.
/// Liste vide = tout va bien. Utilisé par les tests (`test/contenu/`).
///
/// On ne vérifie pas seulement la forme des données : on GÉNÈRE des parties
/// avec plusieurs graines, comme le fera l'app, et on vérifie les invariants
/// propres à chaque moteur.
List<String> validerContenu({int grainesParNiveau = 20}) {
  final problemes = <String>[];
  final idsVus = <String>{};
  final motifId = RegExp(r'^[a-z][a-z0-9]*$');

  final clipsAutorises = <String>{
    for (final clip in clipsDuDeck(Deck.qc)) clip.id,
    for (final clip in clipsDuDeck(Deck.fr)) clip.id,
  };
  final conceptsQc = lexiquePour(Deck.qc).keys.toSet();
  final conceptsFr = lexiquePour(Deck.fr).keys.toSet();

  for (final concept in conceptsQc.difference(conceptsFr)) {
    problemes.add(
      'Concept « $concept » présent au Québec mais absent du lexique France',
    );
  }

  for (final activite in catalogueActivites) {
    final ou = 'Activité ${activite.id}';

    if (activite.nbItemsMaximum < 1 || activite.nbItemsMaximum > 12) {
      problemes.add('$ou : nbItemsMaximum hors bornes (1 à 12)');
    }

    if (!motifId.hasMatch(activite.id)) {
      problemes.add('$ou : identifiant invalide (minuscules ASCII attendues)');
    }
    if (!idsVus.add(activite.id)) {
      problemes.add('$ou : identifiant dupliqué');
    }

    final idsClipsActivite = activite.clips.map((c) => c.id).toSet();
    if (!idsClipsActivite.contains(activite.titreCle)) {
      problemes.add(
        '$ou : le titre ${activite.titreCle} n\'est pas déclaré dans clips',
      );
    }

    final paliersVus = <Palier>{};
    for (final niveau in activite.niveaux) {
      final ouNiveau = '$ou palier ${niveau.palier.id}';
      if (!paliersVus.add(niveau.palier)) {
        problemes.add('$ouNiveau : palier dupliqué');
      }
      if (niveau.nbItems < 1 || niveau.nbItems > 12) {
        problemes.add(
          '$ouNiveau : nbItems ${niveau.nbItems} hors bornes (1 à 12)',
        );
      }
      if (niveau.choixMax < 2 || niveau.choixMax > 6) {
        problemes.add(
          '$ouNiveau : choixMax ${niveau.choixMax} hors bornes (2 à 6)',
        );
      }
      if (niveau.palier == Palier.a4 && niveau.choixMax > 3) {
        problemes.add(
          '$ouNiveau : trop de choix pour 4 ans (${niveau.choixMax})',
        );
      }
    }

    for (final niveau in Palier.values.expand(activite.etapesPour)) {
      for (var graine = 1; graine <= grainesParNiveau; graine++) {
        final manches = _manchesDe(activite, niveau, Random(graine));
        final ouPartie = '$ou ${niveau.palier.id} graine $graine';

        if (activite.source is SourceGenerateur &&
            manches.length != niveau.nbItems) {
          problemes.add(
            '$ouPartie : ${manches.length} manches au lieu de ${niveau.nbItems}',
          );
        }

        final idsManches = <String>{};
        for (final manche in manches) {
          if (!idsManches.add(manche.id)) {
            problemes.add(
              '$ouPartie : manche « ${manche.id} » deux fois dans la partie',
            );
          }
          _validerManche(
            activite,
            niveau,
            manche,
            ouPartie,
            conceptsQc: conceptsQc,
            clipsAutorises: clipsAutorises,
            problemes: problemes,
          );
        }
      }
    }
  }

  return problemes;
}

void _validerManche(
  Activite activite,
  Niveau niveau,
  Manche manche,
  String ouPartie, {
  required Set<String> conceptsQc,
  required Set<String> clipsAutorises,
  required List<String> problemes,
}) {
  final ouManche = '$ouPartie : manche ${manche.id}';

  // Tous les concepts, d'où qu'ils viennent, doivent exister au lexique.
  final conceptsDeLaManche = <String>{
    ...manche.reperes,
    for (final option in manche.options) option.concept,
    ...switch (manche.donnees) {
      DonneesDepot(:final objets, :final emplacements, :final places) => {
        ...objets,
        for (final emplacement in emplacements) emplacement.concept,
        for (final acceptes in places.values) ...acceptes,
      },
      DonneesScene(:final etapes) => {
        for (final etape in etapes) ...etape.options,
        for (final etape in etapes) ...etape.autresBonnesOptions,
        for (final etape in etapes)
          if (etape.bonneOption != null) etape.bonneOption!,
      },
      DonneesOrdre(:final cases) => cases,
      DonneesToile(:final palette, :final couleurObjectif, :final melanges) => {
        ...palette,
        ...melanges.values,
        ?couleurObjectif,
      },
      DonneesTheatre(:final personnages) => personnages,
      DonneesTrace() => const <String>{},
      DonneesRythme(
        :final sonsParOption,
        :final bonneOption,
        :final animalConcept,
      ) =>
        {...sonsParOption.keys, ?bonneOption, ?animalConcept},
      DonneesAtelier(:final groupes, :final nourritures) => {
        for (final groupe in groupes) ...groupe.options,
        ...nourritures,
      },
      DonneesCode(:final animal, :final ramassable) => {animal, ?ramassable},
      DonneesBalance(:final reserve) => reserve,
      DonneesComposer(:final sons) => sons.keys,
      null => const <String>{},
    },
  };
  for (final concept in conceptsDeLaManche) {
    if (!conceptsQc.contains(concept)) {
      problemes.add('$ouManche : concept « $concept » absent du lexique');
    }
  }

  // Les clips de consigne doivent être déclarés.
  final clipsManche = <String>{
    ...manche.clipsConsigne,
    ?manche.explicationCle,
    ...switch (manche.donnees) {
      DonneesDepot(:final finCle) => {?finCle},
      DonneesRythme(
        :final sonCle,
        :final reactionCle,
        :final motCle,
        :final syllabesClips,
      ) =>
        {?sonCle, ?reactionCle, ?motCle, ...syllabesClips},
      DonneesAtelier(
        :final inviterNomCle,
        :final felicitationNomCle,
        :final questionCle,
      ) =>
        {inviterNomCle, felicitationNomCle, questionCle},
      DonneesBalance(:final egalCle, :final pencheCle) => {egalCle, pencheCle},
      _ => const <String>{},
    },
  };
  for (final clip in clipsManche) {
    if (!clipsAutorises.contains(clip)) {
      problemes.add('$ouManche : clip « $clip » non déclaré');
    }
  }

  // Les identifiants d'options sont uniques dans la manche.
  final idsOptions = manche.options.map((o) => o.id).toSet();
  if (idsOptions.length != manche.options.length) {
    problemes.add('$ouManche : options dupliquées');
  }

  // Invariants propres au moteur.
  switch (activite.moteur) {
    case Moteur.tapPick:
      if (manche.options.length != niveau.choixMax) {
        problemes.add(
          '$ouManche : ${manche.options.length} options au lieu de ${niveau.choixMax}',
        );
      }
      if (manche.bonneOptionId == null ||
          !idsOptions.contains(manche.bonneOptionId)) {
        problemes.add(
          '$ouManche : bonne réponse « ${manche.bonneOptionId} » absente',
        );
      }
    case Moteur.dropPlace:
      final donnees = manche.donnees;
      if (donnees is! DonneesDepot) {
        problemes.add('$ouManche : donnees doit être un DonneesDepot');
        break;
      }
      if (donnees.objets.isEmpty) {
        problemes.add('$ouManche : aucun objet à placer');
      }
      if (donnees.emplacements.length < 2) {
        problemes.add('$ouManche : il faut au moins deux emplacements');
      }
      for (final emplacement in donnees.emplacements) {
        if (!donnees.places.containsKey(emplacement.id)) {
          problemes.add(
            '$ouManche : l\'emplacement « ${emplacement.id} » n\'a aucune place définie',
          );
        }
      }
      for (final objet in donnees.objets) {
        final accepte = donnees.places.values.any(
          (conceptsAcceptes) => conceptsAcceptes.contains(objet),
        );
        if (!accepte) {
          problemes.add(
            '$ouManche : l\'objet « $objet » ne va dans aucun emplacement',
          );
        }
      }
    case Moteur.scene:
      final donnees = manche.donnees;
      if (donnees is! DonneesScene) {
        problemes.add('$ouManche : donnees doit être un DonneesScene');
        break;
      }
      if (donnees.etapes.isEmpty) {
        problemes.add('$ouManche : aucune étape');
      }
      for (final etape in donnees.etapes) {
        if (!clipsAutorises.contains(etape.narrationCle)) {
          problemes.add(
            '$ouManche : la narration « ${etape.narrationCle} » n\'est pas déclarée',
          );
        }
        if (etape.observationMs < 0) {
          problemes.add('$ouManche : durée d’observation négative');
        }
        if (etape.autresBonnesOptions.any((c) => !etape.options.contains(c))) {
          problemes.add('$ouManche : réponse alternative absente des choix');
        }
        if (etape.options.isNotEmpty) {
          if (etape.bonneOption == null ||
              !etape.options.contains(etape.bonneOption)) {
            problemes.add(
              '$ouManche : étape « ${etape.narrationCle} » sans bonne réponse valide',
            );
          }
          if (!etape.options.contains(etape.bonneOption)) {
            problemes.add(
              '$ouManche : la bonne réponse de « ${etape.narrationCle} » n\'est pas dans ses options',
            );
          }
        }
      }
    case Moteur.ordre:
      final donnees = manche.donnees;
      if (donnees is DonneesCode) {
        // Mode « exécuter » : le programme doit être possible.
        final grille = donnees.taille;
        bool dansLaGrille(int x, int y) =>
            x >= 0 && y >= 0 && x < grille && y < grille;
        if (!dansLaGrille(donnees.departX, donnees.departY)) {
          problemes.add('$ouManche : le départ du code sort de la grille');
        }
        if (!dansLaGrille(donnees.objectifX, donnees.objectifY)) {
          problemes.add('$ouManche : l\'objectif du code sort de la grille');
        }
        if (!codeEstRealisable(donnees)) {
          problemes.add(
            '$ouManche : objectif impossible avec ${donnees.maxBlocs} blocs (ramassage compris)',
          );
        }
        if (donnees.maxBlocs < 2 || donnees.maxBlocs > 6) {
          problemes.add('$ouManche : nombre de blocs hors bornes (2 à 6)');
        }
        break;
      }
      if (donnees is DonneesComposer) {
        // Mode composer : des cases et des sons, mais jamais de réponse.
        if (donnees.cases < 2) {
          problemes.add('$ouManche : la chanson a moins de deux cases');
        }
        if (donnees.sons.length < 2) {
          problemes.add('$ouManche : la chanson a moins de deux sons');
        }
        break;
      }
      if (donnees is! DonneesOrdre) {
        problemes.add(
          '$ouManche : donnees doit être un DonneesOrdre (ou DonneesCode, DonneesComposer)',
        );
        break;
      }
      if (donnees.cases.length < 2) {
        problemes.add('$ouManche : une séquence à moins de deux cases');
      }
      final conceptsOptions = manche.options.map((o) => o.concept).toSet();
      for (final caseHistoire in donnees.cases) {
        if (!conceptsOptions.contains(caseHistoire)) {
          problemes.add(
            '$ouManche : la case « $caseHistoire » n\'est pas dans les images',
          );
        }
      }
      if (donnees.narrationCle != null &&
          !clipsAutorises.contains(donnees.narrationCle)) {
        problemes.add(
          '$ouManche : la narration « ${donnees.narrationCle} » n\'est pas déclarée',
        );
      }
    case Moteur.trace:
      final donnees = manche.donnees;
      if (donnees is! DonneesTrace) {
        problemes.add('$ouManche : donnees doit être un DonneesTrace');
        break;
      }
      if (!cheminsTrace.containsKey(donnees.cheminId)) {
        problemes.add(
          '$ouManche : le chemin « ${donnees.cheminId} » n\'existe pas dans chemins_lettres.dart',
        );
      }
    case Moteur.creation:
      // L'atelier a des invariants ; la toile et le théâtre, non (créatif).
      final donnees = manche.donnees;
      if (donnees is! DonneesAtelier) break;
      if (donnees.groupes.isEmpty) {
        problemes.add('$ouManche : l\'atelier n\'a aucun groupe à choisir');
      }
      for (final groupe in donnees.groupes) {
        if (groupe.options.length < 2) {
          problemes.add(
            '$ouManche : le groupe « ${groupe.libelleCle} » a moins de deux choix',
          );
        }
        if (!clipsAutorises.contains(groupe.libelleCle)) {
          problemes.add(
            '$ouManche : le clip « ${groupe.libelleCle} » n\'est pas déclaré',
          );
        }
      }
      if (donnees.nourritures.isEmpty) {
        problemes.add('$ouManche : aucune nourriture pour la question finale');
      }
    case Moteur.rythme:
      final donnees = manche.donnees;
      if (donnees is! DonneesRythme) {
        problemes.add('$ouManche : données de rythme absentes');
        break;
      }
      if (donnees.mode == ModeRythme.ecoute) {
        if (manche.options.length < 2 ||
            !manche.options.any((o) => o.concept == donnees.bonneOption)) {
          problemes.add(
            '$ouManche : choix d’écoute absents ou réponse introuvable',
          );
        }
        for (final option in manche.options) {
          if (!donnees.sonsParOption.containsKey(option.concept)) {
            problemes.add('$ouManche : son absent pour ${option.concept}');
          }
        }
      }
    case Moteur.balance:
      final donnees = manche.donnees;
      if (donnees is! DonneesBalance) {
        problemes.add('$ouManche : donnees doit être un DonneesBalance');
        break;
      }
      if (donnees.reserve.length < donnees.minimumParPlateau * 2) {
        problemes.add(
          '$ouManche : la réserve (${donnees.reserve.length}) ne permet pas l\'égalité (${donnees.minimumParPlateau} par plateau)',
        );
      }
    default:
      // Les autres moteurs n'ont pas encore d'invariants propres.
      break;
  }
}

List<Manche> _manchesDe(Activite activite, Niveau niveau, Random alea) =>
    preparerPartie(activite, niveau, alea);

/// Cherche un chemin possible en comptant les quarts de tour et le ramassage,
/// avec la même orientation initiale que le moteur (vers la droite).
bool codeEstRealisable(DonneesCode donnees) {
  if (donnees.taille < 1 || donnees.maxBlocs < 1) return false;
  bool dansLaGrille(int x, int y) =>
      x >= 0 && y >= 0 && x < donnees.taille && y < donnees.taille;
  if (!dansLaGrille(donnees.departX, donnees.departY) ||
      !dansLaGrille(donnees.objectifX, donnees.objectifY)) {
    return false;
  }
  final file = Queue<(int, int, int, int)>()
    ..add((donnees.departX, donnees.departY, 0, 0));
  final vus = <(int, int, int)>{};
  const directions = [(1, 0), (0, 1), (-1, 0), (0, -1)];
  while (file.isNotEmpty) {
    final (x, y, sens, blocs) = file.removeFirst();
    if (!vus.add((x, y, sens))) continue;
    final necessaires = blocs + (donnees.ramassable == null ? 0 : 1);
    if (x == donnees.objectifX &&
        y == donnees.objectifY &&
        necessaires > 0 &&
        necessaires <= donnees.maxBlocs) {
      return true;
    }
    if (blocs >= donnees.maxBlocs) continue;
    file.add((x, y, (sens + 1) % 4, blocs + 1));
    final (dx, dy) = directions[sens];
    if (dansLaGrille(x + dx, y + dy)) {
      file.add((x + dx, y + dy, sens, blocs + 1));
    }
  }
  return false;
}
