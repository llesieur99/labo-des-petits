import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../contenu/modele/activite.dart';

/// Une entrée du manifeste audio : un clip prêt à jouer.
class EntreeAudio {
  final String id;

  /// Chemin relatif au dossier assets/audio/
  /// ('qc/antoine/lexique/chapeau.mp3').
  final String fichier;

  /// Le texte source — ce qui a été (ou sera) dit.
  final String texte;

  final String voix;

  /// genere | enregistre | provisoire
  final String statut;

  final int? dureeMs;

  const EntreeAudio({
    required this.id,
    required this.fichier,
    required this.texte,
    required this.voix,
    required this.statut,
    this.dureeMs,
  });

  /// Chemin complet pour Flutter.
  String get cheminAsset => 'assets/audio/$fichier';
}

/// Le manifeste d'un deck × voix : id de clip → entrée.
class ManifesteAudio {
  final Deck deck;
  final String voix;
  final Map<String, EntreeAudio> clips;

  const ManifesteAudio({
    required this.deck,
    required this.voix,
    required this.clips,
  });

  static ManifesteAudio vide(Deck deck, String voix) =>
      ManifesteAudio(deck: deck, voix: voix, clips: const {});

  factory ManifesteAudio.depuisJson(
      Deck deck, String voix, Map<String, dynamic> json) {
    final clips = <String, EntreeAudio>{};
    final bruts = json['clips'] as Map<String, dynamic>? ?? const {};
    for (final entree in bruts.entries) {
      final valeur = entree.value as Map<String, dynamic>;
      clips[entree.key] = EntreeAudio(
        id: entree.key,
        fichier: valeur['fichier'] as String,
        texte: valeur['texte'] as String? ?? '',
        voix: valeur['voix'] as String? ?? '',
        statut: valeur['statut'] as String? ?? 'genere',
        dureeMs: valeur['dureeMs'] as int?,
      );
    }
    return ManifesteAudio(deck: deck, voix: voix, clips: clips);
  }
}

/// Les voix disponibles (dossier = partie courte du nom Azure).
/// Antoine est la voix par défaut (choix de LP, 2026-10-16).
abstract final class VoixDisponibles {
  static const antoine = 'antoine';
  static const sylvie = 'sylvie';

  static const toutes = [antoine, sylvie];

  static const defaut = antoine;

  /// « fr-CA-AntoineNeural » → « antoine ».
  static String depuisNomAzure(String nom) {
    var court = nom.split('-').last;
    if (court.toLowerCase().endsWith('neural')) {
      court = court.substring(0, court.length - 'neural'.length);
    }
    return court.toLowerCase();
  }
}

/// Résout un identifiant de clip vers un fichier audio.
///
/// Chaque voix a son jeu de clips : `assets/audio/<deck>/<voix>/…`.
/// Les niveaux de résolution, dans l'ordre :
///   ① un clip enregistré par un parent sur l'appareil (vague 3, jeu 6 —
///      pas encore branché) ;
///   ② le manifeste du deck × voix actifs ;
///   ③ l'autre deck (repli QC ↔ FR), même voix ;
///   ④ l'autre voix, même deck ;
///   ⑤ rien : l'appelant journalise et continue sans planter.
class RepertoireClips {
  Deck deckActif;
  String voixActive;

  final Map<String, ManifesteAudio> _manifestes;

  RepertoireClips._(this.deckActif, this.voixActive, this._manifestes);

  /// Constructeur pour les tests : manifestes fournis à la main,
  /// clés `deck/voix` (ex. `qc/antoine`).
  RepertoireClips.pourTest(
      this.deckActif, this.voixActive, Map<String, ManifesteAudio> manifestes)
      : _manifestes = manifestes;

  /// Charge tous les manifestes disponibles (2 decks × 2 voix ≈ 300 Ko,
  /// négligeable). Un manifeste absent — la France avant sa vague — est
  /// simplement vide, jamais une erreur.
  static Future<RepertoireClips> charger({
    Deck deckActif = Deck.qc,
    String voixActive = VoixDisponibles.defaut,
  }) async {
    final manifestes = <String, ManifesteAudio>{};
    for (final deck in Deck.values) {
      for (final voix in VoixDisponibles.toutes) {
        manifestes['${deck.id}/$voix'] = await _charger(deck, voix);
      }
    }
    return RepertoireClips._(deckActif, voixActive, manifestes);
  }

  static Future<ManifesteAudio> _charger(Deck deck, String voix) async {
    try {
      final brut = await rootBundle
          .loadString('assets/audio/${deck.id}/$voix/manifest.json');
      return ManifesteAudio.depuisJson(
          deck, voix, jsonDecode(brut) as Map<String, dynamic>);
    } catch (_) {
      return ManifesteAudio.vide(deck, voix);
    }
  }

  /// L'entrée d'un clip, ou null s'il est introuvable partout.
  EntreeAudio? pour(String id) {
    // ② deck × voix actifs
    final direct = _manifestes['${deckActif.id}/$voixActive']?.clips[id];
    if (direct != null) return direct;

    // ③ l'autre deck, même voix
    for (final deck in Deck.values) {
      if (deck == deckActif) continue;
      final entree = _manifestes['${deck.id}/$voixActive']?.clips[id];
      if (entree != null) return entree;
    }

    // ④ l'autre voix, même deck
    for (final voix in VoixDisponibles.toutes) {
      if (voix == voixActive) continue;
      final entree = _manifestes['${deckActif.id}/$voix']?.clips[id];
      if (entree != null) return entree;
    }

    // ⑤ dernier recours : toutes les combinaisons restantes
    for (final manifeste in _manifestes.values) {
      final entree = manifeste.clips[id];
      if (entree != null) return entree;
    }
    return null;
  }

  /// Tous les identifiants connus (pour le diagnostic).
  Set<String> get idsConnus => {
        for (final manifeste in _manifestes.values) ...manifeste.clips.keys,
      };
}
