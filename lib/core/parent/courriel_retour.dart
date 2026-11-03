import 'package:flutter/services.dart';

import '../identite.dart';

/// Ouvre un brouillon dans l'application de courriel choisie par le parent.
/// Labo des Petits ne transmet rien et ne sait pas si le message est envoyé.
abstract final class CourrielRetour {
  static const _canal = MethodChannel('ca.lesieur.jeuxEnfants/retours_parent');

  static Future<bool> ouvrir(String sujet, String message) async {
    try {
      return await _canal.invokeMethod<bool>('ouvrirCourriel', {
            'adresse': Identite.soutien,
            'sujet': sujet,
            'message': message,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
