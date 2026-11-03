import 'package:just_audio/just_audio.dart';

/// Ce que le reste de l'app attend d'un lecteur de clips.
/// Une implémentation réelle (just_audio) et une factice (les tests).
abstract class LecteurClips {
  Future<void> initialiser();

  /// Joue une suite de fichiers (chemins d'assets) l'un après l'autre.
  /// Coupe ce qui jouait avant.
  Future<void> jouerSequence(List<String> chemins);

  Future<void> stopper();

  Future<void> liberer();
}

/// Le vrai lecteur : un petit pool just_audio.
///
/// On prépare les lecteurs AVANT de jouer (chargement du fichier compris),
/// sinon le premier mot de chaque phrase se perd pendant le décodage.
class LecteurJustAudio implements LecteurClips {
  final int taille;
  final List<AudioPlayer> _lecteurs = [];
  int _prochain = 0;
  // Un arrêt ou une nouvelle lecture invalide aussi les clips encore
  // en chargement et ceux qui attendent leur tour dans la séquence.
  int _generation = 0;
  final AudioPlayer Function() _creerLecteur;

  LecteurJustAudio({this.taille = 3, AudioPlayer Function()? creerLecteur})
    : assert(taille > 0),
      _creerLecteur = creerLecteur ?? (() => AudioPlayer());

  @override
  Future<void> initialiser() async {
    if (_lecteurs.isNotEmpty) return;
    for (var i = 0; i < taille; i++) {
      _lecteurs.add(_creerLecteur());
    }
  }

  @override
  Future<void> jouerSequence(List<String> chemins) async {
    if (chemins.isEmpty) return;
    final generation = ++_generation;
    await _arreterLecteurs();
    if (generation != _generation) return;

    // Par blocs de la taille du pool : on prépare puis on joue.
    for (var debut = 0; debut < chemins.length; debut += taille) {
      final fin = debut + taille > chemins.length
          ? chemins.length
          : debut + taille;
      final bloc = chemins.sublist(debut, fin);
      final prets = <AudioPlayer>[];
      for (final chemin in bloc) {
        final lecteur = _suivant();
        await lecteur.setAudioSource(AudioSource.asset(chemin));
        if (generation != _generation) return;
        prets.add(lecteur);
      }
      for (final lecteur in prets) {
        if (generation != _generation) return;
        await lecteur.play();
        if (generation != _generation) return;
      }
    }
  }

  @override
  Future<void> stopper() async {
    _generation++;
    await _arreterLecteurs();
  }

  Future<void> _arreterLecteurs() async {
    for (final lecteur in _lecteurs) {
      if (lecteur.playing) {
        await lecteur.stop();
      }
    }
  }

  AudioPlayer _suivant() {
    final lecteur = _lecteurs[_prochain];
    _prochain = (_prochain + 1) % _lecteurs.length;
    return lecteur;
  }

  @override
  Future<void> liberer() async {
    _generation++;
    for (final lecteur in _lecteurs) {
      await lecteur.dispose();
    }
    _lecteurs.clear();
  }
}

/// Lecteur factice pour les tests et les aperçus : il note ce qu'on lui
/// demande de dire, sans jamais toucher au son.
class LecteurFactice implements LecteurClips {
  final List<List<String>> sequencesJouees = [];

  @override
  Future<void> initialiser() async {}

  @override
  Future<void> jouerSequence(List<String> chemins) async {
    sequencesJouees.add(List.of(chemins));
  }

  @override
  Future<void> stopper() async {}

  @override
  Future<void> liberer() async {}
}
