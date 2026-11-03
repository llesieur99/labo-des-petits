import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/core/widgets/collant.dart';
import 'package:jeux_enfants/features/famille/famille_screen.dart';
import 'package:jeux_enfants/features/jeu/jeu_controller.dart';
import 'package:jeux_enfants/features/shell/shell_controller.dart';
import 'package:jeux_enfants/theme/theme_enfant.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/commencer_guide.dart';
import '../support/jouer_manche.dart';

void main() {
  Future<(DepotMemoire, ShellController)> monter(
    WidgetTester tester, {
    int parties = 0,
    int etoiles = 0,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final reglages = await Reglages.charger();
    final depot = DepotMemoire();
    final profil = await depot.creerProfil(
      nom: 'Camille',
      avatar: 'chat',
      ageDeclare: 4,
    );
    await depot.enregistrerEtat(
      AdaptationDouce.etatInitial(
        profilId: profil.id!,
        activiteId: 'rimes',
        palier: Palier.a4,
      ).copieAvec(partiesJouees: parties, meilleureEtoile: etoiles),
    );
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
          Provider<Reglages>.value(value: reglages),
          Provider<SayKit>.value(value: say),
          ChangeNotifierProvider<ShellController>.value(value: shell),
        ],
        child: MaterialApp(
          theme: themeEnfant(),
          home: const FamilleScreen(famille: Famille.langue),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (depot, shell);
  }

  Finder miniatures(String id) => find.descendant(
    of: find.byKey(ValueKey('jeu.collants.$id')),
    matching: find.byType(Collant),
  );
  int gagnes(WidgetTester tester, String id) =>
      tester.widgetList<Collant>(miniatures(id)).where((c) => c.gagne).length;

  for (final cas in [
    (parties: 0, etoiles: 0, obtenus: 0),
    (parties: 1, etoiles: 2, obtenus: 2),
    (parties: 5, etoiles: 3, obtenus: 4),
  ]) {
    testWidgets('rubrique : ${cas.obtenus}/4 collants obtenus', (tester) async {
      await monter(tester, parties: cas.parties, etoiles: cas.etoiles);
      expect(miniatures('rimes'), findsNWidgets(4));
      expect(gagnes(tester, 'rimes'), cas.obtenus);
      expect(gagnes(tester, 'bouche'), 0);
      expect(
        tester
            .widgetList<Collant>(miniatures('rimes'))
            .every((c) => c.taille == 36),
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('jeu.collants.rimes')),
          matching: find.text('${cas.obtenus}/4'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changer de profil affiche ses propres collants', (tester) async {
    final (depot, shell) = await monter(tester, parties: 5, etoiles: 3);
    final premier = shell.profilActif!;
    final autre = await depot.creerProfil(
      nom: 'Alex',
      avatar: 'lapin',
      ageDeclare: 5,
    );
    await shell.choisirProfil(autre);
    await tester.pumpAndSettle();
    expect(gagnes(tester, 'rimes'), 0);
    await shell.choisirProfil(premier);
    await tester.pumpAndSettle();
    expect(gagnes(tester, 'rimes'), 4);
  });

  testWidgets('les collants apparaissent au retour de la partie terminée', (
    tester,
  ) async {
    await monter(tester);
    expect(gagnes(tester, 'rimes'), 0);
    await tester.tap(find.byKey(const ValueKey('jeu.ouvrir.rimes')));
    await tester.pumpAndSettle();
    await commencerGuide(tester);
    final partie =
        tester
                .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
                .firstWhere((w) => w.animation is JeuController)
                .animation
            as JeuController;
    for (var i = 0; i < partie.itemsTotal; i++) {
      await jouerManche(tester, partie);
    }
    expect(partie.fini, isTrue);
    await toucher(
      tester,
      find.byWidgetPredicate(
        (w) => w is CibleTactile && w.semantique == 'Retour',
      ),
    );
    await tester.pumpAndSettle();
    expect(gagnes(tester, 'rimes'), 3);
    expect(gagnes(tester, 'bouche'), 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 12));
    expect(tester.takeException(), isNull);
  });
}
