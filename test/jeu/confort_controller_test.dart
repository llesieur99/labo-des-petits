import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/rimes_data.dart';
import 'package:jeux_enfants/core/contenu/activites/logique/intrus_data.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';

class VoixControlee extends SayKit {
  final sequences = <List<String>>[];
  Completer<void>? attente;
  VoixControlee()
    : super(
        repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
        lecteur: LecteurFactice(),
      );
  @override
  Future<void> direSequence(List<String> ids) async {
    sequences.add(List.of(ids));
    await attente?.future;
  }

  @override
  Future<void> stopper() async {
    if (attente != null && !attente!.isCompleted) attente!.complete();
  }
}

Future<JeuController> preparer(
  VoixControlee voix, {
  Activite? jeu,
  int? etape,
}) async {
  final activite = jeu ?? activiteRimes;
  final depot = DepotMemoire();
  final profil = await depot.creerProfil(
    nom: 'Test',
    avatar: 'chat',
    ageDeclare: 5,
  );
  return JeuController(
    activite: activite,
    niveau: activite.niveauPour(Palier.a5, numero: etape)!,
    etat: AdaptationDouce.etatInitial(
      profilId: profil.id!,
      activiteId: activite.id,
      palier: Palier.a5,
    ),
    say: voix,
    depot: depot,
    alea: Random(47),
    delaiEntreItems: Duration.zero,
  );
}

void main() {
  test(
    'la découverte ne désigne pas la réponse avant le premier essai',
    () async {
      final partie = await preparer(VoixControlee(), etape: 1);
      addTearDown(partie.dispose);
      await partie.demarrer();
      expect(partie.montrerIndice, isFalse);
      await partie.choisir(
        partie.optionsAffichees.firstWhere(
          (o) => o.id != partie.manche.bonneOptionId,
        ),
      );
      expect(partie.montrerIndice, isTrue);
    },
  );

  test(
    'une bonne réponse nomme l’image puis explique l’intrus avant le bravo',
    () async {
      final voix = VoixControlee();
      final partie = await preparer(voix, jeu: activiteIntrus);
      addTearDown(partie.dispose);
      await partie.demarrer();
      final manche = partie.manche;
      await partie.choisir(manche.bonneOption);
      final clips = voix.sequences.expand((c) => c).toList();
      final nom = clips.indexOf('lex.${manche.bonneOption.concept}');
      final explication = clips.indexOf(manche.explicationCle!);
      final bravo = clips.indexWhere((c) => c.startsWith('retour.bravo.'));
      expect(nom, greaterThanOrEqualTo(0));
      expect(explication, greaterThan(nom));
      expect(bravo, greaterThan(explication));
    },
  );

  test(
    'une réponse avant la fin de la consigne ne valide pas une manche',
    () async {
      final voix = VoixControlee()..attente = Completer<void>();
      final partie = await preparer(voix);
      addTearDown(partie.dispose);
      final lancement = partie.demarrer();
      await Future<void>.delayed(Duration.zero);
      expect(partie.interactionPossible, isFalse);
      await partie.choisir(partie.manche.bonneOption);
      expect(await partie.depot.evenements(partie.etat.profilId), isEmpty);
      voix.attente!.complete();
      await lancement;
      expect(partie.interactionPossible, isTrue);
    },
  );

  test('une voix interrompue reprend avant de rendre la main au jeu', () async {
    final voix = VoixControlee()..attente = Completer<void>();
    final partie = await preparer(voix);
    addTearDown(partie.dispose);
    final lancement = partie.demarrer();
    await Future<void>.delayed(Duration.zero);
    partie.suspendre();
    await Future<void>.delayed(Duration.zero);
    expect(partie.enPause, isTrue);
    expect(partie.interactionPossible, isFalse);
    voix.attente = null;
    await partie.reprendre();
    await lancement;
    expect(voix.sequences, hasLength(2));
    expect(voix.sequences.first, voix.sequences.last);
    expect(partie.interactionPossible, isTrue);
  });

  test(
    'Répète utilise la consigne courante du moteur et respecte son propriétaire',
    () async {
      final voix = VoixControlee();
      final partie = await preparer(voix);
      addTearDown(partie.dispose);
      await partie.demarrer();
      final ancien = Object();
      final courant = Object();
      var rappels = 0;
      partie.enregistrerConsigne(ancien, () async {
        rappels += 100;
      });
      partie.enregistrerConsigne(courant, () async {
        rappels++;
      });
      partie.retirerConsigne(ancien);
      await partie.repeterConsigne();
      expect(rappels, 1);
      partie.retirerConsigne(courant);
    },
  );

  testWidgets('une attente moteur ne consomme pas son délai pendant la pause', (
    tester,
  ) async {
    final partie = await preparer(VoixControlee());
    var fini = false;
    final attente = partie
        .attendre(const Duration(milliseconds: 400))
        .then((_) => fini = true);
    await tester.pump(const Duration(milliseconds: 100));
    partie.suspendre();
    await tester.pump(const Duration(seconds: 10));
    expect(fini, isFalse);
    await partie.reprendre();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await attente;
    expect(fini, isTrue);
    partie.dispose();
  });

  testWidgets(
    'un seul rappel automatique par manche, même après une longue hésitation',
    (tester) async {
      final voix = VoixControlee();
      final partie = await preparer(voix);
      await partie.demarrer();
      await tester.pump(const Duration(seconds: 11));
      await tester.pump();
      expect(voix.sequences, hasLength(2));
      await tester.pump(const Duration(seconds: 30));
      expect(voix.sequences, hasLength(2));
      partie.dispose();
    },
  );
}
