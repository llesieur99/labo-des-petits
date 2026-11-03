import '../support/commencer_guide.dart';
import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/audio/say_kit.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/adaptation.dart';
import 'package:jeux_enfants/core/progression/depot.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/features/jeu/jeu_screen.dart';
import 'package:jeux_enfants/theme/theme_enfant.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Andika',
    )..addFont(rootBundle.load('assets/fonts/Andika-Regular.ttf'))).load();
  });
  for (final format in [
    (taille: const Size(320, 568), texte: 1.0),
    (taille: const Size(390, 844), texte: 2.0),
    (taille: const Size(844, 390), texte: 1.0),
  ]) {
    for (final activite in catalogueActivites) {
      for (final palier in Palier.values) {
        if (activite.niveauPour(palier) == null) continue;
        for (final etape in [1, 8]) {
          testWidgets(
            '${activite.id} ${palier.id} niveau $etape ${format.taille} texte ${format.texte}',
            (tester) async {
              tester.view.physicalSize = format.taille;
              tester.view.devicePixelRatio = 1;
              final marges = format.taille.width > format.taille.height
                  ? const FakeViewPadding(left: 44, right: 44, bottom: 21)
                  : const FakeViewPadding(top: 47, bottom: 34);
              tester.view.padding = marges;
              tester.view.viewPadding = marges;
              addTearDown(tester.view.resetPadding);
              addTearDown(tester.view.resetViewPadding);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              SharedPreferences.setMockInitialValues({});
              final reglages = await Reglages.charger();
              final depot = DepotMemoire();
              final profil = await depot.creerProfil(
                nom: 'Camille',
                avatar: 'chat',
                ageDeclare: palier.age,
              );
              await depot.enregistrerEtat(
                AdaptationDouce.etatInitial(
                  profilId: profil.id!,
                  activiteId: activite.id,
                  palier: palier,
                ).copieAvec(niveau: etape),
              );
              final say = SayKit(
                repertoire: RepertoireClips.pourTest(Deck.qc, 'antoine', {}),
                lecteur: LecteurFactice(),
              );
              final capture = GlobalKey();
              await tester.pumpWidget(
                RepaintBoundary(
                  key: capture,
                  child: MultiProvider(
                    providers: [
                      Provider<DepotProgression>.value(value: depot),
                      Provider<SayKit>.value(value: say),
                      Provider<Reglages>.value(value: reglages),
                    ],
                    child: MaterialApp(
                      debugShowCheckedModeBanner: false,
                      theme: themeEnfant(),
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(
                          context,
                        ).copyWith(textScaler: TextScaler.linear(format.texte)),
                        child: child!,
                      ),
                      home: JeuScreen(
                        activite: activite,
                        profil: profil,
                        alea: Random(47),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
              await commencerGuide(tester);
              expect(tester.takeException(), isNull);
              expect(find.bySemanticsLabel('Quitter le jeu'), findsOneWidget);
              if (((Platform.environment['CAPTURES_BASE'] == '1' &&
                          etape == 1) ||
                      (Platform.environment['CAPTURES_NIVEAUX'] == '1' &&
                          etape == 8)) &&
                  ((palier == Palier.a4 && format.taille.width == 320) ||
                      (palier == Palier.a7 && format.taille.width == 844))) {
                await tester.pump(const Duration(milliseconds: 200));
                await tester.runAsync(() async {
                  final image =
                      await (capture.currentContext!.findRenderObject()
                              as RenderRepaintBoundary)
                          .toImage();
                  final octets = await image.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  final dossier = Directory(
                    etape == 8
                        ? '_local/captures-niveaux-2026-10-26'
                        : '_local/captures-base-2026-10-16',
                  )..createSync(recursive: true);
                  await File(
                    '${dossier.path}/${activite.id}-${palier.id}${etape == 8 ? '-n8' : ''}.png',
                  ).writeAsBytes(octets!.buffer.asUint8List());
                  image.dispose();
                });
              }

              final cibles = find.byType(CibleTactile);
              for (var i = 0; i < cibles.evaluate().length; i++) {
                final cible = cibles.at(i);
                if (tester.widget<CibleTactile>(cible).onTap == null) continue;
                final taille = tester.getSize(cible);
                expect(
                  taille.width,
                  greaterThanOrEqualTo(80),
                  reason: 'largeur cible $i',
                );
                expect(
                  taille.height,
                  greaterThanOrEqualTo(80),
                  reason: 'hauteur cible $i',
                );
                await tester.ensureVisible(cible);
                final centre = tester.getCenter(cible);
                expect(
                  (Offset.zero & format.taille).contains(centre),
                  isTrue,
                  reason: 'cible $i inaccessible même après défilement',
                );
              }
              await tester.pumpWidget(const SizedBox());
              await tester.pump();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
