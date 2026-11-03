import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/rimes_data.dart';
import 'package:jeux_enfants/core/widgets/guide_gestuel.dart';
import 'package:jeux_enfants/features/parent/guide_parent_screen.dart';
import 'package:jeux_enfants/features/parent/informations_app_screen.dart';
import 'package:jeux_enfants/features/parent/retour_parent_screen.dart';
import 'package:jeux_enfants/features/jeu/jeu_screen.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/core/progression/modele.dart';
import 'package:jeux_enfants/features/accueil/accueil_screen.dart';
import 'package:jeux_enfants/features/famille/famille_screen.dart';
import 'package:jeux_enfants/features/jardin/jardin_screen.dart';
import 'package:jeux_enfants/features/jeu/fin_de_partie.dart';
import 'package:jeux_enfants/features/profil/choix_profil_screen.dart';
import 'package:jeux_enfants/features/profil/creation_profil_screen.dart';
import 'package:jeux_enfants/features/shell/shell_controller.dart';
import 'package:jeux_enfants/theme/theme_enfant.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Andika',
    )..addFont(rootBundle.load('assets/fonts/Andika-Regular.ttf'))).load();
  });
  final boutique = Platform.environment['CAPTURES_STORE'] == '1';
  final formats = boutique
      ? [
          (nom: 'appstore-iphone', taille: const Size(440, 956), texte: 1.0),
          (nom: 'appstore-ipad', taille: const Size(1032, 1376), texte: 1.0),
        ]
      : [
          (nom: 'petit', taille: const Size(320, 568), texte: 1.0),
          (nom: 'iphone', taille: const Size(390, 844), texte: 1.0),
          (nom: 'grand-texte', taille: const Size(390, 844), texte: 2.0),
          (nom: 'paysage', taille: const Size(844, 390), texte: 1.0),
          (nom: 'tablette', taille: const Size(768, 1024), texte: 1.5),
        ];
  for (final format in formats) {
    for (final page in [
      'accueil',
      'langage',
      'profils',
      'creation',
      'collants',
      'fin',
      'demonstration',
      'guide-parent',
      'informations',
      'retour-parent',
      if (boutique) 'rimes',
    ]) {
      testWidgets('$page ${format.nom} police réelle et marges système', (
        tester,
      ) async {
        tester.view.physicalSize = format.taille;
        tester.view.devicePixelRatio = 1;
        final marges = format.nom == 'paysage'
            ? const FakeViewPadding(left: 44, right: 44, bottom: 21)
            : const FakeViewPadding(top: 47, bottom: 34);
        tester.view.padding = marges;
        tester.view.viewPadding = marges;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        SharedPreferences.setMockInitialValues({'guide.v1.1.toucher': true});
        final reglages = await Reglages.charger();
        final depot = DepotMemoire();
        for (final nom in [
          'Camille-Louise',
          'Alexandre',
          'Élodie',
          'Gabriel',
        ]) {
          await depot.creerProfil(nom: nom, avatar: 'chat', ageDeclare: 7);
        }
        final shell = ShellController(depot: depot, reglages: reglages);
        await shell.initialiser();
        await shell.choisirProfil(shell.profils.first);
        addTearDown(shell.dispose);
        for (final cas in [
          (id: 'rimes', parties: 1, etoiles: 2),
          (id: 'bouche', parties: 5, etoiles: 3),
        ]) {
          await depot.enregistrerEtat(
            AdaptationDouce.etatInitial(
              profilId: shell.profilActif!.id!,
              activiteId: cas.id,
              palier: Palier.a7,
            ).copieAvec(
              partiesJouees: cas.parties,
              meilleureEtoile: cas.etoiles,
            ),
          );
        }
        final say = SayKit(
          repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
          lecteur: LecteurFactice(),
        );
        final capture = GlobalKey();
        final Widget ecran = switch (page) {
          'accueil' => const AccueilScreen(),
          'langage' => const FamilleScreen(famille: Famille.langue),
          'profils' => const ChoixProfilScreen(),
          'creation' => const CreationProfilScreen(premier: true),
          'collants' => const JardinScreen(),
          'guide-parent' => const GuideParentScreen(),
          'informations' => const InformationsAppScreen(),
          'retour-parent' => RetourParentScreen(
            ouvrirCourriel: (_, _) async => true,
          ),
          'rimes' => JeuScreen(
            activite: activiteRimes,
            profil: shell.profilActif!,
            alea: Random(47),
          ),
          'demonstration' => Scaffold(
            body: SafeArea(
              child: GuideGestuel(activite: activiteRimes, onCommencer: () {}),
            ),
          ),
          _ => Scaffold(
            body: SafeArea(
              child: FinDePartie(
                resume: const ResumePartie(items: 4, reussisDuPremierCoup: 4),
                nouveauxCollants: 2,
                onRejouer: () {},
                onRetour: () {},
              ),
            ),
          ),
        };
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              Provider<DepotProgression>.value(value: depot),
              Provider<SayKit>.value(value: say),
              Provider<Reglages>.value(value: reglages),
              ChangeNotifierProvider<ShellController>.value(value: shell),
            ],
            child: RepaintBoundary(
              key: capture,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: themeEnfant(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(format.texte)),
                  child: child!,
                ),
                home: ecran,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (Platform.environment['CAPTURES_47'] == '1' || boutique) {
          await tester.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(
                      pixelRatio: boutique
                          ? (format.nom.endsWith('iphone') ? 3 : 2)
                          : 1,
                    );
            final donnees = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final dossier = Directory(
              boutique
                  ? '_local/publication/captures'
                  : '_local/captures-refonte',
            )..createSync(recursive: true);
            await File(
              '${dossier.path}/$page-${format.nom}.png',
            ).writeAsBytes(donnees!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 12));
      });
    }
  }
}
