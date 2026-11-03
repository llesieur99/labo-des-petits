import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/features/jeu/fin_de_partie.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';
import 'package:jeux_enfants/features/jeu/jeu_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commencer_guide.dart';
import '../support/jouer_manche.dart';

void main() {
  for (final activite in catalogueActivites) {
    for (final age in [4, 5, 6, 7]) {
      // Les étapes historiques et deux défis avancés doivent tous permettre
      // une vraie partie complète, puis un rejeu sans état résiduel.
      for (final etape in [1, 2, 3, 5, 8]) {
        testWidgets(
          '${activite.id} $age ans étape $etape : partie complète, récompense, rejeu et retour',
          (tester) async {
            tester.view.physicalSize = const Size(390, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            SharedPreferences.setMockInitialValues({});
            final reglages = await Reglages.charger();
            final depot = DepotMemoire();
            final profil = await depot.creerProfil(
              nom: 'Camille',
              avatar: 'chat',
              ageDeclare: age,
            );
            await depot.enregistrerEtat(
              AdaptationDouce.etatInitial(
                profilId: profil.id!,
                activiteId: activite.id,
                palier: Palier.values[age - 4],
              ).copieAvec(niveau: etape),
            );
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
                ],
                child: MaterialApp(
                  home: Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => JeuScreen(
                              activite: activite,
                              profil: profil,
                              alea: Random(47),
                            ),
                          ),
                        ),
                        child: const Text('Ouvrir'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Ouvrir'));
            await tester.pumpAndSettle();
            await commencerGuide(tester);
            JeuController controleur() =>
                tester
                        .widgetList<AnimatedBuilder>(
                          find.byType(AnimatedBuilder),
                        )
                        .firstWhere((w) => w.animation is JeuController)
                        .animation
                    as JeuController;
            final partie = controleur();
            expect(partie.niveau.numero, etape);
            if (activite.moteur != Moteur.scene) {
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.inactive,
              );
              await tester.pump();
              expect(partie.enPause, isTrue);
              await tester.pump(const Duration(seconds: 2));
              expect(await depot.evenements(profil.id!), isEmpty);
              tester.binding.handleAppLifecycleStateChanged(
                AppLifecycleState.resumed,
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
              expect(partie.enPause, isFalse);
            }
            for (var i = 0; i < partie.itemsTotal; i++) {
              expect(
                partie.itemsFaits,
                i,
                reason: 'la manche précédente doit être réellement terminée',
              );
              await jouerManche(tester, partie, avecErreur: i == 0);
            }
            expect(partie.fini, isTrue);
            expect(find.byType(FinDePartie), findsOneWidget);
            final etat = await depot.etat(profil.id!, activite.id);
            expect(etat!.partiesJouees, 1);
            final evenements = await depot.evenements(profil.id!);
            expect(evenements, hasLength(partie.itemsTotal));
            expect(
              evenements.map((e) => e.itemId).toSet(),
              hasLength(partie.itemsTotal),
            );
            await toucher(
              tester,
              find.byWidgetPredicate(
                (w) => w is CibleTactile && w.semantique == 'Encore !',
              ),
            );
            await tester.pump();
            await commencerGuide(tester);
            expect(controleur(), isNot(same(partie)));
            expect(controleur().itemsFaits, 0);
            await toucher(tester, find.bySemanticsLabel('Quitter le jeu'));
            await tester.pumpAndSettle();
            expect(find.text('Ouvrir'), findsOneWidget);
            await tester.pumpWidget(const SizedBox());
            await tester.pump(const Duration(seconds: 12));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
