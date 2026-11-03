import 'package:flutter/material.dart';

import 'app.dart';
import 'core/audio/lecteur_audio.dart';
import 'core/audio/manifeste_audio.dart';
import 'core/audio/say_kit.dart';
import 'core/audio/session_audio.dart';
import 'core/micro/mic_kit.dart';
import 'core/parent/reglages.dart';
import 'core/progression/depot_sqlite.dart';
import 'features/shell/shell_controller.dart';

/// Tout se prépare avant l'écran : la voix doit être prête au premier tap
/// d'un enfant (préparation des lecteurs, manifeste audio chargé).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final reglages = await Reglages.charger();

  // Le son sort même en mode silencieux, sauf choix contraire du parent.
  await SessionAudio.configurer(
      respecterSilencieux: reglages.respecterSilencieux);

  final repertoire = await RepertoireClips.charger(
    deckActif: reglages.deck,
    voixActive: reglages.voix,
  );
  final lecteur = LecteurJustAudio();
  await lecteur.initialiser();
  final say = SayKit(repertoire: repertoire, lecteur: lecteur);

  final depot = DepotSqlite();
  await depot.initialiser();
  // Purge du journal : on ne garde que 180 jours, et seulement sur l'appareil.
  await depot.purgerAvant(DateTime.now().subtract(const Duration(days: 180)));

  final shell = ShellController(depot: depot, reglages: reglages);
  await shell.initialiser();

  // Le micro : éphémère et local. On efface tout reste d'enregistrement
  // d'une session précédente — rien ne doit traîner.
  final micro = MicKit();
  await micro.nettoyer();

  runApp(JeuxEnfantsApp(
    reglages: reglages,
    say: say,
    depot: depot,
    shell: shell,
    micro: micro,
  ));
}
