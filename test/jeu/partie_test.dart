import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/rimes_data.dart';
import 'package:jeux_enfants/core/contenu/activites/logique/intrus_data.dart';
import 'package:jeux_enfants/core/contenu/activites/monde/graine_data.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/core/progression/modele.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';

void main() {
  Future<(JeuController, DepotMemoire, Profil)> preparer({
    Palier palier = Palier.a4,
    DepotMemoire? depotTest,
    Activite activite = activiteRimes,
  }) async {
    final depot = depotTest ?? DepotMemoire();
    final profil = await depot.creerProfil(
      nom: 'Test',
      avatar: 'chat',
      ageDeclare: palier.age,
    );
    final say = SayKit(
      repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
      lecteur: LecteurFactice(),
    );
    final etat = AdaptationDouce.etatInitial(
      profilId: profil.id!,
      activiteId: activite.id,
      palier: palier,
    );
    final controleur = JeuController(
      activite: activite,
      niveau: activite.niveauPour(palier)!,
      etat: etat,
      say: say,
      depot: depot,
      alea: Random(7),
      delaiEntreItems: Duration.zero,
    );
    await controleur.demarrer();
    return (controleur, depot, profil);
  }

  test(
    'une partie parfaite : 3 étoiles, état et journal enregistrés',
    () async {
      final (controleur, depot, profil) = await preparer();

      while (!controleur.fini) {
        await controleur.choisir(controleur.manche.bonneOption);
      }

      expect(controleur.resume!.etoiles, 3);

      final etat = await depot.etat(profil.id!, 'rimes');
      expect(etat, isNotNull);
      expect(etat!.meilleureEtoile, 3);
      expect(etat.partiesJouees, 1);

      final evenements = await depot.evenements(profil.id!);
      expect(evenements.length, controleur.itemsTotal);
      expect(evenements.every((e) => e.correctDuPremierCoup), isTrue);
    },
  );

  test(
    'une erreur par item : jamais de punition, une aide douce arrive',
    () async {
      final (controleur, depot, profil) = await preparer();

      while (!controleur.fini) {
        final mauvaise = controleur.manche.options.firstWhere(
          (o) => o.id != controleur.manche.bonneOptionId,
        );
        await controleur.choisir(mauvaise);
        await controleur.choisir(controleur.manche.bonneOption);
      }

      expect(controleur.resume!.etoiles, 1);
      final etat = await depot.etat(profil.id!, 'rimes');
      expect(
        etat!.aides,
        contains(Aide.consigneRepetee),
        reason: 'une partie faible ajoute une aide, pas une sanction',
      );
      expect(etat.niveau, 1);
    },
  );

  test(
    'deux erreurs sur un même item retirent un choix (jamais la réponse)',
    () async {
      // Au palier 5 ans il y a trois choix : on peut en retirer un.
      final (controleur, _, _) = await preparer(palier: Palier.a5);
      final optionsDepart = controleur.optionsAffichees.length;
      expect(optionsDepart, 3);

      final mauvaises = controleur.manche.options
          .where((o) => o.id != controleur.manche.bonneOptionId)
          .toList();
      await controleur.choisir(mauvaises[0]);
      await controleur.choisir(mauvaises[1]);

      expect(controleur.optionsAffichees.length, optionsDepart - 1);
      expect(
        controleur.optionsAffichees.any(
          (o) => o.id == controleur.manche.bonneOptionId,
        ),
        isTrue,
        reason: 'la bonne réponse ne doit JAMAIS disparaître',
      );
    },
  );

  test(
    'à deux choix seulement, on ne retire jamais le dernier leurre',
    () async {
      final (controleur, _, _) = await preparer(); // 4 ans : 2 choix
      expect(controleur.optionsAffichees.length, 2);

      final mauvaise = controleur.manche.options.firstWhere(
        (o) => o.id != controleur.manche.bonneOptionId,
      );
      await controleur.choisir(mauvaise);
      await controleur.choisir(mauvaise);

      expect(
        controleur.optionsAffichees.length,
        2,
        reason: 'il doit toujours rester au moins deux choix',
      );
    },
  );

  test('les aides des intrus conservent deux membres de la famille', () async {
    final (controleur, _, _) = await preparer(activite: activiteIntrus);
    addTearDown(controleur.dispose);
    expect(controleur.optionsAffichees, hasLength(3));
    for (var i = 0; i < 4; i++) {
      await controleur.choisir(
        controleur.optionsAffichees.firstWhere(
          (o) => o.id != controleur.manche.bonneOptionId,
        ),
      );
    }
    expect(controleur.optionsAffichees, hasLength(3));
    expect(
      controleur.optionsAffichees,
      contains(controleur.manche.bonneOption),
    );
  });

  test('deux réponses simultanées ne valident qu’une seule manche', () async {
    final depotLent = DepotEvenementSuspendu();
    final (controleur, depot, profil) = await preparer(depotTest: depotLent);
    addTearDown(controleur.dispose);
    final bonne = controleur.manche.bonneOption;
    final premier = controleur.choisir(bonne);
    final second = controleur.choisir(bonne);
    depotLent.attente.complete();
    await Future.wait([premier, second]);

    expect((await depot.evenements(profil.id!)).length, 1);
    expect(controleur.itemsFaits, 1);
  });

  test('fermer pendant une sauvegarde ne relance ni voix ni manche', () async {
    final depotLent = DepotEvenementSuspendu();
    final (controleur, depot, profil) = await preparer(depotTest: depotLent);
    final reponse = controleur.choisir(controleur.manche.bonneOption);
    await depotLent.commence.future;
    controleur.dispose();
    depotLent.attente.complete();
    await reponse;

    expect((await depot.evenements(profil.id!)).length, 1);
    expect(controleur.itemsFaits, 0);
    final lecteur = controleur.say.lecteur as LecteurFactice;
    expect(lecteur.sequencesJouees.length, 1);
  });

  test('fermer pendant le retour d’erreur annule la suite', () async {
    final (controleur, _, _) = await preparer();
    final mauvaise = controleur.manche.options.firstWhere(
      (o) => o.id != controleur.manche.bonneOptionId,
    );
    final reponse = controleur.choisir(mauvaise);
    await Future<void>.delayed(Duration.zero);
    controleur.dispose();
    await reponse;

    final lecteur = controleur.say.lecteur as LecteurFactice;
    expect(lecteur.sequencesJouees.length, 2);
  });

  test('une erreur en cours ignore les touches répétées', () async {
    final (controleur, depot, profil) = await preparer();
    addTearDown(controleur.dispose);
    final mauvaise = controleur.manche.options.firstWhere(
      (o) => o.id != controleur.manche.bonneOptionId,
    );
    final erreur = controleur.choisir(mauvaise);
    await controleur.choisir(mauvaise);
    await controleur.choisir(controleur.manche.bonneOption);
    await erreur;
    expect(await depot.evenements(profil.id!), isEmpty);
    expect(controleur.itemsFaits, 0);
    await controleur.choisir(controleur.manche.bonneOption);
    expect(
      (await depot.evenements(profil.id!)).single.correctDuPremierCoup,
      isFalse,
    );
  });

  test(
    'un moteur peut réussir pendant un encouragement sans rester bloqué',
    () async {
      final (controleur, depot, profil) = await preparer();
      addTearDown(controleur.dispose);
      controleur.essaiRate();
      controleur.itemReussi();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(controleur.itemsFaits, 1);
      expect(
        (await depot.evenements(profil.id!)).single.correctDuPremierCoup,
        isFalse,
      );
      final lecteur = controleur.say.lecteur as LecteurFactice;
      expect(
        lecteur.sequencesJouees.length,
        5,
        reason:
            'consigne initiale, encouragement, nom de la réponse, bravo, nouvelle consigne',
      );
    },
  );

  test('la scène garde la narration des manches suivantes', () async {
    final (controleur, _, _) = await preparer(activite: activiteGraine);
    addTearDown(controleur.dispose);
    final lecteur = controleur.say.lecteur as LecteurFactice;
    expect(lecteur.sequencesJouees, isEmpty);
    final avancement = Completer<void>();
    controleur.addListener(() {
      if (controleur.itemsFaits == 1 && !avancement.isCompleted) {
        avancement.complete();
      }
    });
    controleur.itemReussi();
    await avancement.future;
    await Future<void>.delayed(Duration.zero);
    expect(
      lecteur.sequencesJouees.length,
      1,
      reason: 'seul le bravo vient de l’hôte ; la scène dit sa narration',
    );
  });

  test('la fin attend la sauvegarde et supporte la fermeture', () async {
    final depotLent = DepotEtatSuspendu();
    final (controleur, _, _) = await preparer(depotTest: depotLent);
    while (controleur.itemsFaits < controleur.itemsTotal - 1) {
      await controleur.choisir(controleur.manche.bonneOption);
    }
    final reponse = controleur.choisir(controleur.manche.bonneOption);
    await depotLent.commence.future;
    expect(controleur.fini, isFalse);
    controleur.dispose();
    final lecteur = controleur.say.lecteur as LecteurFactice;
    final avant = lecteur.sequencesJouees.length;
    depotLent.attente.complete();
    await reponse;
    expect(lecteur.sequencesJouees.length, avant);
  });
}

class DepotEvenementSuspendu extends DepotMemoire {
  final commence = Completer<void>();
  final attente = Completer<void>();

  @override
  Future<void> enregistrerEvenement(Evenement evenement) async {
    if (!commence.isCompleted) commence.complete();
    await attente.future;
    await super.enregistrerEvenement(evenement);
  }
}

class DepotEtatSuspendu extends DepotMemoire {
  final commence = Completer<void>();
  final attente = Completer<void>();

  @override
  Future<void> enregistrerEtat(EtatActivite etat) async {
    commence.complete();
    await attente.future;
    await super.enregistrerEtat(etat);
  }
}
