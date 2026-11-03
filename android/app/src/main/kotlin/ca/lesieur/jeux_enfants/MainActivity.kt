package ca.lesieur.jeux_enfants

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ca.lesieur.jeuxEnfants/retours_parent",
        ).setMethodCallHandler { call, result ->
            if (call.method != "ouvrirCourriel") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val adresse = call.argument<String>("adresse")
            val sujet = call.argument<String>("sujet")
            val message = call.argument<String>("message")
            if (adresse != "support@le-sieur.ca" || sujet.isNullOrBlank() || message.isNullOrBlank()) {
                result.error("PARAMETRES", "Brouillon incomplet", null)
                return@setMethodCallHandler
            }

            // ACTION_SENDTO avec mailto: ne propose que les apps de courriel.
            // Le parent doit encore appuyer sur Envoyer dans l'app choisie.
            val courriel = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:$adresse")
                putExtra(Intent.EXTRA_EMAIL, arrayOf(adresse))
                putExtra(Intent.EXTRA_SUBJECT, sujet)
                putExtra(Intent.EXTRA_TEXT, message)
            }
            try {
                startActivity(courriel)
                result.success(true)
            } catch (_: ActivityNotFoundException) {
                result.success(false)
            } catch (_: SecurityException) {
                result.success(false)
            }
        }
    }
}
