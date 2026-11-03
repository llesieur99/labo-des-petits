import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/contenu/activites/langue/rimes_data.dart';
import 'package:jeux_enfants/core/contenu/catalogue.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/validateur.dart';
import 'package:jeux_enfants/core/contenu/activites/logique/code_data.dart';
import 'package:jeux_enfants/core/contenu/modele/donnees_manche.dart';

void main() {
  test('le code compte les déplacements, le virage et le ramassage', () {
    DonneesCode parcours(int blocs) => DonneesCode(
      taille: 4,
      departX: 0,
      departY: 0,
      objectifX: 2,
      objectifY: 2,
      animal: 'souris',
      ramassable: 'pomme',
      maxBlocs: blocs,
    );
    expect(codeEstRealisable(parcours(4)), isFalse);
    expect(codeEstRealisable(parcours(5)), isFalse);
    expect(codeEstRealisable(parcours(6)), isTrue);
  });

  test('à 4 et 5 ans, le code donne seulement les parcours courts', () {
    for (final palier in [Palier.a4, Palier.a5]) {
      for (var graine = 0; graine < 30; graine++) {
        final manches = const CodeGenerateur().generer(
          activiteCode.niveauPour(palier)!,
          Random(graine),
        );
        for (final manche in manches) {
          final code = manche.donnees as DonneesCode;
          expect(code.maxBlocs, lessThanOrEqualTo(3));
          expect(codeEstRealisable(code), isTrue);
          expect(code.ramassable, 'pomme');
        }
      }
    }
  });

  test('le contenu passe le validateur', () {
    final problemes = validerContenu(grainesParNiveau: 100);
    expect(problemes, isEmpty, reason: problemes.join('\n'));
  });

  test('chaque mot de la banque de rimes existe dans les deux lexiques', () {
    final qc = lexiquePour(Deck.qc);
    final fr = lexiquePour(Deck.fr);
    for (final mot in banqueRimes) {
      expect(
        qc.containsKey(mot.concept),
        isTrue,
        reason: '${mot.concept} absent du lexique QC',
      );
      expect(
        fr.containsKey(mot.concept),
        isTrue,
        reason: '${mot.concept} absent du lexique FR',
      );
    }
  });

  test('chaque rime de la banque a au moins trois mots', () {
    final parRime = <String, int>{};
    for (final mot in banqueRimes) {
      parRime[mot.rime] = (parRime[mot.rime] ?? 0) + 1;
    }
    parRime.forEach((rime, nombre) {
      expect(
        nombre,
        greaterThanOrEqualTo(3),
        reason: 'la rime « $rime » n\'a que $nombre mot(s)',
      );
    });
  });

  test('les leurres ne riment JAMAIS avec la cible (règle anti-rime)', () {
    final rimeDe = {for (final mot in banqueRimes) mot.concept: mot.rime};
    const generateur = RimesGenerateur();
    for (final palier in Palier.values) {
      final niveau = activiteRimes.niveauPour(palier)!;
      for (var graine = 1; graine <= 30; graine++) {
        final manches = generateur.generer(niveau, Random(graine));
        for (final manche in manches) {
          final morceaux = manche.id.split('.');
          final cible = morceaux[1];
          final bonne = morceaux[2];
          expect(
            rimeDe[bonne],
            rimeDe[cible],
            reason: 'la bonne réponse ne rime pas avec la cible (${manche.id})',
          );
          for (final option in manche.options) {
            if (option.id == bonne) continue;
            expect(
              rimeDe[option.id],
              isNot(rimeDe[cible]),
              reason:
                  'un leurre rime avec la cible (${manche.id}, ${option.id})',
            );
          }
        }
      }
    }
  });

  test('le contenu pur Dart n\'importe jamais Flutter', () {
    final racine = Directory('lib/core/contenu');
    final fichiers = racine
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final fichier in fichiers) {
      final source = fichier.readAsStringSync();
      expect(
        source.contains('package:flutter'),
        isFalse,
        reason: '${fichier.path} importe Flutter (contenu = pur Dart)',
      );
    }
  });

  test('chaque concept du lexique a son illustration sur disque', () {
    for (final entree in lexiquePour(Deck.qc).entries) {
      final fichier = File(
        'assets/images/concepts/${entree.value.illustrationPour(entree.key)}',
      );
      expect(
        fichier.existsSync(),
        isTrue,
        reason: 'illustration manquante : ${fichier.path}',
      );
    }
  });

  test('chaque activité a sa carte sur disque', () {
    for (final activite in catalogueActivites) {
      final fichier = File('assets/images/concepts/${activite.illustration}');
      expect(
        fichier.existsSync(),
        isTrue,
        reason:
            'carte manquante pour ${activite.id} : ${fichier.path} '
            '(générer avec tools/images/generer_illustrations_activites.py)',
      );
    }
  });
}
