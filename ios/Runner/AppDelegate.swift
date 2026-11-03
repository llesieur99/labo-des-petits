import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var retoursParentChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let canal = FlutterMethodChannel(
      name: "ca.lesieur.jeuxEnfants/retours_parent",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    canal.setMethodCallHandler { call, result in
      guard call.method == "ouvrirCourriel" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: String],
            let adresse = arguments["adresse"],
            adresse == "support@le-sieur.ca",
            let sujet = arguments["sujet"], !sujet.isEmpty,
            let message = arguments["message"], !message.isEmpty else {
        result(false)
        return
      }
      var url = URLComponents()
      url.scheme = "mailto"
      url.path = adresse
      url.queryItems = [
        URLQueryItem(name: "subject", value: sujet),
        URLQueryItem(name: "body", value: message),
      ]
      guard let courriel = url.url else {
        result(false)
        return
      }
      // Mail ouvre un brouillon. Seul le parent peut l'envoyer.
      DispatchQueue.main.async {
        UIApplication.shared.open(courriel, options: [:]) { ouvert in
          result(ouvert)
        }
      }
    }
    retoursParentChannel = canal
  }
}
