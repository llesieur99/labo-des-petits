import 'package:audio_session/audio_session.dart';

/// Configure la session audio de l'app.
///
/// Décision produit : le son sort MÊME SI l'interrupteur silencieux du
/// téléphone est activé — un enfant de 4 ans ne peut pas comprendre pourquoi
/// l'app ne parle plus. Le parent peut inverser ce choix dans son espace.
class SessionAudio {
  static Future<void> configurer({required bool respecterSilencieux}) async {
    final session = await AudioSession.instance;
    await session.configure(
      respecterSilencieux
          // Catégorie « ambient » : le son respecte l'interrupteur silencieux.
          ? const AudioSessionConfiguration(
              avAudioSessionCategory: AVAudioSessionCategory.ambient,
              androidAudioAttributes: AndroidAudioAttributes(
                contentType: AndroidAudioContentType.speech,
                usage: AndroidAudioUsage.media,
              ),
              androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
              androidWillPauseWhenDucked: true,
            )
          // Catégorie « playback » : l'app parle même en mode silencieux.
          : const AudioSessionConfiguration.speech(),
    );
  }
}
