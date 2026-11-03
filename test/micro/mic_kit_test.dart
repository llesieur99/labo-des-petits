import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/micro/mic_kit.dart';

/// Tests de K1 — le kit micro « enregistrer et se réécouter ».
///
/// Le vrai [MicKit] ne peut pas enregistrer ici : `record`, `just_audio` et
/// `path_provider` sont des plugins natifs, absents d'un `flutter test`. On
/// vérifie donc deux choses : le [MicroFactice] tient tout le contrat, et le
/// vrai [MicKit] répond proprement (jamais une exception, jamais un appel
/// natif) quand rien n'est accordé.
void main() {
  group('MicroFactice', () {
    test('accorde faux avant demander(), vrai après', () async {
      final micro = MicroFactice();
      expect(await micro.estAccorde(), isFalse);
      expect(micro.demandes, 0, reason: 'l\'OS ne doit pas être sollicité');

      expect(await micro.demander(), isTrue);
      expect(await micro.estAccorde(), isTrue);
      expect(micro.demandes, 1);
    });

    test('sans accord, enregistrer rend null (le jeu reste jouable)', () async {
      final micro = MicroFactice();
      expect(await micro.enregistrer(max: const Duration(seconds: 5)), isNull);
      expect(micro.fichiers, isEmpty);
    });

    test('enregistrer rend un chemin non vide, et il est tracé', () async {
      final micro = MicroFactice(accorde: true);
      final chemin = await micro.enregistrer(max: const Duration(seconds: 5));

      expect(chemin, isNotNull);
      expect(chemin!.trim(), isNotEmpty);
      expect(micro.fichiers, contains(chemin));

      final autre = await micro.enregistrer(max: const Duration(seconds: 5));
      expect(autre, isNot(chemin),
          reason: 'deux enregistrements ne se marchent pas dessus');
      expect(micro.fichiers, hasLength(2));
    });

    test('rejouer ne jette pas et note le chemin', () async {
      final micro = MicroFactice(accorde: true);
      final chemin = (await micro.enregistrer(max: const Duration(seconds: 3)))!;

      await micro.rejouer(chemin);

      expect(micro.rejoues, [chemin]);
    });

    test('effacer retire le fichier, et reste silencieux s\'il est parti',
        () async {
      final micro = MicroFactice(accorde: true);
      final chemin = (await micro.enregistrer(max: const Duration(seconds: 3)))!;

      await micro.effacer(chemin);
      expect(micro.fichiers, isEmpty);

      // Effacer deux fois n'est pas une erreur : on efface toujours après
      // l'écoute, même si le fichier a déjà disparu.
      await micro.effacer(chemin);
      expect(micro.fichiers, isEmpty);
    });

    test('nettoyer vide tout ce qui traîne', () async {
      final micro = MicroFactice(accorde: true);
      await micro.enregistrer(max: const Duration(seconds: 3));
      await micro.enregistrer(max: const Duration(seconds: 3));
      expect(micro.fichiers, hasLength(2));

      await micro.nettoyer();

      expect(micro.fichiers, isEmpty);
    });
  });

  group('MicKit (aucun appel natif en test)', () {
    test('s\'instancie sans toucher au micro ni aux plugins', () {
      expect(MicKit(), isA<Micro>());
      expect(MicKit.nomDossier, 'voix_enfant');
    });

    test('estAccorde répond faux au lieu de lever', () async {
      // Sans plugin, `record` ne peut pas répondre : le kit doit dire non,
      // pas planter au milieu d'un jeu.
      expect(await MicKit().estAccorde(), isFalse);
    });

    test('enregistrer sans permission rend null au lieu de lever', () async {
      expect(
        await MicKit().enregistrer(max: const Duration(milliseconds: 20)),
        isNull,
      );
    });

    test('effacer et nettoyer répondent proprement (rien à effacer)', () async {
      final micro = MicKit();
      await micro.effacer('/temporaire/voix_enfant/jamais_ecrit.m4a');
      await micro.nettoyer();
    });

    // `rejouer` n'est pas essayé sur le vrai kit ici : il construit un
    // `AudioPlayer`, qui touche le plugin natif de just_audio dès sa
    // construction — et ce plugin laisse échapper une erreur asynchrone
    // qu'aucun try/catch de MicKit ne peut rattraper. Le contrat de `rejouer`
    // est couvert par MicroFactice ci-dessus ; le vrai son se vérifie sur
    // l'iPhone (deploy_iphone.sh).
  });
}
