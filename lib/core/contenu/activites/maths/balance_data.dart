import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 9 — La balance du marché (moteur M9).
///
/// L'enfant pose des fruits jusqu'à ce que les deux plateaux soient égaux.
/// L'égalité arrive bien avant le signe =.
class BalanceGenerateur extends GenerateurManches {
  const BalanceGenerateur();

  static const _fruits = ['pomme', 'banane', 'fraise', 'raisin', 'orange'];

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    // Compter jusqu'à 2 puis 4 à 4 ans ; jusqu'à 7 à 7 ans.
    final minimum = 2 + niveau.palier.index + (niveau.numero - 1) ~/ 3;
    final varietes = min(5, 1 + niveau.palier.index + niveau.numero ~/ 2);
    return [
      for (var i = 0; i < niveau.nbItems; i++)
        _manche(minimum, varietes, niveau.numero, i, alea),
    ];
  }

  Manche _manche(int minimum, int varietes, int numero, int i, Random alea) {
    final fruits = List.of(_fruits)..shuffle(alea);
    // Une quantité paire permet de tout partager. Une quantité impaire oblige
    // à laisser un fruit : l'égalité ne signifie pas vider la réserve.
    final surplus = numero <= 2 ? 0 : (i + numero) % 3;
    final reserve = [
      for (var f = 0; f < minimum * 2 + surplus; f++) fruits[f % varietes],
    ]..shuffle(alea);
    return Manche(
      id: 'balance.$minimum.${reserve.join('-')}.$i',
      clipsConsigne: const ['consigne.balance.g1'],
      donnees: DonneesBalance(
        reserve: reserve,
        minimumParPlateau: minimum,
        pencheCle: 'consigne.balance.penche',
        egalCle: 'consigne.balance.egal',
      ),
    );
  }
}

const clipsBalance = <ClipConsigne>[
  ClipConsigne('act.balance.titre', 'La balance du marché'),
  ClipConsigne(
    'consigne.balance.g1',
    'Mets le même nombre de fruits dans chaque plateau. La balance doit être bien droite !',
  ),
  ClipConsigne(
    'consigne.balance.penche',
    'Ça penche ! Ajoute ou enlève des fruits.',
  ),
  ClipConsigne(
    'consigne.balance.egal',
    'C\'est égal ! La balance est bien droite !',
  ),
];

const activiteBalance = Activite(
  id: 'balance',
  famille: Famille.maths,
  moteur: Moteur.balance,
  sensNaturel: Sens.paysage,
  titreCle: 'act.balance.titre',
  illustration: 'act-balance.svg',
  source: SourceGenerateur(BalanceGenerateur()),
  clips: clipsBalance,
  nbItemsMaximum: 4,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 3, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 4, choixMax: 2),
    Niveau(palier: Palier.a6, numero: 1, nbItems: 4, choixMax: 3),
    Niveau(palier: Palier.a7, numero: 1, nbItems: 4, choixMax: 3),
  ],
  payload: PayloadBalance(),
);
