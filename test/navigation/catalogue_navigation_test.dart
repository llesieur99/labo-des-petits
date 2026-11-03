import '../support/commencer_guide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/core/moteurs/m1_tap_pick/tap_pick.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';
import 'package:jeux_enfants/features/accueil/accueil_screen.dart';
import 'package:jeux_enfants/features/famille/famille_screen.dart';
import 'package:jeux_enfants/features/jeu/jeu_screen.dart';
import 'package:jeux_enfants/features/shell/shell_controller.dart';
import 'package:jeux_enfants/theme/theme_enfant.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final activite in catalogueActivites) {
    testWidgets('ouvrir ${activite.id} depuis sa rubrique', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final reglages = await Reglages.charger();
      final depot = DepotMemoire();
      await depot.creerProfil(nom: 'Camille', avatar: 'chat', ageDeclare: 7);
      final shell = ShellController(depot: depot, reglages: reglages);
      await shell.initialiser();
      addTearDown(shell.dispose);
      final say = SayKit(
        repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
        lecteur: LecteurFactice(),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<DepotProgression>.value(value: depot),
            Provider<SayKit>.value(value: say),
            Provider<Reglages>.value(value: reglages),
            ChangeNotifierProvider<ShellController>.value(value: shell),
          ],
          child: MaterialApp(theme: themeEnfant(), home: const AccueilScreen()),
        ),
      );
      await tester.pump();
      final famille = find.byWidgetPredicate(
        (w) => w is CibleTactile && w.semantique == activite.famille.id,
      );
      await tester.ensureVisible(famille);
      await tester.tap(famille);
      await tester.pumpAndSettle();
      expect(find.byType(FamilleScreen), findsOneWidget);
      final image = find.byWidgetPredicate(
        (w) => w is ImageConcept && w.fichier == activite.illustration,
      );
      await tester.scrollUntilVisible(image, 250);
      final titre = activite.clips
          .firstWhere((c) => c.id == activite.titreCle)
          .texte;
      expect(find.text(titre), findsOneWidget);
      final ecouter = find.byKey(ValueKey('jeu.ecouter.${activite.id}'));
      await tester.ensureVisible(ecouter);
      await tester.tap(ecouter);
      await tester.pump();
      expect(
        find.byType(JeuScreen),
        findsNothing,
        reason: 'écouter garde la rubrique ouverte',
      );
      await tester.ensureVisible(image);
      await tester.tap(image);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await commencerGuide(tester);
      expect(
        find.byType(JeuScreen),
        findsOneWidget,
        reason:
            'toucher l’image doit ouvrir le jeu, pas seulement lire son titre',
      );
      expect(
        tester.widget<JeuScreen>(find.byType(JeuScreen)).activite.id,
        activite.id,
      );
      if (activite.id == 'rimes') {
        final controleur =
            tester
                    .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
                    .firstWhere((w) => w.animation is JeuController)
                    .animation
                as JeuController;
        final reponse = lexiquePour(
          Deck.qc,
        )[controleur.manche.bonneOption.concept]!.texte;
        final cible = find.descendant(
          of: find.byType(MoteurTapPick),
          matching: find.byWidgetPredicate(
            (w) => w is CibleTactile && w.semantique == reponse,
          ),
        );
        await tester.ensureVisible(cible);
        await tester.tap(cible);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(
          controleur.itemsFaits,
          1,
          reason: 'une vraie réponse tactile doit faire avancer la partie',
        );
      }
      await tester.tap(find.bySemanticsLabel('Quitter le jeu'));
      await tester.pumpAndSettle();
      expect(find.byType(JeuScreen), findsNothing);
      expect(find.byType(FamilleScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
