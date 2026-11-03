import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/micro/mic_kit.dart';
import 'package:jeux_enfants/core/moteurs/m6_rythme/rythme.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';

import '../support/micro_controle.dart';

const _tambour = 'assets/audio/neutre/sons/tambour.wav';
const _grogne = 'assets/audio/neutre/sons/grogne.wav';
const _ronflement = 'assets/audio/neutre/sons/ronflement.wav';
const _aiguFort = 'assets/audio/neutre/sons/aigu_fort.wav';
const _graveDoux = 'assets/audio/neutre/sons/grave_doux.wav';

/// Le moteur ne parle qu'à travers ce contrat : on enregistre tout — les
/// clips dits ET les sons non verbaux (tambour, grogne, grelot…).
class _FakeRappels implements RappelsMoteur {
  int reussites = 0;
  int rates = 0;
  final List<String> dits = <String>[];
  final List<String> sons = <String>[];

  @override
  void itemReussi() => reussites++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async => dits.add(clipId);

  @override
  Future<void> jouerSon(String asset) async => sons.add(asset);
}

class _RappelsPause extends _FakeRappels implements HorlogeMoteur {
  @override
  bool enPause = false;
  @override
  Future<void> attendre(Duration duree) => Future<void>.delayed(duree);
}

class _RappelsReaction extends _FakeRappels {
  final attente = Completer<void>();
  @override
  Future<void> dire(String clipId) async {
    dits.add(clipId);
    if (clipId == 'reaction.miaou') await attente.future;
  }
}

const _lexique = <String, EntreeLexique>{
  'oiseau': EntreeLexique(texte: 'oiseau'),
  'chat': EntreeLexique(texte: 'chat'),
};

/// Un micro factice : il note ce que le moteur lui demande (la durée, le
/// chemin rejoué, le chemin effacé) et sait refuser ou tomber en panne.
class _MicroEspion implements Micro {
  _MicroEspion({this.accorde = true, this.panne = false});

  bool accorde;
  bool panne;
  Duration? dureeDemandee;
  int enregistrements = 0;
  final List<String> rejoues = <String>[];
  final List<String> effaces = <String>[];

  @override
  Future<bool> estAccorde() async => accorde;

  @override
  Future<bool> demander() async => accorde = true;

  @override
  Future<String?> enregistrer({required Duration max}) async {
    dureeDemandee = max;
    if (panne) throw StateError('micro en panne');
    if (!accorde) return null;
    return '/factice/voix_${++enregistrements}.m4a';
  }

  @override
  Future<void> rejouer(String chemin) async => rejoues.add(chemin);

  @override
  Future<void> effacer(String chemin) async => effaces.add(chemin);

  @override
  Future<void> nettoyer() async {}
}

/// Le monstre du bercement : jamais une erreur, même si l'illustration
/// n'existe pas dans les tests.
String _conceptDuMonstre(WidgetTester tester) =>
    tester.widget<ImageConcept>(find.byType(ImageConcept)).concept;

Manche _manchePulsation({int battements = 4, int intervalleMs = 900}) => Manche(
  id: 'rythme.pas',
  clipsConsigne: const ['consigne.pas'],
  donnees: DonneesRythme(
    mode: ModeRythme.pulsation,
    battements: battements,
    intervalleMs: intervalleMs,
  ),
);

Manche _mancheBercement({int? caresses, int? attenteMs}) => Manche(
  id: 'rythme.monstre',
  clipsConsigne: const ['consigne.monstre'],
  donnees: DonneesRythme(
    mode: ModeRythme.bercement,
    battements: caresses,
    intervalleMs: attenteMs,
  ),
);

Manche _mancheEcoute() => const Manche(
  id: 'rythme.sons',
  clipsConsigne: ['consigne.ecoute'],
  options: [
    OptionManche(id: 'oiseau', concept: 'oiseau'),
    OptionManche(id: 'chat', concept: 'chat'),
  ],
  donnees: DonneesRythme(
    mode: ModeRythme.ecoute,
    bonneOption: 'oiseau',
    sonsParOption: {'oiseau': _aiguFort, 'chat': _graveDoux},
  ),
);

Manche _mancheEcho() => const Manche(
  id: 'rythme.bouche',
  clipsConsigne: ['consigne.bouche'],
  donnees: DonneesRythme(
    mode: ModeRythme.echo,
    sonCle: 'son.sss',
    animalConcept: 'chat',
    reactionCle: 'reaction.miaou',
  ),
);

Manche _mancheSyllabes() => const Manche(
  id: 'rythme.papillon',
  clipsConsigne: ['consigne.syllabes'],
  donnees: DonneesRythme(
    mode: ModeRythme.syllabes,
    motCle: 'lex.papillon',
    syllabesClips: ['syl.pa', 'syl.pi', 'syl.yon'],
  ),
);

void main() {
  Future<void> monter(
    WidgetTester tester,
    _FakeRappels rappels,
    Manche manche, {
    Micro? micro,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurRythme(
            manche: manche,
            lexique: _lexique,
            rappels: rappels,
            micro: micro,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// L'état du moteur : sert à lire le tempo courant du tambour.
  MoteurRythmeEtat etat(WidgetTester tester) =>
      tester.state<MoteurRythmeEtat>(find.byType(MoteurRythme));

  /// Laisse la phase 1 des syllabes se dérouler (le mot, puis chaque syllabe
  /// avec son saut) : chaque syllabe prend un peu de temps.
  Future<void> deroulerPhase1(WidgetTester tester, int nbSyllabes) async {
    for (var i = 0; i <= nbSyllabes; i++) {
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  for (final fermer in [true, false]) {
    testWidgets(
      'micro éphémère : ${fermer ? "fermeture en cours" : "échec de lecture"}',
      (tester) async {
        final micro = MicroControle(panneLecture: !fermer);
        final rappels = _FakeRappels();
        await monter(tester, rappels, _mancheEcho(), micro: micro);
        await tester.tap(find.byKey(const ValueKey('rythme.ecouteToi')));
        await tester.pump();
        expect(micro.fichiers, hasLength(1));
        if (fermer) await tester.pumpWidget(const SizedBox());
        micro.attente.complete();
        await tester.pump();
        await tester.pump();
        expect(micro.fichiers, isEmpty);
        if (fermer) expect(micro.rejoues, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('la caresse montre le temps à attendre sans texte', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheBercement());
    double progression() => tester
        .widget<CircularProgressIndicator>(
          find.descendant(
            of: find.byKey(const ValueKey('rythme.attenteCaresse')),
            matching: find.byType(CircularProgressIndicator),
          ),
        )
        .value!;
    expect(progression(), 0);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(progression(), 1);
    await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
    await tester.pump();
    expect(progression(), 0);
    expect(rappels.rates, 0);
  });

  testWidgets('une ancienne réaction ne gagne pas la manche suivante', (
    tester,
  ) async {
    final rappels = _RappelsReaction();
    await monter(tester, rappels, _mancheEcho());
    await tester.tap(find.byKey(const ValueKey('rythme.jaiEssaye')));
    await tester.pump();
    await monter(tester, rappels, _mancheEcoute());
    rappels.attente.complete();
    await tester.pump();
    expect(rappels.reussites, 0);
  });

  testWidgets('la pause conserve le dernier saut des syllabes', (tester) async {
    final rappels = _RappelsPause();
    await monter(tester, rappels, _mancheSyllabes());
    await deroulerPhase1(tester, 3);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('rythme.syllabe')));
      await tester.pump();
    }
    rappels.enPause = true;
    await tester.pump(const Duration(seconds: 2));
    expect(rappels.reussites, 0);
    rappels.enPause = false;
    await tester.pump(const Duration(milliseconds: 320));
    expect(rappels.reussites, 1);
  });

  // ───────────────────────────── mode pulsation ─────────────────────────────

  testWidgets('le tambour bat tout seul, à intervalles réguliers', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manchePulsation());

    // Le premier coup part avec la manche : l'enfant entend le tempo.
    expect(rappels.sons, [_tambour]);

    await tester.pump(const Duration(milliseconds: 900));
    expect(rappels.sons, [_tambour, _tambour]);

    await tester.pump(const Duration(milliseconds: 900));
    expect(rappels.sons.length, 3);

    // Le tambour est un gros rond (au moins 140 points) et il est seul.
    final taille = tester.getSize(find.byKey(const ValueKey('rythme.tambour')));
    expect(taille.width, greaterThanOrEqualTo(140));
    expect(taille.height, greaterThanOrEqualTo(140));
  });

  testWidgets('des tapes bien placées remplissent la manche sans ralentir', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manchePulsation(battements: 3));

    // Une tape juste après chaque coup : le tempo ne bouge pas.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 900));
      await tester.tap(find.byKey(const ValueKey('rythme.tambour')));
      await tester.pump();
    }

    expect(rappels.reussites, 1);
    expect(rappels.rates, 0); // aucune punition, jamais
    expect(etat(tester).intervalleCourantMs, 900);
  });

  testWidgets('des tapes décalées font ralentir le tambour — sans gronder', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _manchePulsation(battements: 4));
    expect(etat(tester).intervalleCourantMs, 900);

    // Une tape au milieu du battement : elle se perd, le tempo ralentit.
    await tester.pump(const Duration(milliseconds: 450));
    await tester.tap(find.byKey(const ValueKey('rythme.tambour')));
    await tester.pump();

    final ralenti = etat(tester).intervalleCourantMs;
    expect(ralenti, greaterThan(900));

    // Puis l'enfant retape bien, juste après le coup suivant : le tempo
    // reste où il est — il ne remonte jamais tout seul, et personne ne
    // gronde l'enfant pour la tape perdue.
    await tester.pump(const Duration(milliseconds: 620));
    await tester.tap(find.byKey(const ValueKey('rythme.tambour')));
    await tester.pump();
    expect(etat(tester).intervalleCourantMs, ralenti);
    expect(rappels.rates, 0);
  });

  // ───────────────────────────── mode bercement ─────────────────────────────

  testWidgets('huit caresses lentes endorment le monstre', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheBercement());

    expect(_conceptDuMonstre(tester), 'monstre');

    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
      await tester.pump();
    }

    expect(rappels.reussites, 1);
    expect(rappels.sons, contains(_ronflement));
    expect(rappels.rates, 0);
    expect(_conceptDuMonstre(tester), 'monstre_dodo');
  });

  testWidgets('le bercement suit le nombre et le tempo du niveau', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(
      tester,
      rappels,
      _mancheBercement(caresses: 4, attenteMs: 700),
    );

    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
      await tester.pump();
    }
    expect(rappels.reussites, 0);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
    await tester.pump();
    expect(rappels.reussites, 1);
  });

  testWidgets('une tape trop vive réveille le monstre, sans rien perdre', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheBercement());

    // Une caresse lente : le monstre s'assoupit.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
    await tester.pump();
    expect(_conceptDuMonstre(tester), 'monstre_dodo');

    // Tout de suite après : le monstre se réveille en grognant…
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
    await tester.pump();
    expect(rappels.sons, contains(_grogne));
    expect(_conceptDuMonstre(tester), 'monstre');
    expect(rappels.rates, 0);
    expect(rappels.reussites, 0);

    // … mais le compteur de sommeil n'a PAS descendu : il reste sept
    // caresses lentes à donner (une + six = sept → pas encore gagné).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
      await tester.pump();
    }
    expect(rappels.reussites, 0);

    await tester.pump(const Duration(milliseconds: 1200));
    await tester.tap(find.byKey(const ValueKey('rythme.caresse')));
    await tester.pump();
    expect(rappels.reussites, 1);
  });

  // ─────────────────────────────── mode ecoute ───────────────────────────────

  testWidgets(
    'le son du bon choix part au démarrage, puis sur « écouter encore »',
    (tester) async {
      final rappels = _FakeRappels();
      await monter(tester, rappels, _mancheEcoute());

      expect(rappels.sons, [_aiguFort]);

      final bouton = find.byKey(const ValueKey('rythme.ecouter'));
      expect(tester.getSize(bouton).width, greaterThanOrEqualTo(80));

      await tester.tap(bouton);
      await tester.pump();
      expect(rappels.sons, [_aiguFort, _aiguFort]);
    },
  );

  testWidgets('la mauvaise carte rate, la bonne gagne', (tester) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheEcoute());

    await tester.tap(find.byKey(const ValueKey('rythme.option.chat')));
    await tester.pump();
    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);

    await tester.tap(find.byKey(const ValueKey('rythme.option.oiseau')));
    await tester.pump();
    expect(rappels.reussites, 1);
    expect(rappels.dits, isEmpty); // les cartes ne parlent pas : le son parle
  });

  // ──────────────────────────────── mode echo ────────────────────────────────

  testWidgets('l\'animal écoute le son, l\'enfant essaie, l\'animal réagit', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheEcho());

    // Le son à reproduire est dit au démarrage de la manche.
    expect(rappels.dits, ['son.sss']);

    // On peut le réécouter autant de fois qu'on veut.
    await tester.tap(find.byKey(const ValueKey('rythme.ecouter')));
    await tester.pump();
    expect(rappels.dits, ['son.sss', 'son.sss']);

    // Sans micro : « J'ai essayé ! » suffit — le son n'est JAMAIS jugé.
    expect(find.byKey(const ValueKey('rythme.ecouteToi')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rythme.jaiEssaye')));
    await tester.pumpAndSettle();

    expect(rappels.dits, ['son.sss', 'son.sss', 'reaction.miaou']);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  testWidgets(
    'avec un micro : « écoute-toi » enregistre, rejoue, efface, puis l\'animal réagit',
    (tester) async {
      final rappels = _FakeRappels();
      final micro = _MicroEspion();
      await monter(tester, rappels, _mancheEcho(), micro: micro);

      expect(find.byKey(const ValueKey('rythme.ecouteToi')), findsOneWidget);
      expect(find.byKey(const ValueKey('rythme.jaiEssaye')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('rythme.ecouteToi')));
      await tester.pumpAndSettle();

      // Trois secondes au plus, rejouées telles quelles, puis effacées :
      // aucun jugement, aucune reconnaissance, rien qui reste sur l'appareil.
      expect(micro.dureeDemandee, const Duration(seconds: 3));
      expect(micro.rejoues, ['/factice/voix_1.m4a']);
      expect(micro.effaces, ['/factice/voix_1.m4a']);
      expect(rappels.dits, ['son.sss', 'reaction.miaou']);
      expect(rappels.reussites, 1);
    },
  );

  testWidgets('un micro sans accord ne bloque jamais l\'enfant', (
    tester,
  ) async {
    // Sans accord : l'enregistrement rend null, rien n'est rejoué, et
    // l'enfant termine sa manche sans même s'en apercevoir.
    final rappels = _FakeRappels();
    final micro = _MicroEspion(accorde: false);
    await monter(tester, rappels, _mancheEcho(), micro: micro);

    await tester.tap(find.byKey(const ValueKey('rythme.ecouteToi')));
    await tester.pumpAndSettle();

    expect(micro.rejoues, isEmpty);
    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('un micro en panne ne bloque jamais l\'enfant', (tester) async {
    final rappels = _FakeRappels();
    await monter(
      tester,
      rappels,
      _mancheEcho(),
      micro: _MicroEspion(panne: true),
    );

    await tester.tap(find.byKey(const ValueKey('rythme.ecouteToi')));
    await tester.pumpAndSettle();

    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  // ────────────────────────────── mode syllabes ──────────────────────────────

  testWidgets('la grenouille saute les syllabes, puis l\'enfant les tape', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheSyllabes());

    // Pendant que l'app parle, les tapes ne comptent pas.
    await tester.tap(find.byKey(const ValueKey('rythme.syllabe')));
    await tester.pump();
    expect(rappels.reussites, 0);

    // Phase 1 : le mot, puis chaque syllabe — la grenouille saute.
    await deroulerPhase1(tester, 3);
    expect(rappels.dits, ['lex.papillon', 'syl.pa', 'syl.pi', 'syl.yon']);

    // Phase 2 : une tape par syllabe.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('rythme.syllabe')));
      await tester.pump();
    }
    expect(rappels.reussites, 0); // la grenouille atterrit d'abord
    await tester.pump(const Duration(milliseconds: 400));

    expect(rappels.reussites, 1);
    expect(rappels.rates, 0);
  });

  testWidgets('une tape en trop fait refaire le mot, doucement', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    await monter(tester, rappels, _mancheSyllabes());
    await deroulerPhase1(tester, 3);

    // Quatre tapes pour trois syllabes : un encouragement doux, et la
    // grenouille revient au départ — la manche n'est pas perdue.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byKey(const ValueKey('rythme.syllabe')));
      await tester.pump();
    }
    expect(rappels.rates, 1);
    expect(rappels.reussites, 0);

    // Le mot se rejoue tout de suite : trois tapes propres et c'est gagné.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('rythme.syllabe')));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(rappels.reussites, 1);
  });

  // ─────────────────────────────── ergonomie ───────────────────────────────

  testWidgets('chaque mode offre des cibles d\'au moins 80 points', (
    tester,
  ) async {
    final rappels = _FakeRappels();
    const claviers = <String, List<String>>{
      'rythme.tambour': ['rythme.tambour'],
      'rythme.caresse': ['rythme.caresse'],
      'rythme.ecouter': ['rythme.ecouter', 'rythme.option.oiseau'],
      'rythme.jaiEssaye': ['rythme.ecouter', 'rythme.jaiEssaye'],
      'rythme.syllabe': ['rythme.syllabe'],
    };
    final manches = <String, Manche>{
      'rythme.tambour': _manchePulsation(),
      'rythme.caresse': _mancheBercement(),
      'rythme.ecouter': _mancheEcoute(),
      'rythme.jaiEssaye': _mancheEcho(),
      'rythme.syllabe': _mancheSyllabes(),
    };

    for (final entree in claviers.entries) {
      await monter(tester, rappels, manches[entree.key]!);
      for (final cle in entree.value) {
        final taille = tester.getSize(find.byKey(ValueKey(cle)));
        expect(
          taille.width,
          greaterThanOrEqualTo(80),
          reason: '$cle est trop petit en largeur (${taille.width})',
        );
        expect(
          taille.height,
          greaterThanOrEqualTo(80),
          reason: '$cle est trop petit en hauteur (${taille.height})',
        );
      }
    }
  });
}
