#!/bin/zsh
# Garde-fou du manifeste Android — permissions interdites.
#
# POURQUOI CE CONTRÔLE EXISTE
# L'app est classée « enfants » (App Store Kids Category / Google Play
# Families) et se vend comme 100% hors ligne, sans compte et sans pub :
#   • android.permission.INTERNET     → l'app pourrait parler au réseau :
#     contraire à la promesse « 100% hors ligne » et aux règles Families
#     (une app enfant ne doit pas envoyer de données sans consentement).
#   • com.google.android.gms.permission.AD_ID → identifiant publicitaire :
#     interdit dans la catégorie enfant des deux stores (et l'app ne doit
#     embarquer AUCUN SDK de pub/analytique, cf. AGENTS.md).
# Un plugin ajouté sans y penser peut apporter l'un ou l'autre en silence :
# ce script est là pour l'attraper avant que ça parte en build.
#
# DEUX MODES
#   1. Un manifeste FUSIONNÉ existe (build Android fait sur cette machine) :
#      on l'analyse — c'est le fichier qui compte, celui que le système lit.
#   2. Aucun manifeste fusionné (cas normal sur le Mac mini, qui ne fait que
#      iOS) : on analyse le manifeste SOURCE android/app/src/main/ et on
#      avertit que le contrôle complet se refera sur le poste Android au build.
#
# NOTE : android/app/src/debug/ et src/profile/ contiennent INTERNET par
# conception (le « hot reload » de Flutter en a besoin). Ce n'est PAS un bug et
# ces fichiers ne sont JAMAIS analysés ici : seuls le mode release et le
# manifeste principal comptent.
#
# Usage : tools/verif_android_manifest.sh   (depuis n'importe quel dossier)

set -euo pipefail

cd "$(dirname "$0")/.."

RACINE_PROJET="$(pwd)"
MANIFESTE_SOURCE="android/app/src/main/AndroidManifest.xml"
MANIFESTE_FUSIONNE="build/app/intermediates/merged_manifests/release/AndroidManifest.xml"

# Le motif large « AD_ID » couvre com.google.android.gms.permission.AD_ID et
# toute variante d'un SDK publicitaire.
MOTIF_INTERDIT='android\.permission\.INTERNET|AD_ID'

verifier() {
  local manifeste="$1"
  echo "Manifeste analysé : $manifeste"
  echo ""

  # Les permissions réellement déclarées (pour information).
  echo "Permissions déclarées :"
  grep -o 'android:name="[^"]*permission[^"]*"' "$manifeste" 2>/dev/null \
    | sed 's/android:name="//; s/"$//' | sort -u | sed 's/^/  · /' || true
  echo ""

  local lignes
  lignes=$(grep -nE "$MOTIF_INTERDIT" "$manifeste" || true)

  if [[ -z "$lignes" ]]; then
    return 0
  fi

  echo "✗✗✗ PERMISSION INTERDITE DÉTECTÉE ✗✗✗"
  echo ""
  while IFS= read -r ligne; do
    echo "  ligne $ligne"
  done <<< "$lignes"
  echo ""
  echo "POURQUOI C'EST INTERDIT (app enfant, 100% hors ligne, sans pub) :"
  echo "  · INTERNET   → l'app ne doit JAMAIS parler au réseau : hors ligne promis,"
  echo "                 et les règles Google Play Families / App Store Kids Category"
  echo "                 exigent de ne collecter aucune donnée d'enfant."
  echo "  · AD_ID      → identifiant publicitaire : interdit dans la catégorie enfant."
  echo ""
  echo "QUOI FAIRE :"
  echo "  1. Trouve le plugin qui apporte la permission :"
  echo "       grep -rn 'INTERNET\\|AD_ID' android/ ~/.pub-cache/hosted/pub.dev/*/android/src/main/AndroidManifest.xml"
  echo "     (ou regarde les dépendances récentes de pubspec.yaml)."
  echo "  2. Retire le plugin, ou remplace-le par un équivalent sans permission."
  echo "     ⚠ Ne masque PAS la permission avec tools:node=\"remove\" : le SDK qui"
  echo "       la demande est toujours là, avec son code de collecte."
  echo "  3. Relance ce script — il doit finir sur « MANIFESTE PROPRE »."
  return 1
}

# ── Manifeste fusionné : le vrai contrôle ───────────────────────────────────
# Il vit dans build/ après un `flutter build apk --release` (fait sur le poste Android).
if [[ ! -f "$MANIFESTE_FUSIONNE" && -d build ]]; then
  # Le chemin exact dépend de la version du plugin Android Gradle : on cherche
  # les variantes « merged » en préférant la release.
  # NOTE : `|| true` est obligatoire — avec set -o pipefail, le SIGPIPE reçu par
  # `find` quand `head` ferme le tuyau ferait sortir le script en erreur.
  TROUVE=$(find build -name AndroidManifest.xml -path "*merged*" 2>/dev/null \
             | grep -i release | head -1 || true)
  if [[ -z "$TROUVE" ]]; then
    TROUVE=$(find build -name AndroidManifest.xml -path "*merged*" 2>/dev/null | head -1 || true)
  fi
  if [[ -n "$TROUVE" ]]; then
    MANIFESTE_FUSIONNE="$TROUVE"
  fi
fi

if [[ -f "$MANIFESTE_FUSIONNE" ]]; then
  echo "── Contrôle du manifeste FUSIONNÉ (celui que le système lit) ──"
  echo ""
  if verifier "$MANIFESTE_FUSIONNE"; then
    echo "✓ MANIFESTE PROPRE — ni INTERNET, ni AD_ID. Prêt pour la catégorie enfant."
    exit 0
  fi
  exit 1
fi

# ── Pas de build Android ici : contrôle partiel sur le manifeste source ─────
echo "── Aucun manifeste fusionné trouvé (build Android pas encore fait ici) ──"
echo ""
if [[ ! -f "$MANIFESTE_SOURCE" ]]; then
  echo "✗ $MANIFESTE_SOURCE est introuvable — lance ce script depuis le projet."
  exit 1
fi

if verifier "$MANIFESTE_SOURCE"; then
  echo "✓ manifeste SOURCE propre."
  echo ""
  echo "⚠ CONTROLE PARTIEL : seul android/app/src/main/AndroidManifest.xml a été lu."
  echo "  Un plugin peut ajouter INTERNET ou AD_ID au moment de la FUSION, sans"
  echo "  jamais toucher ce fichier. Le contrôle complet se fait sur le poste Android :"
  echo ""
  echo "      flutter build apk --release"
  echo "      tools/verif_android_manifest.sh     # là-bas, il lira le manifeste fusionné"
  echo ""
  echo "  Sur le poste Android, le manifeste fusionné se trouve sous build/app/intermediates/"
  echo "  (dossier « merged »), et le script le trouve tout seul."
  echo "  Le refaire à chaque ajout de plugin ou mise à jour de dépendance."
  exit 0
fi
exit 1
