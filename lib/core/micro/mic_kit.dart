import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Ce que les jeux attendent du micro : enregistrer, se réécouter, effacer.
/// Jamais de reconnaissance, jamais de réseau, jamais de conservation.
abstract class Micro {
  /// Le parent a autorisé le micro et l'OS a accordé la permission.
  Future<bool> estAccorde();

  /// Demande la permission à l'OS — APPELÉE UNIQUEMENT DEPUIS L'ESPACE
  /// PARENT (règle du projet). Rend vrai si accordée.
  Future<bool> demander();

  /// Enregistre au plus [max], puis rend le chemin du fichier temporaire
  /// (null si le micro n'est pas accordé).
  Future<String?> enregistrer({required Duration max});

  /// Réécoute un enregistrement.
  Future<void> rejouer(String chemin);

  /// Efface l'enregistrement (toujours appelé après l'écoute).
  Future<void> effacer(String chemin);

  /// Efface tout ce qui traîne (au démarrage, pour ne rien laisser).
  Future<void> nettoyer();
}

/// Le vrai micro : `record` pour enregistrer, `just_audio` pour réécouter,
/// `path_provider` pour un fichier temporaire voué à disparaître.
///
/// Ce que ce kit garantit, sans exception :
/// - l'OS n'est JAMAIS sollicité pour la permission ailleurs que dans
///   [demander] — un jeu qui n'a pas l'accord appelle [enregistrer], reçoit
///   `null` et reste jouable sans micro ;
/// - le son vit dans un fichier temporaire de l'app (`voix_enfant/`), nulle
///   part ailleurs, et part avec [effacer] (ou [nettoyer] au démarrage) ;
/// - rien ne part sur le réseau, rien n'est reconnu, rien n'est conservé :
///   on enregistre, on se réécoute, on efface.
///
/// Le parent autorise le micro de son côté (espace parent, journal d'accord) ;
/// ce kit ne connaît que l'état de l'OS.
class MicKit implements Micro {
  /// Le sous-dossier temporaire où la voix de l'enfant vit le temps d'un jeu.
  static const nomDossier = 'voix_enfant';

  AudioRecorder? _enregistreur;
  AudioPlayer? _lecteur;

  // Rien n'est créé avant le premier usage : instancier le kit ne touche ni
  // au micro ni aux plugins (les tests et les aperçus peuvent le faire).
  AudioRecorder get _micro => _enregistreur ??= AudioRecorder();
  AudioPlayer get _ecoute => _lecteur ??= AudioPlayer();

  @override
  Future<bool> estAccorde() async {
    try {
      // `request: false` est le cœur de la règle : on REGARDE l'accord, on ne
      // le demande pas. La boîte de l'OS ne doit apparaître que dans l'espace
      // parent — jamais au milieu d'un jeu.
      return await _micro.hasPermission(request: false);
    } catch (e) {
      debugPrint('MicKit : permission illisible ($e) — on joue sans micro.');
      return false;
    }
  }

  @override
  Future<bool> demander() async {
    try {
      // Le seul appel qui peut faire apparaître la boîte de l'OS.
      return await _micro.hasPermission();
    } catch (e) {
      debugPrint('MicKit : demande de permission impossible ($e).');
      return false;
    }
  }

  @override
  Future<String?> enregistrer({required Duration max}) async {
    if (!await estAccorde()) return null;

    final chemin = '${(await _dossierPret()).path}/${_nomNeuf()}';
    // Une durée négative ne doit pas faire planter : on enregistre au minimum.
    final duree = max.isNegative ? Duration.zero : max;
    try {
      await _micro.start(const RecordConfig(), path: chemin);
      await Future<void>.delayed(duree);
      return await _micro.stop() ?? chemin;
    } catch (e) {
      // Rien ne reste derrière : ni micro ouvert, ni fichier à moitié écrit.
      await _arreterEnSilence();
      await effacer(chemin);
      debugPrint('MicKit : enregistrement impossible ($e) — on continue sans.');
      return null;
    }
  }

  @override
  Future<void> rejouer(String chemin) async {
    try {
      // `play()` rend la main à la fin de l'écoute : après lui, l'appelant
      // peut effacer le fichier sans couper la voix de l'enfant.
      await _ecoute.stop();
      await _ecoute.setFilePath(chemin);
      await _ecoute.play();
    } catch (e) {
      debugPrint('MicKit : écoute impossible ($e) — le jeu continue.');
    }
  }

  @override
  Future<void> effacer(String chemin) async {
    try {
      final fichier = File(chemin);
      if (fichier.existsSync()) await fichier.delete();
    } on FileSystemException catch (e) {
      // Déjà parti, ou jamais écrit : il n'y a rien à annoncer à un enfant.
      debugPrint('MicKit : effacement sans effet ($e).');
    }
  }

  @override
  Future<void> nettoyer() async {
    try {
      final dossier = await _dossier();
      if (await dossier.exists()) {
        // Le dossier entier : il ne contient que des enregistrements d'enfants
        // et il est recréé au prochain [enregistrer].
        await dossier.delete(recursive: true);
      }
    } catch (e) {
      debugPrint('MicKit : nettoyage impossible ($e).');
    }
  }

  /// Arrête le micro sans jamais lever (chemin d'erreur seulement).
  Future<void> _arreterEnSilence() async {
    try {
      await _micro.stop();
    } catch (e) {
      debugPrint('MicKit : arrêt du micro sans effet ($e).');
    }
  }

  /// Le dossier temporaire des voix, sans le créer.
  Future<Directory> _dossier() async {
    final temporaire = await getTemporaryDirectory();
    return Directory('${temporaire.path}/$nomDossier');
  }

  /// Le même dossier, prêt à recevoir un fichier.
  Future<Directory> _dossierPret() async {
    final dossier = await _dossier();
    if (!await dossier.exists()) await dossier.create(recursive: true);
    return dossier;
  }

  /// Un nom de fichier neuf — deux enregistrements ne se marchent jamais
  /// dessus, même dans la même seconde. Format AAC/m4a (défaut de `record`).
  String _nomNeuf() => 'voix_${DateTime.now().microsecondsSinceEpoch}.m4a';
}

/// Factice pour les tests et les aperçus : rien de réel, tout tracé.
///
/// Il tient le même contrat que [MicKit] (sans accord, [enregistrer] rend
/// `null`), ce qui permet de vérifier qu'un jeu reste jouable micro refusé.
class MicroFactice implements Micro {
  /// L'accord courant — le parent peut le retirer à tout moment.
  bool accorde;

  /// Les chemins encore « en vie » (rendus par [enregistrer], pas effacés).
  final List<String> fichiers = [];

  /// Les chemins qu'on a demandé de réécouter.
  final List<String> rejoues = [];

  /// Combien de fois l'OS a été sollicité (doit rester à 0 côté jeu).
  int demandes = 0;

  int _compteur = 0;

  MicroFactice({this.accorde = false});

  @override
  Future<bool> estAccorde() async => accorde;

  @override
  Future<bool> demander() async {
    demandes++;
    accorde = true;
    return accorde;
  }

  @override
  Future<String?> enregistrer({required Duration max}) async {
    if (!accorde) return null;
    final chemin = '/factice/$MicKit.nomDossier/voix_${++_compteur}.m4a';
    fichiers.add(chemin);
    return chemin;
  }

  @override
  Future<void> rejouer(String chemin) async {
    rejoues.add(chemin);
  }

  @override
  Future<void> effacer(String chemin) async {
    fichiers.remove(chemin);
  }

  @override
  Future<void> nettoyer() async {
    fichiers.clear();
  }
}
