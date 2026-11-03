import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/activites/autonomie/table_data.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/moteurs/m2_drop_place/depot_place.dart';
import 'package:jeux_enfants/core/parent/fiches_activites.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/core/widgets/guide_gestuel.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';
import 'package:jeux_enfants/features/jeu/jeu_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commencer_guide.dart';
import '../support/jouer_manche.dart';

void main() {
  testWidgets(
    'le guide est local au profil et conserve un objet déjà pris quand on le revoit',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final reglages = await Reglages.charger();
      final depot = DepotMemoire();
      final profil = await depot.creerProfil(
        nom: 'Test',
        avatar: 'chat',
        ageDeclare: 5,
      );
      final lecteur = LecteurFactice();
      final say = SayKit(
        repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
        lecteur: lecteur,
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DepotProgression>.value(value: depot),
            Provider<SayKit>.value(value: say),
            Provider<Reglages>.value(value: reglages),
          ],
          child: MaterialApp(
            home: JeuScreen(
              activite: activiteTable,
              profil: profil,
              alea: Random(47),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GuideGestuel), findsOneWidget);
      expect(
        lecteur.sequencesJouees,
        isEmpty,
        reason: 'le moteur ne doit pas parler derrière la démonstration',
      );
      await toucheCle(tester, const ValueKey('jeu.guide'));
      await commencerGuide(tester);
      expect(find.byType(MoteurDepotPlace), findsOneWidget);
      expect(reglages.guideVu(profil.id!, GesteGuide.poser.name), isTrue);
      expect(reglages.guideVu(999, GesteGuide.poser.name), isFalse);
      final partie =
          tester
                  .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
                  .firstWhere((w) => w.animation is JeuController)
                  .animation
              as JeuController;
      final donnees = partie.manche.donnees as DonneesDepot;
      final objet = donnees.objets.first;
      final emplacement = donnees.emplacements.firstWhere(
        (e) => donnees.places[e.id]!.contains(objet),
      );
      await toucheCle(tester, MoteurDepotPlace.cleObjet(0, objet));
      await toucheCle(tester, const ValueKey('jeu.guide'));
      expect(partie.enPause, isTrue);
      await tester.pump(const Duration(seconds: 20));
      expect(await depot.evenements(profil.id!), isEmpty);
      await commencerGuide(tester);
      await toucheCle(tester, MoteurDepotPlace.cleEmplacement(emplacement.id));
      expect(
        find.byKey(MoteurDepotPlace.cleObjet(0, objet)),
        findsNothing,
        reason: 'la sélection doit survivre à la démonstration',
      );
      expect(partie.itemsFaits, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
