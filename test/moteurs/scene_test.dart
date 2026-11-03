import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';
import 'package:jeux_enfants/core/contenu/modele/lexique.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/moteurs/m4_scene/scene.dart';
import 'package:jeux_enfants/core/moteurs/rappels_moteur.dart';
import 'package:jeux_enfants/core/widgets/cible_tactile.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';

/// Rappels enregistreurs : on garde la trace de tout ce que la scène raconte
/// à son hôte (narration dite, item réussi, essai raté).
class FakeRappels implements RappelsMoteur {
  final List<String> clips = [];
  int reussis = 0;
  int rates = 0;

  @override
  void itemReussi() => reussis++;

  @override
  void essaiRate() => rates++;

  @override
  Future<void> dire(String clipId) async => clips.add(clipId);

  @override
  Future<void> jouerSon(String asset) async {}
}

class _RappelsNarration extends FakeRappels implements ConsigneContextuelle {
  final attentes = <Completer<void>>[];
  Future<void> Function()? repeter;
  @override
  Future<void> dire(String clipId) async {
    clips.add(clipId);
    final attente = Completer<void>();
    attentes.add(attente);
    await attente.future;
  }

  @override
  void enregistrerConsigne(
    Object proprietaire,
    Future<void> Function() action,
  ) => repeter = action;
  @override
  void retirerConsigne(Object proprietaire) => repeter = null;
}

class RappelsAvecPause extends FakeRappels implements HorlogeMoteur {
  @override
  bool enPause = false;
  @override
  Future<void> attendre(Duration duree) => Future<void>.delayed(duree);
}

const lexique = <String, EntreeLexique>{
  '2': EntreeLexique(texte: '2'),
  '3': EntreeLexique(texte: '3'),
  '4': EntreeLexique(texte: '4'),
  'visage_content': EntreeLexique(texte: 'content'),
  'visage_triste': EntreeLexique(texte: 'triste'),
  'visage_colere': EntreeLexique(texte: 'fâché'),
  'visage_peur': EntreeLexique(texte: 'peur'),
};

/// Manche « bus » : une étape automatique (le bus se remplit), puis une
/// question (combien de passagers ?). La dernière étape est la question.
const _mancheBus = Manche(
  id: 'bus.passagers',
  clipsConsigne: ['consigne.scene.bus'],
  donnees: DonneesScene(
    decor: 'bus',
    etapes: [
      EtapeScene(narrationCle: 'bus.monte', visuel: 'passagers_2'),
      EtapeScene(
        narrationCle: 'bus.compte',
        options: ['2', '3', '4'],
        bonneOption: '3',
        visuel: 'reponse_ok',
      ),
    ],
  ),
);

/// Manche « milo » : deux visages à reconnaître, une étape après l'autre.
const _mancheMilo = Manche(
  id: 'milo.humeur',
  clipsConsigne: ['consigne.scene.milo'],
  donnees: DonneesScene(
    decor: 'milo',
    etapes: [
      EtapeScene(
        narrationCle: 'milo.tombe',
        options: ['visage_triste', 'visage_content'],
        bonneOption: 'visage_triste',
        visuel: 'visage_triste',
      ),
      EtapeScene(
        narrationCle: 'milo.console',
        options: ['visage_content', 'visage_colere'],
        bonneOption: 'visage_content',
        visuel: 'visage_content',
      ),
    ],
  ),
);

/// Manche « objets » : l'étagère apparaît, puis la question en fait
/// disparaître un objet — le cœur du jeu « Qu'est-ce qui manque ? ».
const _mancheObjets = Manche(
  id: 'objets.manque',
  clipsConsigne: ['consigne.scene.objets'],
  donnees: DonneesScene(
    decor: 'objets',
    etapes: [
      EtapeScene(narrationCle: 'objets.regarde', visuel: 'objets:chat|ballon'),
      EtapeScene(
        narrationCle: 'objets.manque',
        options: ['2', '3', '4'],
        bonneOption: '2',
        visuel: 'objets:chat',
      ),
    ],
  ),
);

/// Manche « maison » : le chat se promène autour de la maison (à côté,
/// derrière, puis devant), et la question attend un doigt.
const _mancheMaison = Manche(
  id: 'maison.place',
  clipsConsigne: ['consigne.scene.maison'],
  donnees: DonneesScene(
    decor: 'maison',
    etapes: [
      EtapeScene(narrationCle: 'maison.acote', visuel: 'chat_acote'),
      EtapeScene(narrationCle: 'maison.derriere', visuel: 'chat_derriere'),
      EtapeScene(narrationCle: 'maison.devant', visuel: 'chat_devant'),
      EtapeScene(
        narrationCle: 'maison.question',
        options: ['2', '3', '4'],
        bonneOption: '2',
      ),
    ],
  ),
);

/// La carte d'une option, retrouvée par ce que l'enfant voit et entend
/// (le mot du lexique, ou le concept à défaut).
Finder _carte(String texte) => find.byWidgetPredicate(
  (widget) => widget is CibleTactile && widget.semantique == texte,
);

/// L'illustration d'un concept posée par un décor : un objet du plateau,
/// la maison ou son chat.
Finder _image(String concept) => find.byWidgetPredicate(
  (widget) => widget is ImageConcept && widget.concept == concept,
);

/// Les concepts des ImageConcept, dans l'ordre de DESSIN : un parent vient
/// avant ses enfants, donc l'ordre est celui des enfants du Stack.
List<String> _ordreDessin() => [
  for (final element in find.byType(ImageConcept).evaluate())
    (element.widget as ImageConcept).concept,
];

Widget _scene(MoteurScene scene) => MaterialApp(home: Scaffold(body: scene));

/// Monte une scène d'un seul visuel et la laisse s'installer : l'étape
/// automatique passe (narration), puis le visuel s'applique et s'anime.
///
/// Chaque pose a sa propre clé : le décor repart donc de son état initial,
/// comme dans un vrai début de manche.
Future<void> _pose(WidgetTester tester, String decor, String visuel) async {
  await tester.pumpWidget(
    _scene(
      MoteurScene(
        key: ValueKey('scene.$decor.$visuel'),
        manche: Manche(
          id: 'essai.$decor',
          clipsConsigne: const ['consigne.scene'],
          donnees: DonneesScene(
            decor: decor,
            etapes: [EtapeScene(narrationCle: 'scene.ecoute', visuel: visuel)],
          ),
        ),
        lexique: lexique,
        rappels: FakeRappels(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 400));
}

/// Le cosinus de l'angle d'une aiguille d'horloge : 1 sur le 12, 0 sur le 3,
/// -1 sur le 6 (la première case de la matrice de rotation du [Transform]).
double _aiguilleCos(WidgetTester tester, Key cle) => tester
    .widget<Transform>(
      find.descendant(of: find.byKey(cle), matching: find.byType(Transform)),
    )
    .transform
    .storage[0];

/// La couleur du rond d'une perle du fil (pas celle de son reflet).
Color _couleurPerle(WidgetTester tester, int rang) {
  final rond = tester.widget<Container>(
    find
        .descendant(
          of: find.byKey(clePerle(rang)),
          matching: find.byType(Container),
        )
        .first,
  );
  return (rond.decoration! as BoxDecoration).color!;
}

/// Le rectangle du bac d'eau (sa surface est son bord supérieur).
Rect _rectBac(WidgetTester tester) => tester.getRect(find.byKey(cleBacEau));

/// La boîte qui contient tous les widgets trouvés par un finder.
Rect _enveloppe(WidgetTester tester, Finder trouve) {
  var boite = tester.getRect(find.byWidget(trouve.evaluate().first.widget));
  for (final element in trouve.evaluate()) {
    boite = boite.expandToInclude(
      tester.getRect(find.byWidget(element.widget)),
    );
  }
  return boite;
}

void main() {
  testWidgets(
    'répéter attend la nouvelle narration avant de quitter la scène',
    (tester) async {
      final rappels = _RappelsNarration();
      await tester.pumpWidget(
        _scene(
          MoteurScene(manche: _mancheBus, lexique: lexique, rappels: rappels),
        ),
      );
      await tester.pump();
      unawaited(rappels.repeter!());
      await tester.pump();
      expect(rappels.attentes, hasLength(2));
      rappels.attentes.first.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_carte('3'), findsNothing);
      rappels.attentes[1].complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 400));
      expect(_carte('3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      for (final attente in rappels.attentes) {
        if (!attente.isCompleted) attente.complete();
      }
      await tester.pump();
    },
  );

  testWidgets('deux essais éclairent la bonne option sans terminer la scène', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurScene(
            manche: _mancheMilo,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      ),
    );
    await tester.pump();
    final bonne = _carte('triste');
    Color bord() =>
        (tester
                    .widget<AnimatedContainer>(
                      find.descendant(
                        of: bonne,
                        matching: find.byType(AnimatedContainer),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .border!
            .top
            .color;
    final initial = bord();
    for (var i = 0; i < 2; i++) {
      await tester.tap(_carte('content'));
      await tester.pump();
    }
    expect(bord(), isNot(initial));
    expect(rappels.reussis, 0);
    await tester.tap(bonne);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'une scène montre les objets pendant toute la période d’observation',
    (tester) async {
      final rappels = FakeRappels();
      const manche = Manche(
        id: 'memoire.observation',
        clipsConsigne: [],
        donnees: DonneesScene(
          decor: 'objets',
          etapes: [
            EtapeScene(
              narrationCle: 'regarde',
              visuel: 'objets:chat|ballon',
              montrerAvant: true,
              observationMs: 4500,
            ),
            EtapeScene(
              narrationCle: 'manque',
              options: ['chat', 'ballon'],
              bonneOption: 'ballon',
              visuel: 'objets:chat',
              montrerAvant: true,
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        _scene(MoteurScene(manche: manche, lexique: lexique, rappels: rappels)),
      );
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (w) => w is ImageConcept && w.concept == 'ballon',
        ),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(rappels.clips, ['regarde']);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(rappels.clips, ['regarde', 'manque']);
      expect(
        find.byWidgetPredicate((w) => w is CibleTactile && w.onTap != null),
        findsNWidgets(2),
      );
    },
  );

  testWidgets('une autre émotion acceptable réussit et reste affichée', (
    tester,
  ) async {
    final rappels = FakeRappels();
    const manche = Manche(
      id: 'milo.alternative',
      clipsConsigne: [],
      donnees: DonneesScene(
        decor: 'milo',
        etapes: [
          EtapeScene(
            narrationCle: 'question',
            options: ['visage_triste', 'visage_colere'],
            bonneOption: 'visage_triste',
            autresBonnesOptions: ['visage_colere'],
            visuel: 'visage_triste',
          ),
        ],
      ),
    );
    await tester.pumpWidget(
      _scene(MoteurScene(manche: manche, lexique: lexique, rappels: rappels)),
    );
    await tester.pump();
    final choix = find.byWidgetPredicate(
      (w) => w is CibleTactile && w.semantique == 'fâché',
    );
    await tester.tap(choix);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is ImageConcept && w.concept == 'visage_colere',
      ),
      findsNWidgets(2),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(rappels.rates, 0);
    expect(rappels.reussis, 1);
  });

  testWidgets('une scène automatique reste en place pendant une interruption', (
    tester,
  ) async {
    final rappels = RappelsAvecPause();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MoteurScene(
            manche: _mancheBus,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      ),
    );
    await tester.pump();
    rappels.enPause = true;
    await tester.pump(const Duration(seconds: 6));
    expect(rappels.clips, isNot(contains('bus.compte')));
    expect(rappels.reussis, 0);
    rappels.enPause = false;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    expect(rappels.clips, isNot(contains('bus.compte')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(rappels.clips, contains('bus.compte'));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'bus : l\'étape automatique enchaîne puis la bonne option réussit',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(manche: _mancheBus, lexique: lexique, rappels: rappels),
        ),
      );
      await tester.pump();

      // L'étape 0 est automatique : pas de carte. Le moteur dit lui-même sa
      // narration et l'ATTEND avant d'enchaîner (jamais de voix coupée).
      expect(find.byType(CibleTactile), findsNothing);
      expect(rappels.clips, ['bus.monte']);

      // Après la narration (~600 ms), le visuel s'applique puis l'étape 1
      // s'ouvre : le moteur dit lui-même la narration de la nouvelle étape.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rappels.clips, ['bus.monte', 'bus.compte']);
      expect(find.byType(CibleTactile), findsNWidgets(3));

      await tester.tap(_carte('3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(rappels.reussis, 1);
      expect(rappels.rates, 0);
      // Manche terminée : plus rien à toucher.
      expect(find.byType(CibleTactile), findsNothing);
    },
  );

  testWidgets(
    'bus : la mauvaise option rate sans avancer, puis la bonne termine',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(manche: _mancheBus, lexique: lexique, rappels: rappels),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(CibleTactile), findsNWidgets(3));

      await tester.tap(_carte('2'));
      await tester.pump();
      expect(rappels.rates, 1);
      expect(rappels.reussis, 0);
      // L'étape reste ouverte, et rien de neuf n'est raconté.
      expect(find.byType(CibleTactile), findsNWidgets(3));
      expect(rappels.clips, ['bus.monte', 'bus.compte']);

      // Le petit clin d'œil d'erreur passe, puis la bonne option réussit.
      await tester.pump(const Duration(milliseconds: 950));
      await tester.tap(_carte('3'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(rappels.rates, 1);
      expect(rappels.reussis, 1);
    },
  );

  testWidgets(
    'milo : mauvaise puis bonne option, la scène ouvre l\'étape suivante '
    'et toutes les cibles font au moins 80 points',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(manche: _mancheMilo, lexique: lexique, rappels: rappels),
        ),
      );
      await tester.pump();

      // Ergonomie enfant : au moins 80 points de côté, toujours.
      for (final element in find.byType(CibleTactile).evaluate()) {
        final taille = tester.getSize(find.byWidget(element.widget));
        expect(taille.width, greaterThanOrEqualTo(80));
        expect(taille.height, greaterThanOrEqualTo(80));
      }

      await tester.tap(_carte('content')); // la mauvaise
      await tester.pump();
      expect(rappels.rates, 1);
      expect(rappels.reussis, 0);
      expect(rappels.clips, isEmpty); // on n'a pas avancé

      await tester.tap(_carte('triste')); // la bonne
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(rappels.clips, ['milo.console']); // la scène a ouvert l'étape 2
      expect(_carte('fâché'), findsOneWidget); // les nouvelles options
      expect(_carte('triste'), findsNothing);

      // Dernière étape : la bonne option termine la manche.
      await tester.tap(_carte('content'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(rappels.reussis, 1);
      expect(rappels.rates, 1);
    },
  );

  testWidgets(
    'le moteur peut dire lui-même la narration de la première étape',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(
            manche: _mancheBus,
            lexique: lexique,
            rappels: rappels,
            direNarrationDepart: true,
          ),
        ),
      );
      await tester.pump();

      expect(rappels.clips, ['bus.monte']);
    },
  );

  testWidgets('les quatre décors se dessinent sans exception', (tester) async {
    for (final decor in ['bus', 'graine', 'ciel', 'milo']) {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(
            manche: Manche(
              id: 'decor.$decor',
              clipsConsigne: const ['consigne.scene'],
              donnees: DonneesScene(
                decor: decor,
                etapes: const [
                  EtapeScene(
                    narrationCle: 'scene.ecoute',
                    visuel: 'etat_inconnu',
                  ),
                ],
              ),
            ),
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(tester.takeException(), isNull, reason: 'décor « $decor »');
      // L'étape visuelle est la dernière : la manche se termine toute seule.
      expect(rappels.reussis, 1, reason: 'décor « $decor »');
    }
  });

  testWidgets('sur un écran de téléphone, les scènes et les cartes tiennent', (
    tester,
  ) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Le pire état de chaque décor, puis une question à toucher.
    const pires = <String, String>{
      'bus': 'passagers_5',
      'graine': 'fleur',
      'ciel': 'lune',
      'milo': 'visage_peur',
    };

    for (final decor in pires.keys) {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(
            manche: Manche(
              id: 'tel.$decor',
              clipsConsigne: const ['consigne.scene'],
              donnees: DonneesScene(
                decor: decor,
                etapes: [
                  EtapeScene(
                    narrationCle: 'scene.ecoute',
                    visuel: pires[decor],
                  ),
                  const EtapeScene(
                    narrationCle: 'scene.choisis',
                    options: ['visage_content', 'visage_triste', 'visage_peur'],
                    bonneOption: 'visage_content',
                  ),
                ],
              ),
            ),
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(tester.takeException(), isNull, reason: 'décor « $decor »');
      expect(
        find.byType(CibleTactile),
        findsNWidgets(3),
        reason: 'décor « $decor »',
      );
      for (final element in find.byType(CibleTactile).evaluate()) {
        final taille = tester.getSize(find.byWidget(element.widget));
        expect(
          taille.width,
          greaterThanOrEqualTo(80),
          reason: 'décor « $decor »',
        );
        expect(
          taille.height,
          greaterThanOrEqualTo(80),
          reason: 'décor « $decor »',
        );
      }
    }
  });

  testWidgets('décor inconnu et manche sans données : repli propre', (
    tester,
  ) async {
    // Un décor que cette version ne dessine pas encore : fond crème et le
    // visuel en simple ImageConcept.
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _scene(
        MoteurScene(
          manche: const Manche(
            id: 'decor.balance',
            clipsConsigne: ['consigne.scene'],
            donnees: DonneesScene(
              decor: 'balance',
              etapes: [
                EtapeScene(
                  narrationCle: 'balance.ecoute',
                  visuel: 'plateau_haut',
                ),
              ],
            ),
          ),
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
    expect(rappels.reussis, 1);

    // Une manche sans données de scène : la scène ne casse pas.
    await tester.pumpWidget(
      _scene(
        MoteurScene(
          manche: const Manche(id: 'sans.donnees', clipsConsigne: ['consigne']),
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CibleTactile), findsNothing);
  });

  testWidgets(
    'objets : le visuel porte la liste, et un objet peut disparaître',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(
            manche: _mancheObjets,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      // Le premier visuel pose l'étagère : 'objets:chat|ballon'.
      expect(_image('chat'), findsOneWidget);
      expect(_image('ballon'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // L'étape automatique passe : la question s'ouvre avec ses cartes.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CibleTactile), findsNWidgets(3));

      // La bonne réponse applique le visuel de la question : le ballon part.
      await tester.tap(_carte('2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(rappels.reussis, 1);
      expect(_image('chat'), findsOneWidget);
      expect(_image('ballon'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'objets : un visuel sans préfixe (ou vide) laisse le plateau vide',
    (tester) async {
      // « etat_inconnu » : un nom que ce décor ne connaît pas. « objets: » :
      // une liste vide. Dans les deux cas : plateau vide, jamais d'exception.
      for (final visuel in ['etat_inconnu', 'objets:']) {
        final rappels = FakeRappels();
        await tester.pumpWidget(
          _scene(
            MoteurScene(
              manche: Manche(
                id: 'objets.$visuel',
                clipsConsigne: const ['consigne.scene'],
                donnees: DonneesScene(
                  decor: 'objets',
                  etapes: [
                    EtapeScene(narrationCle: 'objets.ecoute', visuel: visuel),
                  ],
                ),
              ),
              lexique: lexique,
              rappels: rappels,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));

        expect(tester.takeException(), isNull, reason: 'visuel « $visuel »');
        expect(
          find.byType(ImageConcept),
          findsNothing,
          reason: 'visuel « $visuel »',
        );
        // L'étape visuelle est la dernière : la manche se termine toute seule.
        expect(rappels.reussis, 1, reason: 'visuel « $visuel »');
      }
    },
  );

  testWidgets(
    'maison : le chat change de place d\'une étape à l\'autre, sans exception',
    (tester) async {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(
            manche: _mancheMaison,
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();

      // L'état de départ du décor : le chat dans la maison, à la fenêtre.
      expect(_image('maison'), findsOneWidget);
      expect(_image('chat'), findsOneWidget);
      expect(tester.getSize(_image('chat')).width, 56);

      // Premier visuel : le chat passe à côté de la maison.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      final aCote = tester.getTopLeft(_image('chat'));

      // Deuxième visuel : derrière la maison, plus haut et à droite.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      final derriere = tester.getTopLeft(_image('chat'));
      expect(derriere, isNot(aCote));

      // Derrière : le chat est dessiné AVANT la maison, qui le cache en partie.
      final cache = _ordreDessin();
      expect(cache.indexOf('chat'), lessThan(cache.indexOf('maison')));

      // Troisième visuel : devant la maison, il repasse APRÈS elle.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      final devant = tester.getTopLeft(_image('chat'));
      expect(devant, isNot(derriere));
      final montre = _ordreDessin();
      expect(montre.indexOf('chat'), greaterThan(montre.indexOf('maison')));
      expect(_image('maison'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // La question est ouverte : les cartes attendent un doigt.
      expect(find.byType(CibleTactile), findsNWidgets(3));
    },
  );

  testWidgets('maison : chat_derriere laisse voir le chat ET la maison', (
    tester,
  ) async {
    final rappels = FakeRappels();
    await tester.pumpWidget(
      _scene(
        MoteurScene(
          manche: const Manche(
            id: 'maison.derriere',
            clipsConsigne: ['consigne.scene.maison'],
            donnees: DonneesScene(
              decor: 'maison',
              etapes: [
                EtapeScene(
                  narrationCle: 'maison.derriere',
                  visuel: 'chat_derriere',
                ),
              ],
            ),
          ),
          lexique: lexique,
          rappels: rappels,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(tester.takeException(), isNull);
    // Les deux ImageConcept sont là : le chat est trouvable, la maison aussi.
    expect(_image('chat'), findsOneWidget);
    expect(_image('maison'), findsOneWidget);
    final ordre = _ordreDessin();
    expect(ordre.indexOf('chat'), lessThan(ordre.indexOf('maison')));
    // Étape unique : la manche se termine toute seule.
    expect(rappels.reussis, 1);

    // Un nom de visuel inconnu : la maison seule, sans exception.
    await tester.pumpWidget(
      _scene(
        MoteurScene(
          manche: const Manche(
            id: 'maison.inconnu',
            clipsConsigne: ['consigne.scene.maison'],
            donnees: DonneesScene(
              decor: 'maison',
              etapes: [
                EtapeScene(
                  narrationCle: 'maison.toit',
                  visuel: 'chat_sur_le_toit',
                ),
              ],
            ),
          ),
          lexique: lexique,
          rappels: FakeRappels(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.takeException(), isNull);
    expect(_image('maison'), findsOneWidget);
    expect(_image('chat'), findsNothing);
  });

  testWidgets('sur un écran de téléphone, les deux nouveaux décors tiennent', (
    tester,
  ) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Le pire état de chaque décor : l'étagère pleine, le chat derrière.
    const pires = <String, String>{
      'objets': 'objets:chat|ballon|fleur|pizza',
      'maison': 'chat_derriere',
    };

    for (final decor in pires.keys) {
      final rappels = FakeRappels();
      await tester.pumpWidget(
        _scene(
          MoteurScene(
            manche: Manche(
              id: 'tel.$decor',
              clipsConsigne: const ['consigne.scene'],
              donnees: DonneesScene(
                decor: decor,
                etapes: [
                  EtapeScene(
                    narrationCle: 'scene.ecoute',
                    visuel: pires[decor],
                  ),
                  const EtapeScene(
                    narrationCle: 'scene.choisis',
                    options: ['2', '3', '4'],
                    bonneOption: '2',
                  ),
                ],
              ),
            ),
            lexique: lexique,
            rappels: rappels,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));

      expect(tester.takeException(), isNull, reason: 'décor « $decor »');
      if (decor == 'objets') {
        // Les quatre objets tiennent sur la tablette, chacun bien visible.
        for (final concept in ['chat', 'ballon', 'fleur', 'pizza']) {
          expect(_image(concept), findsOneWidget, reason: 'objet « $concept »');
          expect(
            tester.getSize(_image(concept)).width,
            greaterThanOrEqualTo(48),
            reason: 'objet « $concept »',
          );
        }
      } else {
        expect(_image('maison'), findsOneWidget, reason: 'décor « $decor »');
        expect(_image('chat'), findsOneWidget, reason: 'décor « $decor »');
      }
      expect(
        find.byType(CibleTactile),
        findsNWidgets(3),
        reason: 'décor « $decor »',
      );
      for (final element in find.byType(CibleTactile).evaluate()) {
        final taille = tester.getSize(find.byWidget(element.widget));
        expect(
          taille.width,
          greaterThanOrEqualTo(80),
          reason: 'décor « $decor »',
        );
        expect(
          taille.height,
          greaterThanOrEqualTo(80),
          reason: 'décor « $decor »',
        );
      }
    }
  });

  testWidgets('horloge : les aiguilles se posent selon l\'heure du visuel', (
    tester,
  ) async {
    // Midi : les deux aiguilles sur le 12 (cos = -1 dans la matrice).
    await _pose(tester, 'horloge', 'heure_12');
    expect(find.byKey(cleHorloge), findsOneWidget);
    expect(_aiguilleCos(tester, cleAiguilleHeure), closeTo(-1, 0.001));
    expect(_aiguilleCos(tester, cleAiguilleMinute), closeTo(-1, 0.001));

    // Trois heures : la petite sur le 3, la grande toujours sur le 12.
    await _pose(tester, 'horloge', 'heure_3');
    expect(_aiguilleCos(tester, cleAiguilleHeure), closeTo(0, 0.001));
    expect(_aiguilleCos(tester, cleAiguilleMinute), closeTo(-1, 0.001));

    // Sept heures et demie : la petite sur le 7, la grande sur le 6.
    await _pose(tester, 'horloge', 'heure_7demi');
    expect(
      _aiguilleCos(tester, cleAiguilleHeure),
      closeTo(math.cos(30 * math.pi / 180), 0.001),
    );
    expect(_aiguilleCos(tester, cleAiguilleMinute), closeTo(1, 0.001));

    // Aucun chiffre écrit sur le cadran : que des marques et des aiguilles.
    expect(find.byType(Text), findsNothing);

    // Un nom inconnu (ou une heure impossible) : le repli est midi, sans
    // exception.
    await _pose(tester, 'horloge', 'heure_13');
    expect(tester.takeException(), isNull);
    expect(_aiguilleCos(tester, cleAiguilleHeure), closeTo(-1, 0.001));
    await _pose(tester, 'horloge', 'etat_inconnu');
    expect(tester.takeException(), isNull);
    expect(find.byKey(cleHorloge), findsOneWidget);
  });

  testWidgets('droite : la grenouille se pose sur le bon point, bond compris', (
    tester,
  ) async {
    await _pose(tester, 'droite', 'grenouille_0');
    final zero = tester.getTopLeft(find.byKey(cleGrenouille));
    final tailleDix = tester.getSize(find.byKey(cleGrenouille)).width;
    // Elle n'a pas encore sauté : aucun bond derrière elle.
    expect(find.byKey(cleBond), findsNothing);

    // Sur le point 3 : elle a glissé vers la droite, et son bond est tracé.
    await _pose(tester, 'droite', 'grenouille_3');
    final trois = tester.getTopLeft(find.byKey(cleGrenouille));
    expect(trois.dx, greaterThan(zero.dx));
    expect(trois.dy, closeTo(zero.dy, 1));
    expect(find.byKey(cleBond), findsOneWidget);

    // Les points sont régulièrement espacés : 3 → 7 fait quatre pas de plus.
    await _pose(tester, 'droite', 'grenouille_7');
    final sept = tester.getTopLeft(find.byKey(cleGrenouille));
    expect(sept.dx - trois.dx, closeTo((trois.dx - zero.dx) / 3 * 4, 1));

    // La droite à 20 : les points sont plus serrés, la grenouille plus petite.
    await _pose(tester, 'droite', 'droite20:grenouille_15');
    expect(tester.takeException(), isNull);
    final quinze = tester.getTopLeft(find.byKey(cleGrenouille));
    final tailleVingt = tester.getSize(find.byKey(cleGrenouille)).width;
    expect(quinze.dx, greaterThan(sept.dx));
    expect(tailleVingt, lessThan(tailleDix));

    // Un nom inconnu : elle reste au point 0, sans exception.
    await _pose(tester, 'droite', 'saut_de_grenouille');
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.byKey(cleGrenouille)).dx,
      closeTo(zero.dx, 1),
    );
  });

  testWidgets('gateau : tout entier, en deux parts ou en quatre parts', (
    tester,
  ) async {
    // Entier : aucune ligne de coupe, et les six cerises sont là.
    await _pose(tester, 'gateau', 'gateau_entier');
    expect(find.byKey(cleGateau), findsOneWidget);
    expect(find.byKey(cleCoupeVerticale), findsNothing);
    expect(find.byKey(cleCoupeHorizontale), findsNothing);
    expect(find.byKey(cleCerise(0)), findsOneWidget);
    expect(find.byKey(cleCerise(5)), findsOneWidget);
    expect(find.byKey(cleCerise(6)), findsNothing);

    // Deux parts : une seule ligne, verticale, au centre du gâteau.
    await _pose(tester, 'gateau', 'gateau_2');
    expect(find.byKey(cleCoupeVerticale), findsOneWidget);
    expect(find.byKey(cleCoupeHorizontale), findsNothing);
    expect(
      tester.getRect(find.byKey(cleCoupeVerticale)).center.dx,
      closeTo(tester.getRect(find.byKey(cleGateau)).center.dx, 0.5),
    );

    // Quatre parts : la verticale et l'horizontale.
    await _pose(tester, 'gateau', 'gateau_4');
    expect(find.byKey(cleCoupeVerticale), findsOneWidget);
    expect(find.byKey(cleCoupeHorizontale), findsOneWidget);
    expect(
      tester.getRect(find.byKey(cleCoupeHorizontale)).center.dy,
      closeTo(tester.getRect(find.byKey(cleGateau)).center.dy, 0.5),
    );

    // Un nom inconnu : le gâteau entier, jamais d'exception.
    await _pose(tester, 'gateau', 'gateau_mange');
    expect(tester.takeException(), isNull);
    expect(find.byKey(cleGateau), findsOneWidget);
    expect(find.byKey(cleCoupeVerticale), findsNothing);
  });

  testWidgets(
    'perles : les perles suivent le visuel, la place suivante attend',
    (tester) async {
      await _pose(tester, 'perles', 'perles:rouge|jaune|bleu|vert');
      // Quatre perles enfilées, et la place 5 en pointillé avec son « ? ».
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(clePerle(i)), findsOneWidget, reason: 'perle $i');
      }
      expect(find.byKey(clePerle(4)), findsNothing);
      expect(find.byKey(clePlaceSuivante), findsOneWidget);
      expect(find.text('?'), findsOneWidget);

      // Le fil va de gauche à droite, la place suivante après la dernière perle.
      final premiere = tester.getTopLeft(find.byKey(clePerle(0)));
      final derniere = tester.getTopLeft(find.byKey(clePerle(3)));
      final place = tester.getTopLeft(find.byKey(clePlaceSuivante));
      expect(premiere.dx, lessThan(derniere.dx));
      expect(derniere.dx, lessThan(place.dx));
      expect(derniere.dy, closeTo(premiere.dy, 1));

      // Les concepts de couleurs deviennent des couleurs concrètes.
      expect(_couleurPerle(tester, 0), const Color(0xFFE53935)); // rouge
      expect(_couleurPerle(tester, 1), const Color(0xFFFDD835)); // jaune
      expect(_couleurPerle(tester, 2), const Color(0xFF1E88E5)); // bleu

      // Une couleur inconnue : une perle grise, sans exception.
      await _pose(tester, 'perles', 'perles:mauve');
      expect(tester.takeException(), isNull);
      expect(_couleurPerle(tester, 0), const Color(0xFFBDBDBD));

      // Un fil vide : la place 1 attend, en pointillé.
      await _pose(tester, 'perles', 'perles:');
      expect(tester.takeException(), isNull);
      expect(find.byKey(clePerle(0)), findsNothing);
      expect(find.byKey(clePlaceSuivante), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
    },
  );

  testWidgets('eau : l\'objet tombe, flotte à la surface ou coule au fond', (
    tester,
  ) async {
    // Suspendu au-dessus du bac : « devine avant de vérifier ».
    await _pose(tester, 'eau', 'objet:pomme');
    expect(tester.takeException(), isNull);
    expect(_image('pomme'), findsOneWidget);
    final bacHaut = _rectBac(tester);
    final suspendu = tester.getRect(_image('pomme'));
    expect(suspendu.bottom, lessThan(bacHaut.top)); // au-dessus de la surface
    expect(bacHaut.top - suspendu.bottom, closeTo(20, 1));

    // À la surface : à moitié immergé, coupé par l'eau.
    await _pose(tester, 'eau', 'flotte:pomme');
    final bacSurface = _rectBac(tester);
    final surface = tester.getRect(_image('pomme'));
    expect(surface.center.dy, closeTo(bacSurface.top, 1));
    expect(surface.top, lessThan(bacSurface.top));
    expect(surface.bottom, greaterThan(bacSurface.top));

    // Au fond : entièrement sous la surface.
    await _pose(tester, 'eau', 'coule:pomme');
    final bacFond = _rectBac(tester);
    final fond = tester.getRect(_image('pomme'));
    expect(fond.top, greaterThan(bacFond.top + 20));
    expect(fond.bottom, lessThan(bacFond.bottom));
    expect(bacFond.contains(fond.center), isTrue);

    // Un nom inconnu : le bac seul, sans exception.
    await _pose(tester, 'eau', 'plonge');
    expect(tester.takeException(), isNull);
    expect(find.byKey(cleBacEau), findsOneWidget);
    expect(find.byType(ImageConcept), findsNothing);
  });

  testWidgets('ombre : la lampe décide de la place de l\'ombre', (
    tester,
  ) async {
    // Lampe à gauche : son ombre tombe à DROITE, grande et décalée.
    await _pose(tester, 'ombre', 'lampe_gauche:ballon');
    expect(_image('ballon'), findsOneWidget);
    final objetG = tester.getRect(_image('ballon'));
    final ombreG = tester.getRect(find.byKey(cleOmbre));
    final lampeG = tester.getRect(find.byKey(cleLampe));
    expect(lampeG.center.dx, lessThan(objetG.center.dx));
    expect(ombreG.center.dx, greaterThan(objetG.center.dx + 20));
    expect(ombreG.width, greaterThan(objetG.width * 0.9));

    // Lampe à droite : l'ombre passe à GAUCHE.
    await _pose(tester, 'ombre', 'lampe_droite:ballon');
    final objetD = tester.getRect(_image('ballon'));
    final ombreD = tester.getRect(find.byKey(cleOmbre));
    final lampeD = tester.getRect(find.byKey(cleLampe));
    expect(lampeD.center.dx, greaterThan(objetD.center.dx));
    expect(ombreD.center.dx, lessThan(objetD.center.dx - 20));

    // Lampe au-dessus : l'ombre est courte et tombe SOUS l'objet.
    await _pose(tester, 'ombre', 'lampe_haut:pomme');
    expect(_image('pomme'), findsOneWidget);
    final objetH = tester.getRect(_image('pomme'));
    final ombreH = tester.getRect(find.byKey(cleOmbre));
    final lampeH = tester.getRect(find.byKey(cleLampe));
    expect(ombreH.center.dy, greaterThan(objetH.center.dy));
    expect(ombreH.height, lessThan(objetH.height * 0.7));
    expect(ombreH.center.dx, closeTo(objetH.center.dx, 8));
    expect(lampeH.center.dx, closeTo(objetH.center.dx, 8));
    expect(lampeH.center.dy, lessThan(objetH.center.dy));

    // Un nom inconnu : la scène se tient, lampe comprise, sans exception.
    await _pose(tester, 'ombre', 'lampe_xyz:ballon');
    expect(tester.takeException(), isNull);
    expect(find.byKey(cleLampe), findsOneWidget);
  });

  testWidgets('objets : le séparateur « // » fait deux tas bien séparés', (
    tester,
  ) async {
    // Un écran de téléphone : les deux tas doivent tenir côte à côte.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await _pose(tester, 'objets', 'objets:pomme|pomme|pomme//poisson|poisson');
    expect(tester.takeException(), isNull);

    final pommes = find.byWidgetPredicate(
      (widget) => widget is ImageConcept && widget.concept == 'pomme',
    );
    final poissons = find.byWidgetPredicate(
      (widget) => widget is ImageConcept && widget.concept == 'poisson',
    );
    expect(pommes, findsNWidgets(3));
    expect(poissons, findsNWidgets(2));
    // Les trois pommes sont dessinées d'abord, les deux poissons ensuite.
    expect(_ordreDessin(), ['pomme', 'pomme', 'pomme', 'poisson', 'poisson']);

    // Le grand espace du séparateur passe entre les deux tas (48 points).
    final boitePommes = _enveloppe(tester, pommes);
    final boitePoissons = _enveloppe(tester, poissons);
    expect(boitePoissons.left - boitePommes.right, greaterThanOrEqualTo(47.5));

    // Les deux tas sont posés côte à côte, pas l'un sur l'autre.
    expect(boitePommes.center.dx, lessThan(boitePoissons.center.dx));

    // Tous les objets ont la MÊME taille : c'est ce qui rend les deux tas
    // comparables d'un coup d'œil.
    for (final element in find.byType(ImageConcept).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.width, closeTo(56, 0.5));
      expect(rect.height, closeTo(56, 0.5));
    }

    // Et les deux tas tiennent dans l'écran du téléphone.
    expect(boitePommes.left, greaterThan(0));
    expect(boitePoissons.right, lessThan(390));
  });

  testWidgets('sur un écran de téléphone, les six nouveaux décors tiennent', (
    tester,
  ) async {
    // iPhone 15 Pro : 390 × 844 points.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Un ou deux visuels réalistes par décor, les plus chargés.
    const visuels = <String, List<String>>{
      'horloge': ['heure_7demi', 'heure_12'],
      'droite': ['grenouille_5', 'droite20:grenouille_20'],
      'gateau': ['gateau_4'],
      'perles': ['perles:rouge|jaune|bleu|vert|violet|orange|rouge|jaune'],
      'eau': ['flotte:pomme', 'objet:ballon'],
      'ombre': ['lampe_gauche:ballon', 'lampe_droite:pomme'],
    };

    for (final decor in visuels.keys) {
      for (final visuel in visuels[decor]!) {
        final rappels = FakeRappels();
        await tester.pumpWidget(
          _scene(
            MoteurScene(
              key: ValueKey('tel.$decor.$visuel'),
              manche: Manche(
                id: 'tel.$decor',
                clipsConsigne: const ['consigne.scene'],
                donnees: DonneesScene(
                  decor: decor,
                  etapes: [
                    EtapeScene(narrationCle: 'scene.ecoute', visuel: visuel),
                    const EtapeScene(
                      narrationCle: 'scene.choisis',
                      options: ['2', '3', '4'],
                      bonneOption: '2',
                      visuel: 'reponse_ok',
                    ),
                  ],
                ),
              ),
              lexique: lexique,
              rappels: rappels,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pump(const Duration(milliseconds: 400));

        final raison = 'décor « $decor » ($visuel)';
        expect(tester.takeException(), isNull, reason: raison);
        // La question est ouverte : trois cartes, assez grandes pour un doigt.
        expect(find.byType(CibleTactile), findsNWidgets(3), reason: raison);
        for (final element in find.byType(CibleTactile).evaluate()) {
          final taille = tester.getSize(find.byWidget(element.widget));
          expect(taille.width, greaterThanOrEqualTo(80), reason: raison);
          expect(taille.height, greaterThanOrEqualTo(80), reason: raison);
        }

        // La bonne réponse applique 'reponse_ok' : un nom que le décor ne
        // connaît pas — il doit le laisser passer sans rien casser.
        await tester.tap(_carte('2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull, reason: raison);
        expect(rappels.reussis, 1, reason: raison);
        expect(rappels.rates, 0, reason: raison);
      }
    }
  });
}
