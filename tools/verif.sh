#!/bin/zsh
# Vérification complète du projet labo-des-petits.
#
# Enchaîne les cinq contrôles que doit passer un lot avant d'être committé :
#   1/5  flutter analyze                        (0 problème exigé)
#   2/5  flutter test                           (tout vert exigé)
#   3/5  dart run tool/exporter_scripts.dart --check   (scripts.json à jour)
#   4/5  generer_audio.py --verifier            (manifest ↔ fichiers ↔ scripts.json)
#   5/5  taille des assets                      (seuil : 90 Mo)
#
# Sortie non nulle dès qu'une étape échoue, avec le numéro de l'étape fautive.
# Fin heureuse : « TOUT EST VERT ».
#
# Usage : tools/verif.sh   (depuis n'importe quel dossier)

set -euo pipefail

# Le terminal du Dock n'a pas toujours le PATH du shell interactif.
export PATH="$HOME/flutter/bin:$PATH"

# Le script marche d'où qu'on l'appelle : on se replace à la racine du projet.
cd "$(dirname "$0")/.."

TOTAL_ETAPES=5
SEUIL_KO=92160   # 90 Mo — le plafond du plan (60 Mo visés pour le QC seul)

typeset -i NUMERO=0
TITRE=""

etape() {
  NUMERO=$((NUMERO + 1))
  TITRE="$1"
  echo ""
  echo "──────────────────────────────────────────────────────────────"
  echo "Étape $NUMERO/$TOTAL_ETAPES — $TITRE"
  echo "──────────────────────────────────────────────────────────────"
}

echec() {
  echo ""
  echo "✗ ÉCHEC à l'étape $NUMERO/$TOTAL_ETAPES — $TITRE"
  echo "  (rien n'est cassé : corrige, puis relance tools/verif.sh)"
  exit 1
}

echo "Vérification de labo-des-petits — $(pwd)"

# ── 1/5 : l'analyse statique ────────────────────────────────────────────────
etape "flutter analyze (0 problème exigé)"
flutter analyze || echec

# ── 2/5 : les tests ─────────────────────────────────────────────────────────
etape "flutter test (tout vert exigé)"
flutter test || echec

# ── 3/5 : l'export du contenu vers scripts.json ─────────────────────────────
etape "export du contenu à jour (tool/exporter_scripts.dart --check)"
dart run tool/exporter_scripts.dart --check || echec

# ── 4/5 : la cohérence audio ────────────────────────────────────────────────
# Le venv s'il existe (edge-tts y est installé), sinon le python3 du système :
# generer_audio.py n'utilise que la bibliothèque standard.
if [[ -x tools/audio/.venv/bin/python ]]; then
  PYTHON_AUDIO=tools/audio/.venv/bin/python
else
  PYTHON_AUDIO=python3
fi
etape "audio cohérent (generer_audio.py --verifier, via $PYTHON_AUDIO)"
"$PYTHON_AUDIO" tools/audio/generer_audio.py --verifier || echec

# ── 5/5 : la taille des assets ──────────────────────────────────────────────
etape "taille des assets (seuil $((SEUIL_KO / 1024)) Mo)"
TAILLE_KO=$(du -sk assets | awk '{print $1}')
TAILLE_MO=$(awk -v ko="$TAILLE_KO" 'BEGIN { printf "%.1f", ko / 1024 }')
if (( TAILLE_KO > SEUIL_KO )); then
  echo "assets/ pèse $TAILLE_KO Ko ($TAILLE_MO Mo) — au-dessus du seuil de $SEUIL_KO Ko."
  echo "Allège les sons ou les images avant de committer."
  echec
fi
echo "assets/ pèse $TAILLE_KO Ko ($TAILLE_MO Mo) — sous le seuil de $SEUIL_KO Ko."

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "TOUT EST VERT ($TOTAL_ETAPES/$TOTAL_ETAPES)"
echo "  analyze · tests · export · audio · taille des assets"
echo "══════════════════════════════════════════════════════════════"
