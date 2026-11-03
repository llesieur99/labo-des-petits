import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/lettres/chemins_lettres.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m3_trace/trace.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';

/// Le moteur ne parle qu'à travers ce contrat : on enregistre tout.
class _FakeRappels implements RappelsMoteur {
  int reussites = 0;
  int rates = 0;
  final List<String> dits = <String>[];
  Completer<void>? attenteBravo;

  @override
  void itemReussi() => reussites++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async {
    dits.add(clipId);
    if (clipId == 'trace.bravo') await attenteBravo?.future;
  }

  @override
  Future<void> jouerSon(String asset) async {}
}

void main() {
  const lexique = <String, EntreeLexique>{};

  Manche mancheTrace(
    String cheminId, {
    double largeurRuban = 0.3,
    bool departOblige = false,
  }) {
    return Manche(
      id: 'trace.test',
      clipsConsigne: const ['consigne.chemin.g1'],
      donnees: DonneesTrace(
        cheminId: cheminId,
        largeurRuban: largeurRuban,
        departOblige: departOblige,
      ),
    );
  }

  /// Monte le moteur et rend la boîte de la zone de tracé.
  ///
  /// On PUMP (et non pumpAndSettle) : la pastille de départ pulse en boucle
  /// tant que le tracé n'a pas commencé, et pumpAndSettle attendrait une
  /// animation sans fin.
  Future<Rect> monter(
    WidgetTester tester,
    _FakeRappels rappels, {
    required Manche manche,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurTrace(manche: manche, lexique: lexique, rappels: rappels),
        ),
      ),
    );
    await tester.pump();
    return tester.getRect(find.byKey(const ValueKey('trace.zone')));
  }

  /// La géométrie du chemin telle que le moteur la calcule : le test pose le
  /// doigt SUR les points du chemin, exactement comme un enfant qui suit le
  /// ruban.
  GeometrieTrace geometrieDe(Rect zone, Manche manche) {
    final donnees = manche.donnees! as DonneesTrace;
    return GeometrieTrace.pour(
      boite: zone.size,
      trace: cheminsTrace[donnees.cheminId]!,
      largeurRuban: donnees.largeurRuban,
    );
  }

  /// Suit le ruban avec le doigt, du point [de] au point [a] inclus, puis
  /// lève le doigt (le progrès doit rester acquis).
  Future<void> suivreEntre(
    WidgetTester tester,
    Rect zone,
    GeometrieTrace geometrie, {
    required int de,
    required int a,
  }) async {
    final geste = await tester.startGesture(
      zone.topLeft + geometrie.points[de],
    );
    await tester.pump();
    for (var i = de + 1; i <= a; i += 4) {
      await geste.moveTo(zone.topLeft + geometrie.points[i]);
      await tester.pump();
    }
    await geste.moveTo(zone.topLeft + geometrie.points[a]);
    await tester.pump();
    await geste.up();
    await tester.pump();
  }

  testWidgets(
    'toucher le départ puis directement l’arrivée ne réussit pas le tracé',
    (tester) async {
      final rappels = _FakeRappels();
      final manche = mancheTrace('sentier.ligne');
      final zone = await monter(tester, rappels, manche: manche);
      final geometrie = geometrieDe(zone, manche);
      final geste = await tester.startGesture(
        zone.topLeft + geometrie.points.first,
      );
      await tester.pump();
      await geste.moveTo(zone.topLeft + geometrie.points.last);
      await geste.up();
      await tester.pump();
      expect(rappels.reussites, 0);
      await suivreEntre(
        tester,
        zone,
        geometrie,
        de: 0,
        a: geometrie.points.length - 1,
      );
      await tester.pumpAndSettle();
      expect(rappels.reussites, 1);
    },
  );

  testWidgets('suivre le sentier du début à la fin réussit la manche', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    final manche = mancheTrace('sentier.ligne');
    final zone = await monter(tester, rappels, manche: manche);
    final geometrie = geometrieDe(zone, manche);
    final milieu = geometrie.points.length ~/ 2;

    expect(geometrie.points, isNotEmpty);
    expect(rappels.reussites, 0);

    // À mi-chemin, la manche n'est pas gagnée : il faut aller jusqu'au bout.
    await suivreEntre(tester, zone, geometrie, de: 0, a: milieu);
    expect(rappels.reussites, 0);
    expect(rappels.dits, isEmpty);

    // Le doigt s'est levé, puis repart : ce qui est fait reste fait.
    await suivreEntre(
      tester,
      zone,
      geometrie,
      de: milieu,
      a: geometrie.points.length - 1,
    );
    await tester.pumpAndSettle();

    expect(rappels.dits, ['trace.bravo']);
    expect(rappels.reussites, 1);
    // Aucun échec : on ne juge jamais la beauté d'un tracé.
    expect(rappels.rates, 0);

    // Un doigt qui continue après la réussite ne double pas le bravo.
    await suivreEntre(
      tester,
      zone,
      geometrie,
      de: geometrie.points.length - 1,
      a: 0,
    );
    await tester.pumpAndSettle();
    expect(rappels.reussites, 1);
    expect(rappels.dits.length, 1);
  });

  testWidgets('un deuxième doigt ne trace pas à la place du premier', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    final manche = mancheTrace('sentier.ligne');
    final zone = await monter(tester, rappels, manche: manche);
    final geometrie = geometrieDe(zone, manche);
    final premier = await tester.startGesture(
      zone.topLeft + geometrie.depart,
      pointer: 1,
    );
    final second = await tester.startGesture(
      zone.topLeft + geometrie.depart,
      pointer: 2,
    );
    for (var i = 1; i < geometrie.points.length; i += 4) {
      await second.moveTo(zone.topLeft + geometrie.points[i]);
      await tester.pump();
    }
    await second.up();
    expect(rappels.reussites, 0);
    for (var i = 1; i < geometrie.points.length; i += 4) {
      await premier.moveTo(zone.topLeft + geometrie.points[i]);
      await tester.pump();
    }
    await premier.up();
    await tester.pumpAndSettle();
    expect(rappels.reussites, 1);
  });

  testWidgets('un bravo retardé ne réussit pas la nouvelle manche', (
    tester,
  ) async {
    final rappels = _FakeRappels()..attenteBravo = Completer<void>();
    final manche = mancheTrace('sentier.ligne');
    final zone = await monter(tester, rappels, manche: manche);
    final geometrie = geometrieDe(zone, manche);
    await suivreEntre(
      tester,
      zone,
      geometrie,
      de: 0,
      a: geometrie.points.length - 1,
    );
    expect(rappels.dits, ['trace.bravo']);
    await monter(tester, rappels, manche: mancheTrace('sentier.s'));
    rappels.attenteBravo!.complete();
    await tester.pump();
    expect(rappels.reussites, 0);
  });

  testWidgets('toucher loin du ruban ne réussit rien et ne punit rien', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    final manche = mancheTrace('sentier.ligne');
    final zone = await monter(tester, rappels, manche: manche);

    // Le sentier passe au milieu de l'écran : on promène le doigt dans les
    // coins, très loin du ruban.
    final geste = await tester.startGesture(
      zone.topLeft + const Offset(12, 12),
    );
    await tester.pump();
    await geste.moveTo(zone.topRight + const Offset(-12, 12));
    await tester.pump();
    await geste.moveTo(zone.bottomRight + const Offset(-12, -12));
    await tester.pump();
    await geste.moveTo(zone.bottomLeft + const Offset(12, -12));
    await tester.pump();
    await geste.up();
    await tester.pump();

    expect(rappels.reussites, 0);
    expect(rappels.rates, 0);
    expect(rappels.dits, isEmpty);
    // L'écran est toujours là : rien n'a cassé.
    expect(find.byKey(const ValueKey('trace.zone')), findsOneWidget);
  });

  testWidgets('départ obligé : toucher au milieu ne fait rien, puis du départ '
      'jusqu\'au bout réussit', (tester) async {
    final rappels = _FakeRappels();
    final manche = mancheTrace('sentier.ligne', departOblige: true);
    final zone = await monter(tester, rappels, manche: manche);
    final geometrie = geometrieDe(zone, manche);
    final fin = geometrie.points.length - 1;

    // Le doigt se pose au MILIEU du chemin et va jusqu'au bout : sans être
    // passé par la pastille, rien ne progresse et l'item ne se termine pas.
    await suivreEntre(
      tester,
      zone,
      geometrie,
      de: geometrie.points.length ~/ 2,
      a: fin,
    );
    expect(rappels.reussites, 0);
    expect(rappels.dits, isEmpty);
    expect(rappels.rates, 0);

    // Cette fois le doigt part du point de départ marqué : tout s'enchaîne.
    await suivreEntre(tester, zone, geometrie, de: 0, a: fin);
    await tester.pumpAndSettle();
    expect(rappels.reussites, 1);
    expect(rappels.dits, ['trace.bravo']);
    expect(rappels.rates, 0);
  });

  testWidgets('une lettre se suit aussi, point et accent compris', (
    tester,
  ) async {
    // « i » : la tige PUIS son point, deux morceaux dans un seul chemin.
    final rappels = _FakeRappels();
    final manche = mancheTrace('lettre.i');
    final zone = await monter(tester, rappels, manche: manche);
    final geometrie = geometrieDe(zone, manche);
    final fin = geometrie.points.length - 1;

    // La tige seule ne suffit pas : le point du « i » n'est pas tracé.
    await suivreEntre(tester, zone, geometrie, de: 0, a: fin ~/ 2);
    expect(rappels.reussites, 0);

    // Le doigt reprend et va jusqu'au point du « i » : c'est gagné.
    await suivreEntre(tester, zone, geometrie, de: fin ~/ 2, a: fin);
    await tester.pumpAndSettle();

    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  test('chaque chemin du registre se relit et le ruban tient dans le carré', () {
    const boite = Size(400, 600);
    expect(cheminsTrace.length, greaterThanOrEqualTo(32));

    // Les clés réclamées par le contenu (lettre_data, chemin_data,
    // couper_data) : si l'une manque, l'activité s'ouvrirait sur du vide.
    for (final cle in const [
      'sentier.ligne',
      'sentier.s',
      'sentier.boucle',
      'coupe.droite',
      'coupe.zigzag',
      'lettre.o',
      'lettre.c',
      'lettre.s',
      'lettre.u',
      'lettre.l',
      'lettre.a',
      'lettre.e',
      'lettre.i',
      'lettre.m',
      'lettre.n',
      'lettre.r',
      'lettre.d',
      'lettre.p',
      'lettre.b',
      'lettre.q',
      'lettre.t',
      'lettre.f',
      'lettre.v',
      'lettre.w',
      'lettre.y',
      'lettre.k',
      'lettre.x',
    ]) {
      expect(
        cheminsTrace.containsKey(cle),
        isTrue,
        reason: 'chemin « $cle » absent du registre',
      );
    }

    for (final entree in cheminsTrace.entries) {
      final trace = entree.value;
      final ou = 'chemin ${entree.key}';
      expect(trace.id, entree.key, reason: '$ou : la clé et l\'id diffèrent');
      expect(
        trace.svgPath.startsWith('M'),
        isTrue,
        reason: '$ou : un path SVG commence toujours par M',
      );

      final geometrie = GeometrieTrace.pour(
        boite: boite,
        trace: trace,
        largeurRuban: 0.3,
      );

      // Le chemin est exploitable : beaucoup de points, une vraie longueur.
      expect(geometrie.points.length, greaterThan(200), reason: ou);
      expect(geometrie.longueur, greaterThan(80), reason: ou);
      expect(geometrie.indexReussite, greaterThan(200), reason: ou);

      // Le premier point échantillonné est EXACTEMENT le départ écrit dans le
      // registre : c'est là que le doigt commence et que la pastille se pose.
      final departAttendu = Offset(
        geometrie.decalage.dx + trace.departX * geometrie.cote,
        geometrie.decalage.dy + trace.departY * geometrie.cote,
      );
      expect(
        (geometrie.points.first - departAttendu).distance,
        lessThan(0.5),
        reason: '$ou : le départ du registre n\'est pas le premier point',
      );

      // Tout le chemin, ruban compris, tient dans la boîte : rien n'est coupé.
      final encombrement = geometrie.chemin.getBounds().inflate(
        geometrie.ruban / 2,
      );
      expect(encombrement.left, greaterThanOrEqualTo(-0.5), reason: ou);
      expect(encombrement.top, greaterThanOrEqualTo(-0.5), reason: ou);
      expect(
        encombrement.right,
        lessThanOrEqualTo(boite.width + 0.5),
        reason: ou,
      );
      expect(
        encombrement.bottom,
        lessThanOrEqualTo(boite.height + 0.5),
        reason: ou,
      );

      // Le départ le plus proche du coin haut-gauche : la pastille invite le
      // doigt là où la lettre commence (comme le demande le générateur).
      for (final point in geometrie.points) {
        expect(point.dx, greaterThanOrEqualTo(-0.5), reason: ou);
        expect(point.dy, greaterThanOrEqualTo(-0.5), reason: ou);
        expect(point.dx, lessThanOrEqualTo(boite.width + 0.5), reason: ou);
        expect(point.dy, lessThanOrEqualTo(boite.height + 0.5), reason: ou);
      }
    }
  });
}
