import 'dart:async';

import 'package:jeux_enfants/core/micro/mic_kit.dart';

class MicroControle extends MicroFactice {
  final attente = Completer<void>();
  final bool panneLecture;

  MicroControle({this.panneLecture = false}) : super(accorde: true);

  @override
  Future<String?> enregistrer({required Duration max}) async {
    final chemin = await super.enregistrer(max: max);
    await attente.future;
    return chemin;
  }

  @override
  Future<void> rejouer(String chemin) async {
    if (panneLecture) throw StateError('lecture indisponible');
    await super.rejouer(chemin);
  }
}
