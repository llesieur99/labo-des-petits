import 'dart:math';

import '../../modele/activite.dart';
import '../../modele/donnees_manche.dart';
import '../../modele/manche.dart';
import '../../modele/payloads_moteurs.dart';

/// Activité 14 — Mettre la table (moteur M2, appariement un pour un).
///
/// « Une assiette par personne » : l'enfant donne une assiette à chaque ami.
/// C'est la correspondance un-pour-un, la base du nombre — avant tout chiffre.
class TableGenerateur extends GenerateurManches {
  const TableGenerateur();

  @override
  List<Manche> generer(Niveau niveau, Random alea) {
    final manches = <Manche>[];
    final progression = niveau.numero.clamp(1, 8) - 1;
    final objets = [
      'assiette',
      if (progression >= 1 || niveau.palier.age >= 5) 'verre',
      if (progression >= 4) 'fourchette',
    ]..shuffle(alea);
    final maximum = (niveau.choixMax + (progression >= 2 ? 1 : 0)).clamp(
      2,
      niveau.palier == Palier.a4 ? 3 : 5,
    );

    for (var i = 0; i < niveau.nbItems; i++) {
      // On change l'objet et le nombre d'invités entre les manches :
      // l'enfant doit refaire la correspondance, sans cliquer par habitude.
      final objet = objets[i % objets.length];
      final nbAmis = progression < 3
          ? maximum
          : 2 + (i + progression) % (maximum - 1);
      final emplacements = [
        for (var a = 1; a <= nbAmis; a++)
          EmplacementDepot(id: 'ami$a', concept: 'enfant'),
      ];
      final objetsBarre = [for (var o = 1; o <= nbAmis; o++) objet];
      final places = <String, List<String>>{
        for (final e in emplacements) e.id: [objet],
      };

      manches.add(
        Manche(
          id: 'table.$objet.$nbAmis.$i',
          clipsConsigne: ['consigne.table.$objet'],
          options: [
            for (var o = 1; o <= nbAmis; o++)
              OptionManche(id: '$objet$o', concept: objet),
          ],
          donnees: DonneesDepot(
            emplacements: emplacements,
            objets: List.of(objetsBarre)..shuffle(alea),
            places: places,
          ),
        ),
      );
    }
    return manches;
  }
}

const clipsTable = <ClipConsigne>[
  ClipConsigne('act.table.titre', 'Mettre la table'),
  ClipConsigne('consigne.table.assiette', 'Donne une assiette à chaque ami.'),
  ClipConsigne('consigne.table.verre', 'Donne un verre à chaque ami.'),
  ClipConsigne(
    'consigne.table.fourchette',
    'Donne une fourchette à chaque ami.',
  ),
];

const activiteTable = Activite(
  id: 'table',
  famille: Famille.autonomie,
  moteur: Moteur.dropPlace,
  sensNaturel: Sens.paysage,
  titreCle: 'act.table.titre',
  illustration: 'act-table.svg',
  source: SourceGenerateur(TableGenerateur()),
  clips: clipsTable,
  niveaux: [
    Niveau(palier: Palier.a4, numero: 1, nbItems: 5, choixMax: 2),
    Niveau(palier: Palier.a5, numero: 1, nbItems: 6, choixMax: 3),
    Niveau(
      palier: Palier.a6,
      numero: 1,
      nbItems: 6,
      choixMax: 3,
      afficherMots: true,
    ),
    Niveau(
      palier: Palier.a7,
      numero: 1,
      nbItems: 8,
      choixMax: 4,
      afficherMots: true,
    ),
  ],
  payload: PayloadDropPlace(),
);
