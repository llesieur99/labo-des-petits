#!/bin/zsh
set -euo pipefail
export PATH="$HOME/homebrew/bin:$HOME/flutter/bin:$HOME/.gem/portable-cocoapods/bin:$PATH"
export GEM_HOME="$HOME/.gem/portable-cocoapods"
export GEM_PATH="$GEM_HOME"
cd "$(dirname "$0")"

MODE="${1:-release}"  # release | profile | debug | build

if [[ "$MODE" == "build" ]]; then
  flutter build ios --release
  echo "OK: build release termine (aucune installation demandee)"
  exit 0
fi
# NOTE: pas de `exit` dans awk — avec set -e + pipefail, fermer le pipe tot
# envoie SIGPIPE a flutter devices et tue le script.
DEVICE_ID=$(flutter devices 2>/dev/null | awk -F'•' '
  tolower($0) ~ /iphone/ && tolower($0) !~ /simulator/ && !seen {
    gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; seen = 1
  }
' || true)
if [[ -z "${DEVICE_ID:-}" ]]; then
  echo "ERROR: Aucun iPhone physique détecté"; exit 1
fi
echo "Device=$DEVICE_ID mode=$MODE"

if [[ "$MODE" == "debug" ]]; then
  echo "NOTE: debug nécessite flutter run attaché (crash sinon depuis l'écran d'accueil)"
  flutter run -d "$DEVICE_ID" --debug
  exit 0
fi

flutter build ios --"$MODE"
APP="build/ios/iphoneos/Runner.app"
xcrun devicectl device install app --device "$DEVICE_ID" "$APP"
if xcrun devicectl device process launch --device "$DEVICE_ID" ca.lesieur.jeuxEnfants 2>/dev/null; then
  echo "OK: installée et lancée (mode $MODE)"
else
  echo "OK: installée (mode $MODE) — lancement auto impossible (téléphone verrouillé ?). Ouvre l'app manuellement."
fi
