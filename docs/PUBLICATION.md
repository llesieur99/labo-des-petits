# Compiler et distribuer Labo des Petits

Les sources publiques ne contiennent pas les certificats, profils, contacts
privés, identifiants App Store Connect ou clés de distribution du mainteneur.
La présence du code sur GitHub ne garantit pas la disponibilité sur une boutique.

## iOS

Exécuter flutter pub get, puis ouvrir ios/Runner.xcworkspace dans Xcode.
Configurer votre équipe et vos profils de signature. Pour une compilation
sans signature : flutter build ios --release --no-codesign.

La cible Runner utilise LABO_DEVELOPMENT_TEAM pour l’équipe Apple. La configuration
Release accepte LABO_SIGNING_STYLE (Automatic par défaut), LABO_SIGNING_IDENTITY
(Apple Development par défaut) et LABO_PROVISIONING_PROFILE (vide par défaut).
Ces paramètres s’appliquent à l’application, pas aux dépendances SwiftPM.

Exemple de paramètres pour xcodebuild, avec des valeurs définies localement :

```sh
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner \
  -configuration Release -destination 'generic/platform=iOS' \
  LABO_DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
  LABO_SIGNING_STYLE=Manual \
  'LABO_SIGNING_IDENTITY=Apple Distribution' \
  LABO_PROVISIONING_PROFILE="$APPLE_PROFILE_NAME" archive
```

Copier docs/publication/ExportOptions.plist dans _local/ et compléter les
paramètres de signature avant export. Ne jamais ajouter les identifiants locaux
au modèle public. L’archivage, la signature, le téléversement, la validation et
la publication sont des étapes distinctes.

## Android

Utiliser Android SDK 36 et JDK 17 ou plus récent. Configurer votre keystore dans
android/key.properties ou via LUDIBALLON_KEY_PROPERTIES ; ces fichiers restent
privés. Compiler avec flutter build appbundle --release et vérifier les permissions
avec tools/verif_android_manifest.sh. Ne pas publier un paquet signé en debug.

## Fiche et captures

Le modèle français est docs/publication/fiche-fr-CA.json. Les coordonnées privées
et l’identifiant App Store Connect se renseignent dans
_local/publication/contacts-apple.json. Le contrôle --soumission exige ces champs
mais n’effectue aucun envoi. Ne publier qu’avec une autorisation explicite.

```sh
python3 tools/verif_publication.py
python3 tools/verif_publication.py --soumission
CAPTURES_STORE=1 flutter test test/navigation/ecrans_adaptatifs_test.dart
```

Les visuels de docs/publication/presentation/ utilisent des données fictives.
Régénérer et relire les captures à chaque changement visible de l’application.

## Parcours du microphone — build 11

Le bouton préalable à la permission porte le libellé neutre « Continuer »,
y compris pour les technologies d’assistance. Le texte précise que le micro
est facultatif et que les jeux restent utilisables sans lui. Après un refus,
le message reste neutre et aucune demande n’est relancée automatiquement.
Le réglage local n’est activé qu’après une permission système accordée.

Les tests parentaux couvrent acceptation et refus, absence de demande à
l’ouverture, absence d’activation avant le résultat système, écran iPhone
et petit écran avec texte agrandi. Pour produire les captures de contrôle
privées : CAPTURES_MICRO=1 flutter test test/parent/permission_micro_test.dart.
