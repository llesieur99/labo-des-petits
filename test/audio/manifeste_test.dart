import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/manifeste_audio.dart';
import 'package:jeux_enfants/core/contenu/modele/activite.dart';

void main() {
  ManifesteAudio manifeste(Deck deck, String voix, Map<String, String> fichiers) =>
      ManifesteAudio.depuisJson(deck, voix, {
        'clips': {
          for (final entree in fichiers.entries)
            entree.key: {
              'fichier': entree.value,
              'texte': 'texte de ${entree.key}',
              'voix': 'fr-CA-AntoineNeural',
              'statut': 'genere',
            },
        },
      });

  test('lit un manifeste et garde les entrées', () {
    final m = manifeste(
        Deck.qc, 'antoine', {'lex.chapeau': 'qc/antoine/lexique/chapeau.mp3'});
    expect(m.clips['lex.chapeau']!.fichier, 'qc/antoine/lexique/chapeau.mp3');
    expect(m.clips['lex.chapeau']!.cheminAsset,
        'assets/audio/qc/antoine/lexique/chapeau.mp3');
    expect(m.clips['lex.chapeau']!.statut, 'genere');
  });

  test('résout vers le deck × voix actifs d\'abord', () {
    final repertoire = RepertoireClips.pourTest(Deck.qc, 'sylvie', {
      'qc/antoine': manifeste(
          Deck.qc, 'antoine', {'lex.chapeau': 'qc/antoine/lexique/chapeau.mp3'}),
      'qc/sylvie': manifeste(
          Deck.qc, 'sylvie', {'lex.chapeau': 'qc/sylvie/lexique/chapeau.mp3'}),
    });
    expect(repertoire.pour('lex.chapeau')!.fichier,
        'qc/sylvie/lexique/chapeau.mp3');
  });

  test('se replie sur l\'autre voix quand la voix active n\'a pas le clip', () {
    final repertoire = RepertoireClips.pourTest(Deck.qc, 'sylvie', {
      'qc/antoine': manifeste(
          Deck.qc, 'antoine', {'lex.chapeau': 'qc/antoine/lexique/chapeau.mp3'}),
      'qc/sylvie': manifeste(Deck.qc, 'sylvie', {}),
    });
    expect(repertoire.pour('lex.chapeau')!.fichier,
        'qc/antoine/lexique/chapeau.mp3',
        reason: 'Sylvie n\'a pas encore ce clip : repli sur Antoine');
  });

  test('se replie sur l\'autre deck (QC ↔ FR), même voix', () {
    final repertoire = RepertoireClips.pourTest(Deck.fr, 'antoine', {
      'qc/antoine': manifeste(
          Deck.qc, 'antoine', {'lex.chapeau': 'qc/antoine/lexique/chapeau.mp3'}),
      'fr/antoine': manifeste(Deck.fr, 'antoine', {}),
    });
    expect(repertoire.pour('lex.chapeau')!.fichier,
        'qc/antoine/lexique/chapeau.mp3',
        reason: 'le deck France n\'a pas encore ses clips : repli QC');
  });

  test('rend null (jamais une erreur) quand rien n\'existe', () {
    final repertoire = RepertoireClips.pourTest(Deck.qc, 'antoine', {
      'qc/antoine': manifeste(Deck.qc, 'antoine', {}),
    });
    expect(repertoire.pour('lex.inconnu'), isNull);
  });

  test('le dossier de voix se dérive du nom Azure', () {
    expect(VoixDisponibles.depuisNomAzure('fr-CA-AntoineNeural'), 'antoine');
    expect(VoixDisponibles.depuisNomAzure('fr-CA-SylvieNeural'), 'sylvie');
  });
}
