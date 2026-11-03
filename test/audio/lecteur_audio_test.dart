import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/audio/lecteur_audio.dart';
import 'package:just_audio/just_audio.dart';

class PlayerControle implements AudioPlayer {
  Completer<void>? attenteLecture;
  Completer<void>? attenteChargement;
  int lectures = 0;
  @override
  bool playing = false;

  @override
  Future<Duration?> setAudioSource(
    AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    await attenteChargement?.future;
    return const Duration(seconds: 1);
  }

  @override
  Future<void> play() async {
    lectures++;
    playing = true;
    await attenteLecture?.future;
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
    if (attenteLecture != null && !attenteLecture!.isCompleted) {
      attenteLecture!.complete();
    }
  }

  @override
  Future<void> dispose() => stop();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('stopper coupe aussi les clips suivants de la séquence', () async {
    final player = PlayerControle()..attenteLecture = Completer<void>();
    final lecteur = LecteurJustAudio(taille: 1, creerLecteur: () => player);
    await lecteur.initialiser();
    final lecture = lecteur.jouerSequence(['un.mp3', 'deux.mp3']);
    await Future<void>.delayed(Duration.zero);
    expect(player.lectures, 1);
    await lecteur.stopper();
    await lecture;
    expect(player.lectures, 1);
    await lecteur.liberer();
  });

  test('stopper pendant le chargement empêche le démarrage tardif', () async {
    final player = PlayerControle()..attenteChargement = Completer<void>();
    final lecteur = LecteurJustAudio(taille: 1, creerLecteur: () => player);
    await lecteur.initialiser();
    final lecture = lecteur.jouerSequence(['un.mp3']);
    await Future<void>.delayed(Duration.zero);
    await lecteur.stopper();
    player.attenteChargement!.complete();
    await lecture;
    expect(player.lectures, 0);
    await lecteur.liberer();
  });

  test('une nouvelle séquence remplace toute la précédente', () async {
    final player = PlayerControle()..attenteLecture = Completer<void>();
    final lecteur = LecteurJustAudio(taille: 1, creerLecteur: () => player);
    await lecteur.initialiser();
    final ancienne = lecteur.jouerSequence(['un.mp3', 'deux.mp3']);
    await Future<void>.delayed(Duration.zero);
    final nouvelle = lecteur.jouerSequence(['trois.mp3']);
    await Future.wait([ancienne, nouvelle]);
    expect(player.lectures, 2);
    await lecteur.liberer();
  });
}
