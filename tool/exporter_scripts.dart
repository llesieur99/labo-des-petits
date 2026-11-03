import 'dart:convert';
import 'dart:io';

import 'package:jeux_enfants/core/contenu/modele/activite.dart';
import 'package:jeux_enfants/core/contenu/registre_clips.dart';

/// Exporte le registre de clips vers `tools/audio/scripts.json` (lu par
/// tools/audio/generer_audio.py) et, avec --csv, vers un CSV pour les
/// séances d'enregistrement en voix humaine.
///
/// Usage :
///   dart run tool/exporter_scripts.dart [--deck qc|fr] [--check] [--csv]
///
/// --check : n'écrit rien ; sort en code 1 si le fichier sur disque diverge
/// (utilisé par tools/verif.sh et les tests).
void main(List<String> args) {
  final deck = _lireDeck(args);
  final check = args.contains('--check');
  final csv = args.contains('--csv');

  final clips = clipsDuDeck(deck);
  final donnees = construireScripts(deck, clips);

  final chemin = File('tools/audio/scripts.json');
  final texte = '${const JsonEncoder.withIndent('  ').convert(donnees)}\n';

  if (check) {
    if (!chemin.existsSync()) {
      stderr.writeln('scripts.json absent : lance sans --check pour le créer.');
      exit(1);
    }
    final existant = jsonDecode(chemin.readAsStringSync()) as Map<String, dynamic>;
    final attendu = jsonDecode(texte) as Map<String, dynamic>;
    // Le champ « genere » change à chaque exécution : on l'ignore.
    existant.remove('genere');
    attendu.remove('genere');
    if (jsonEncode(existant) != jsonEncode(attendu)) {
      stderr.writeln(
          'scripts.json n\'est pas à jour : relance `dart run tool/exporter_scripts.dart`.');
      exit(1);
    }
    stdout.writeln('scripts.json à jour (${clips.length} clips, deck ${deck.id}).');
    return;
  }

  chemin.parent.createSync(recursive: true);
  chemin.writeAsStringSync(texte);
  stdout.writeln(
      'Écrit ${chemin.path} : ${clips.length} clips (deck ${deck.id}).');

  if (csv) {
    final fichierCsv = File('tools/audio/clips.csv');
    final lignes = <String>['id,texte,categorie,activite,concept'];
    for (final clip in clips) {
      lignes.add([
        clip.id,
        _csv(clip.texte),
        clip.categorie,
        clip.activite ?? '',
        clip.concept ?? '',
      ].join(','));
    }
    fichierCsv.writeAsStringSync('${lignes.join('\n')}\n');
    stdout.writeln('Écrit ${fichierCsv.path}.');
  }
}

/// Construit la carte JSON exportée (séparée de main pour être testable).
Map<String, Object?> construireScripts(Deck deck, List<ClipDeclare> clips) {
  return {
    'version': 1,
    'genere': DateTime.now().toUtc().toIso8601String(),
    'deck': deck.id,
    'voix': {
      // Choix de LP (2026-10-16, après écoute des échantillons) :
      // Antoine est la voix par défaut, Sylvie la voix secondaire
      // (choix femme/homme dans l'espace parent).
      'principale': 'fr-CA-AntoineNeural',
      'secondaire': 'fr-CA-SylvieNeural',
    },
    'clips': [
      for (final clip in clips)
        {
          'id': clip.id,
          'texte': clip.texte,
          'categorie': clip.categorie,
          if (clip.activite != null) 'activite': clip.activite,
          if (clip.concept != null) 'concept': clip.concept,
          'prosodie': {
            'rate': clip.rate ?? '-10%',
            'pitch': clip.pitch ?? '+0%',
          },
          'style': clip.categorie == 'retour' ? 'cheerful' : '',
        },
    ],
  };
}

Deck _lireDeck(List<String> args) {
  final index = args.indexOf('--deck');
  if (index >= 0 && index + 1 < args.length) {
    final id = args[index + 1];
    for (final deck in Deck.values) {
      if (deck.id == id) return deck;
    }
    stderr.writeln('Deck inconnu : $id');
    exit(2);
  }
  return Deck.qc;
}

String _csv(String texte) =>
    texte.contains(',') || texte.contains('"')
        ? '"${texte.replaceAll('"', '""')}"'
        : texte;
