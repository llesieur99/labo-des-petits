import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/modele/manche.dart';
import 'package:jeux_enfants/core/contenu/modele/payloads_moteurs.dart';
import 'package:jeux_enfants/core/contenu/preparer_partie.dart';

void main() {
  test('huit niveaux conservent le troisième historique et le plafond', () {
    final activite = _activiteFixe();
    final etapes = activite.etapesPour(Palier.a4);
    expect(etapes.map((n) => n.numero), [1, 2, 3, 4, 5, 6, 7, 8]);
    expect(etapes[2].nbItems, 4);
    expect(etapes.last.nbItems, 5);
    expect(etapes.last.aides, isEmpty);
  });

  test('les premières et dernières étapes explorent des cas différents', () {
    final activite = _activiteFixe();
    final debut = preparerPartie(
      activite,
      activite.niveauPour(Palier.a4, numero: 1)!,
      Random(47),
    );
    final fin = preparerPartie(
      activite,
      activite.niveauPour(Palier.a4, numero: 8)!,
      Random(47),
    );
    expect(debut.length, 2);
    expect(fin.length, 5);
    expect(
      debut.map((m) => m.id),
      everyElement(isIn([for (var i = 0; i < 8; i++) 'cas$i'])),
    );
    expect(
      fin.map((m) => m.id),
      everyElement(isIn([for (var i = 8; i < 16; i++) 'cas$i'])),
    );
  });
}

Activite _activiteFixe() => Activite(
  id: 'exemple',
  famille: Famille.langue,
  moteur: Moteur.tapPick,
  sensNaturel: Sens.lesDeux,
  titreCle: 'act.exemple.titre',
  illustration: 'act-exemple.svg',
  source: SourceFixe([
    for (var i = 0; i < 16; i++)
      Manche(
        id: 'cas$i',
        clipsConsigne: const ['act.exemple.titre'],
        options: const [
          OptionManche(id: 'chat', concept: 'chat'),
          OptionManche(id: 'chien', concept: 'chien'),
        ],
        bonneOptionId: 'chat',
      ),
  ]),
  clips: const [ClipConsigne('act.exemple.titre', 'Exemple')],
  niveaux: const [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 4, choixMax: 2),
  ],
  payload: const PayloadTapPick(),
  nbItemsMaximum: 5,
);
