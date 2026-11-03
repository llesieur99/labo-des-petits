import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Garde-fou contre un piège Flutter vicieux : une entrée `assets:` dans le
/// pubspec ne couvre que les fichiers DIRECTEMENT dans le dossier. Si un
/// sous-dossier de clips n'est pas listé, ses MP3 ne sont pas embarqués —
/// l'app trouve le manifeste mais joue le silence. C'est arrivé au lot 0.
void main() {
  List<String> dossiersDeclares() {
    final lignes = File('pubspec.yaml').readAsStringSync().split('\n');
    final dossiers = <String>[];
    for (final ligne in lignes) {
      final texte = ligne.trim();
      if (texte.startsWith('- assets/')) dossiers.add(texte.substring(2));
    }
    return dossiers;
  }

  test('chaque dossier de clips des manifestes est déclaré dans pubspec.yaml',
      () {
    final manifestes = Directory('assets/audio')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('manifest.json'))
        .toList();
    expect(manifestes, isNotEmpty,
        reason: 'aucun manifeste audio trouvé sous assets/audio/');
    final declares = dossiersDeclares();

    final manquants = <String>{};
    for (final fichier in manifestes) {
      final json =
          jsonDecode(fichier.readAsStringSync()) as Map<String, dynamic>;
      final clips = json['clips'] as Map<String, dynamic>? ?? const {};
      for (final clip in clips.values) {
        final chemin = (clip as Map<String, dynamic>)['fichier'] as String;
        final dossier =
            'assets/audio/${chemin.substring(0, chemin.lastIndexOf('/'))}/';
        if (!declares.contains(dossier)) manquants.add(dossier);
      }
    }

    expect(
      manquants,
      isEmpty,
      reason: 'Ces dossiers de clips ne sont PAS déclarés dans pubspec.yaml — '
          'leurs fichiers ne seraient pas embarqués dans l\'app (jeu '
          'silencieux) :\n${manquants.join('\n')}',
    );
  });

  test('chaque dossier d\'assets déclaré existe vraiment', () {
    for (final dossier in dossiersDeclares()) {
      expect(
        Directory(dossier).existsSync(),
        isTrue,
        reason: 'pubspec.yaml déclare $dossier mais ce dossier n\'existe pas '
            '— le build échouera.',
      );
    }
  });

  test('chaque dossier de sons neutres est déclaré dans pubspec.yaml', () {
    // Les WAV non verbaux (tambour, notes…) vivent sous assets/audio/neutre/
    // et souffrent du MÊME piège que les voix : un sous-dossier non déclaré
    // n'est pas embarqué, et le jeu devient muet sans erreur.
    final declares = dossiersDeclares();
    final manquants = <String>{};
    final neutre = Directory('assets/audio/neutre');
    if (neutre.existsSync()) {
      for (final fichier in neutre.listSync(recursive: true).whereType<File>()) {
        if (!fichier.path.endsWith('.wav')) continue;
        // Le manifeste utilise des / sur toutes les plateformes.
        final dossier = '${fichier.parent.path.replaceAll(r'\', '/')}/';
        if (!declares.contains(dossier)) manquants.add(dossier);
      }
    }
    expect(
      manquants,
      isEmpty,
      reason: 'Ces dossiers de sons ne sont PAS déclarés dans pubspec.yaml '
          '(jeu muet) :\n${manquants.join('\n')}',
    );
  });
}
