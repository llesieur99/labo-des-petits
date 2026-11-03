import '../support/commencer_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/rimes_data.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';
import 'package:jeux_enfants/features/jeu/jeu_screen.dart';
import 'package:jeux_enfants/features/jeu/fin_de_partie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('fermer l’écran libère la partie et son rappel automatique', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final reglages = await Reglages.charger();
    final depot = DepotMemoire();
    final profil = await depot.creerProfil(
      nom: 'Test',
      avatar: 'chat',
      ageDeclare: 4,
    );
    final lecteur = LecteurAvecArrets();
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
          home: JeuScreen(activite: activiteRimes, profil: profil),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await commencerGuide(tester);
    final animation = tester
        .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
        .firstWhere((w) => w.animation is JeuController);
    final controleur = animation.animation as JeuController;
    final avant = lecteur.sequencesJouees.length;

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
    await controleur.repeterConsigne();
    await controleur.dire('retour.fin.1');
    await controleur.jouerSon('assets/audio/neutre/sons/tambour.wav');
    expect(lecteur.sequencesJouees.length, avant);
    expect(lecteur.arrets, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'le temps est compté une seule fois et un double rejeu reste unique',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final reglages = await Reglages.charger();
      final depot = DepotMemoire();
      final profil = await depot.creerProfil(
        nom: 'Test',
        avatar: 'chat',
        ageDeclare: 4,
      );
      final say = SayKit(
        repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
        lecteur: LecteurFactice(),
      );
      var heure = DateTime(2026, 10, 16, 12);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DepotProgression>.value(value: depot),
            Provider<SayKit>.value(value: say),
            Provider<Reglages>.value(value: reglages),
          ],
          child: MaterialApp(
            home: JeuScreen(
              activite: activiteRimes,
              profil: profil,
              maintenant: () => heure,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await commencerGuide(tester);
      JeuController controleur() =>
          tester
                  .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
                  .firstWhere((w) => w.animation is JeuController)
                  .animation
              as JeuController;
      final ancien = controleur();
      heure = heure.add(const Duration(minutes: 3));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      heure = heure.add(const Duration(minutes: 30));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      for (var i = 0; i < ancien.itemsTotal; i++) {
        ancien.itemReussi();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      await commencerGuide(tester);
      expect(reglages.minutesAujourdhui(profil.id!), 3);
      final fin = tester.widget<FinDePartie>(find.byType(FinDePartie));
      tester.element(find.byType(JeuScreen)).markNeedsBuild();
      await tester.pump();
      await tester.pump();
      expect(reglages.minutesAujourdhui(profil.id!), 3);
      fin.onRejouer();
      fin.onRejouer();
      await tester.pumpAndSettle();
      await commencerGuide(tester);
      expect(controleur(), isNot(same(ancien)));
      expect(controleur().itemsFaits, 0);
      expect(reglages.minutesAujourdhui(profil.id!), 3);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}

class LecteurAvecArrets extends LecteurFactice {
  int arrets = 0;

  @override
  Future<void> stopper() async {
    arrets++;
  }
}
