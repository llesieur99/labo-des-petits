import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/micro/mic_kit.dart';
import 'package:jeux_enfants/core/parent/reglages.dart';
import 'package:jeux_enfants/core/progression/depot_memoire.dart';
import 'package:jeux_enfants/features/parent/parent_screen.dart';
import 'package:jeux_enfants/features/shell/shell_controller.dart';
import 'package:jeux_enfants/theme/theme_enfant.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PermissionMicro extends MicroFactice {
  final reponse = Completer<bool>();

  @override
  Future<bool> demander() {
    demandes++;
    return reponse.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Andika',
    )..addFont(rootBundle.load('assets/fonts/Andika-Regular.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final format in [
    (nom: 'iphone', taille: const Size(390, 844), texte: 1.0),
    (nom: 'petit-grand-texte', taille: const Size(320, 568), texte: 2.0),
  ]) {
    for (final accepte in [false, true]) {
      testWidgets(
        'le parent ${accepte ? 'accepte' : 'refuse'} la permission système ${format.nom}',
        (tester) async {
          tester.view.physicalSize = format.taille;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final reglages = await Reglages.charger();
          final shell = ShellController(
            depot: DepotMemoire(),
            reglages: reglages,
          );
          await shell.initialiser();
          addTearDown(shell.dispose);
          final micro = _PermissionMicro();
          final capture = GlobalKey();
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                Provider<Reglages>.value(value: reglages),
                Provider<Micro>.value(value: micro),
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
                  home: const ParentScreen(),
                ),
              ),
            ),
          );
          final continuer = find.text('Continuer');
          await tester.scrollUntilVisible(continuer, 200);
          await tester.pumpAndSettle();
          expect(micro.demandes, 0);
          expect(reglages.microAutorise, isFalse);
          expect(find.text('Autoriser le micro'), findsNothing);
          if (!accepte && Platform.environment['CAPTURES_MICRO'] == '1') {
            await _capturer(tester, capture, '${format.nom}-avant');
          }
          await tester.tap(continuer);
          await tester.pump();
          expect(micro.demandes, 1);
          expect(
            reglages.microAutorise,
            isFalse,
            reason: 'Continuer ne vaut pas consentement système',
          );

          micro.reponse.complete(accepte);
          await tester.pumpAndSettle();
          expect(reglages.microAutorise, accepte);
          if (!accepte) {
            final message = find.textContaining('continuer à jouer sans micro');
            await tester.scrollUntilVisible(message, 150);
            await tester.pumpAndSettle();
            expect(message, findsOneWidget);
            expect(
              micro.demandes,
              1,
              reason: 'aucune relance automatique après refus',
            );
            if (Platform.environment['CAPTURES_MICRO'] == '1') {
              await _capturer(tester, capture, '${format.nom}-refus');
            }
          } else {
            expect(find.text('Le micro est autorisé'), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

Future<void> _capturer(WidgetTester tester, GlobalKey key, String nom) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dossier = Directory('_local/publication/captures-micro');
    await dossier.create(recursive: true);
    await File(
      '${dossier.path}/$nom.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
