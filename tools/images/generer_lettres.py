#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère les chemins à suivre du moteur M3 (trace) — dont les lettres.

Écrit `lib/core/contenu/lettres/chemins_lettres.dart` : le registre complet
`cheminsTrace` (id → CheminTrace) utilisé par `DonneesTrace.cheminId`.

Deux familles de chemins, dans le MÊME fichier généré :

1. **Les sentiers et les coupes** (`sentier.ligne`, `sentier.s`,
   `sentier.boucle`, `coupe.droite`, `coupe.zigzag`) : écrits à la main dans
   ce script, en coordonnées normalisées 0..1 (y vers le bas). Pour les
   retoucher, modifier SENTIERS ci-dessous puis relancer.

2. **Les lettres** : extraites de `assets/fonts/Andika-Regular.ttf` (SIL OFL,
   dessinée pour les apprentis lecteurs — voir CREDITS.md). Pour chaque
   lettre, le contour EXTÉRIEUR du glyphe est converti en courbes cubiques,
   normalisé dans une viewBox carrée 0..1 (lettre centrée, plus grande
   dimension = 0,7), avec **y inversé** (les polices montent, SVG descend).
   Le contour commence au point le plus proche du coin haut-gauche : c'est le
   point de départ du tracé, celui où le moteur pose sa pastille.

Usage (fontTools est installé dans le venv du pack audio) :

    tools/audio/.venv/bin/python3 tools/images/generer_lettres.py
    tools/audio/.venv/bin/python3 tools/images/generer_lettres.py --apercu /tmp/lettres

`--apercu DOSSIER` écrit un SVG par chemin (ruban compris) pour vérifier à
l'œil ce que le moteur va dessiner. Le script, lui, n'écrit que le fichier
Dart sous lib/core/contenu/lettres/.
"""

import argparse
import sys
from pathlib import Path

try:
    from fontTools.pens.basePen import BasePen
    from fontTools.ttLib import TTFont
except ImportError:  # pragma: no cover - message d'aide seulement
    sys.exit(
        "fontTools manque. Installer dans le venv du pack audio :\n"
        "    tools/audio/.venv/bin/pip install fonttools"
    )

# --- Emplacements (ancrés au projet : le script marche de n'importe où) -----
RACINE = Path(__file__).resolve().parents[2]
POLICE = RACINE / "assets" / "fonts" / "Andika-Regular.ttf"
DESTINATION = RACINE / "lib" / "core" / "contenu" / "lettres" / "chemins_lettres.dart"

# --- Réglages de normalisation ----------------------------------------------
# La plus grande dimension de la lettre (largeur ou hauteur) mesure 0,7 dans
# la viewBox : la lettre est centrée dans 0..1 et garde ses proportions.
COTE_LETTRE = 0.7

# --- Les sentiers et les coupes (écrits à la main) ---------------------------
# Un path SVG simple en 0..1, et le bout du chemin où l'enfant pose son doigt
# (le premier point du tracé : la pastille de départ s'y dessine).
SENTIERS = {
    # Une ligne légèrement ondulée de gauche à droite.
    "sentier.ligne": (
        "M0.1,0.5"
        " C0.24,0.41 0.33,0.59 0.47,0.5"
        " C0.6,0.41 0.72,0.6 0.9,0.5",
        0.1,
        0.5,
    ),
    # Un grand S tranquille : on part en haut à gauche, on finit en bas.
    "sentier.s": (
        "M0.26,0.16"
        " C0.52,0.06 0.74,0.2 0.68,0.38"
        " C0.62,0.54 0.38,0.46 0.32,0.6"
        " C0.24,0.78 0.46,0.94 0.74,0.84",
        0.26,
        0.16,
    ),
    # Un grand rond : le tour complet, sans jamais lever le doigt.
    "sentier.boucle": (
        "M0.5,0.12"
        " C0.71,0.12 0.88,0.29 0.88,0.5"
        " C0.88,0.71 0.71,0.88 0.5,0.88"
        " C0.29,0.88 0.12,0.71 0.12,0.5"
        " C0.12,0.29 0.29,0.12 0.5,0.12"
        " Z",
        0.5,
        0.12,
    ),
    # Une droite horizontale au milieu : la bande à couper.
    "coupe.droite": ("M0.08,0.5 L0.92,0.5", 0.08, 0.5),
    # Un zigzag horizontal : la même bande, en plus amusant.
    "coupe.zigzag": (
        "M0.08,0.5 L0.22,0.3 L0.36,0.7 L0.5,0.3 L0.64,0.7 L0.78,0.3 L0.92,0.5",
        0.08,
        0.5,
    ),
}

# --- Les lettres -------------------------------------------------------------
# L'ordre du fichier. Les paliers de
# lib/core/contenu/activites/langue/lettre_data.dart réclament toutes ces
# lettres — y compris le « q » (palier 6), qu'on oublie facilement.
LETTRES = [
    "o", "c", "s", "u", "l",
    "a", "e", "i", "m", "n", "r",
    "t", "d", "p", "b", "q",
    "v", "w", "f", "h", "k", "x", "y", "z",
    "é", "è", "à",
]


class PenContours(BasePen):
    """Collecte les contours d'un glyphe en segments CUBIQUES.

    BasePen fait le gros du travail : les glyphes composés (les accents des
    « é », « è », « à », et le « a » à un étage de ce projet) sont décomposés,
    les points implicites des courbes TrueType sont calculés, et chaque
    courbe quadratique est convertie en cubique par la formule exacte
    c1 = p0 + 2/3(q - p0), c2 = p2 + 2/3(q - p2).

    Le sens des contours est celui de la police : le contour extérieur est
    horaire (aire négative au lacer de souliers), les trous tournent dans
    l'autre sens (aire positive).
    """

    def __init__(self, glyphe_set):
        super().__init__(glyphe_set)
        self.contours = []
        self._courant = None

    def _moveTo(self, pt):
        self._courant = [("M", pt)]

    def _lineTo(self, pt):
        self._courant.append(("L", pt))

    def _curveToOne(self, c1, c2, pt):
        self._courant.append(("C", c1, c2, pt))

    def _closePath(self):
        if self._courant:
            self.contours.append(self._courant)
            self._courant = None


def points_du_contour(contour):
    """Tous les points d'un contour, points de contrôle compris.

    Les points de contrôle débordent un peu de la courbe : le cadrage est donc
    très légèrement conservateur (la lettre est un cheveu plus petite que
    0,7). C'est voulu — la lettre ne touche jamais le bord du carré.
    """
    return [pt for segment in contour for pt in segment[1:]]


def aire(contour):
    """Aire signée (lacer de souliers) du polygone du contour."""
    points = points_du_contour(contour)
    total = 0.0
    for i, (x1, y1) in enumerate(points):
        x2, y2 = points[(i + 1) % len(points)]
        total += x1 * y2 - x2 * y1
    return total / 2.0


def cadrage(contours):
    """La fonction point police (y monte) → point normalisé (y descend)."""
    points = [pt for contour in contours for pt in points_du_contour(contour)]
    xs = [pt[0] for pt in points]
    ys = [pt[1] for pt in points]
    plus_grande = max(max(xs) - min(xs), max(ys) - min(ys))
    if plus_grande <= 0:
        plus_grande = 1.0
    echelle = COTE_LETTRE / plus_grande
    centre_x = (min(xs) + max(xs)) / 2
    centre_y = (min(ys) + max(ys)) / 2

    def transformer(pt):
        return (
            0.5 + (pt[0] - centre_x) * echelle,
            0.5 - (pt[1] - centre_y) * echelle,  # y inversé
        )

    return transformer


def nombre(valeur):
    """Un nombre Dart compact : 3 décimales, zéros inutiles retirés."""
    texte = f"{valeur:.3f}".rstrip("0").rstrip(".")
    if texte in ("", "-0", "-"):
        return "0"
    return texte


def chemin_svg(contours, transformer):
    """Le path SVG complet (plusieurs sous-chemins, un par contour).

    Chaque sous-chemin COMMENCE par un « M » posé sur le premier point du
    contour — même quand la rotation du départ a déplacé le premier segment :
    un path SVG commence toujours par un M, et c'est ce point que le moteur
    prend pour le départ du tracé.
    """
    morceaux = []
    for contour in contours:
        segments = []
        for index, segment in enumerate(contour):
            if index == 0:
                x, y = transformer(point_de_segment(contour, index))
                segments.append(f"M{nombre(x)},{nombre(y)}")
            if segment[0] == "M":
                # Le point de départ d'origine du contour : après la rotation
                # du départ, il tombe au milieu et n'a rien à dessiner.
                continue
            if segment[0] == "L":
                x, y = transformer(segment[1])
                segments.append(f" L{nombre(x)},{nombre(y)}")
            else:
                c1x, c1y = transformer(segment[1])
                c2x, c2y = transformer(segment[2])
                x, y = transformer(segment[3])
                segments.append(
                    f" C{nombre(c1x)},{nombre(c1y)}"
                    f" {nombre(c2x)},{nombre(c2y)}"
                    f" {nombre(x)},{nombre(y)}"
                )
        segments.append(" Z")
        morceaux.append("".join(segments))
    return "".join(morceaux)


def point_de_segment(contour, index):
    """Le premier point du segment [index] du contour (contour fermé).

    Le « M » porte son point de départ ; les autres segments partent de la fin
    du précédent — et le premier segment d'un contour TOURNÉ part de la fin du
    dernier, puisque le contour se referme.
    """
    if index == 0:
        if contour[0][0] == "M":
            return contour[0][1]
        return contour[-1][-1]
    return contour[index - 1][-1]


def rotation_depart(contour, transformer):
    """Réordonne les segments pour que le tracé COMMENCE au coin haut-gauche.

    Le premier point du path est le point de départ : la pastille du moteur
    s'y pose, et le progrès du doigt part de là. On commence donc le contour à
    l'extrémité de segment la plus proche du coin (0,0) — un point EXACT du
    contour, pas un point de contrôle.

    Renvoie (contour réordonné, départ en 0..1).
    """
    meilleur = 0
    meilleure_distance = None
    for index in range(len(contour)):
        x, y = transformer(point_de_segment(contour, index))
        distance = x * x + y * y  # coin haut-gauche = (0,0)
        if meilleure_distance is None or distance < meilleure_distance:
            meilleure_distance = distance
            meilleur = index
    x, y = transformer(point_de_segment(contour, meilleur))
    return contour[meilleur:] + contour[:meilleur], (x, y)


def lettre_vers_chemin(caractere, police):
    """(svg, depart_x, depart_y) d'une lettre, ou (None, raison si échec)."""
    cmap = police.getBestCmap()
    nom = cmap.get(ord(caractere))
    if nom is None:
        return None, "absente de la police"

    glyphe_set = police.getGlyphSet()
    pen = PenContours(glyphe_set)
    glyphe_set[nom].draw(pen)
    if not pen.contours:
        return None, "aucun contour"

    # Le contour extérieur (aire négative) : on écarte les trous du « o », du
    # « a », du « d »… mais on GARDE les morceaux séparés qui font la lettre
    # (le point du « i », l'accent du « é », la barre du « t », les bras du
    # « k »).
    pleins = [contour for contour in pen.contours if aire(contour) < 0]
    if not pleins:
        return None, "aucun contour extérieur exploitable"

    # Le plus grand d'abord (le corps de la lettre), puis les morceaux du haut
    # vers le bas : on trace le « i » puis son point, le « é » puis son
    # accent — jamais l'inverse.
    pleins.sort(key=aire)
    principal, *reste = pleins
    reste.sort(key=lambda c: -max(pt[1] for pt in points_du_contour(c)))
    contours = [principal, *reste]

    transformer = cadrage(contours)
    # Le départ est cherché sur le PREMIER contour : c'est là que le tracé
    # commence, et donc là que la pastille doit inviter le doigt.
    principal, depart = rotation_depart(principal, transformer)
    contours = [principal, *reste]

    return chemin_svg(contours, transformer), depart[0], depart[1]


def litteral_dart(svg, largeur=68):
    """Le path en morceaux de ~[largeur] caractères (sans les guillemets).

    Les morceaux se recollent tels quels, espaces compris : Dart juxtapose
    les littéraux et le path reconstruit est identique au caractère près.
    """
    if len(svg) <= largeur:
        return [svg]
    morceaux = []
    reste = svg
    while len(reste) > largeur:
        coupe = reste.rfind(" ", 0, largeur + 1)
        if coupe <= 0:
            coupe = largeur
            morceaux.append(reste[:coupe])
            reste = reste[coupe:]
            continue
        morceaux.append(reste[: coupe + 1])  # l'espace reste avec son morceau
        reste = reste[coupe + 1:]
    morceaux.append(reste)
    return morceaux


def entree_dart(identifiant, svg, depart_x, depart_y):
    """Une entrée du registre, en Dart."""
    lignes = [f"  '{identifiant}': CheminTrace(", f"    '{identifiant}',"]
    morceaux = litteral_dart(svg)
    lignes += [f"    '{morceau}'" for morceau in morceaux[:-1]]
    lignes.append(f"    '{morceaux[-1]}',")
    lignes.append(f"    {nombre(depart_x)},")
    lignes.append(f"    {nombre(depart_y)},")
    lignes.append("  ),")
    return "\n".join(lignes)


def entete():
    return '''// ═══════════════════════════════════════════════════════════════════════
// GÉNÉRÉ par tools/images/generer_lettres.py — NE PAS ÉDITER À LA MAIN.
//
// Les sentiers et les coupes sont écrits dans le script (constante SENTIERS) ;
// les lettres sont extraites des contours de la police Andika
// (assets/fonts/Andika-Regular.ttf, SIL OFL — voir CREDITS.md), converties en
// courbes cubiques et normalisées en 0..1 (y vers le bas). Pour changer quoi
// que ce soit ici : modifier le script, puis relancer
//
//     tools/audio/.venv/bin/python3 tools/images/generer_lettres.py
//
// Ce fichier est du Dart PUR (aucun import) : il vit sous lib/core/contenu.
// ═══════════════════════════════════════════════════════════════════════

/// Un chemin à suivre, en coordonnées normalisées 0..1 (y vers le BAS).
class CheminTrace {
  /// Clé du chemin dans [cheminsTrace] ('lettre.o', 'sentier.ligne'…).
  final String id;

  /// « M0.2,0.3 C… » — path SVG dans un viewBox 0 0 1 1 (y vers le bas).
  /// Un chemin peut porter plusieurs sous-chemins : les lettres faites de
  /// morceaux (le « i » et son point, le « é » et son accent) se suivent
  /// dans l'ordre où le doigt doit les tracer.
  final String svgPath;

  /// Point de départ conseillé (0..1) : le premier point du tracé, là où la
  /// pastille de départ invite le doigt.
  final double departX;
  final double departY;

  const CheminTrace(this.id, this.svgPath, this.departX, this.departY);
}

/// Tous les chemins à suivre : sentiers, bandes de coupe, et les lettres.
/// Les clés sont les `DonneesTrace.cheminId` des manches.
const cheminsTrace = <String, CheminTrace>{
'''


def apercu_svg(svg, depart_x, depart_y, taille=360):
    """Un SVG de contrôle : le fond crème, le ruban, la pastille de départ."""
    marge = 6  # le trait du ruban déborde un peu : on le laisse respirer
    interieur = taille - 2 * marge
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" '
        f'viewBox="0 0 {taille} {taille}" width="{taille}" height="{taille}">\n'
        f'  <rect width="{taille}" height="{taille}" fill="#FDF6E3"/>\n'
        f'  <g transform="translate({marge},{marge}) scale({interieur})">\n'
        f'    <path d="{svg}" fill="none" stroke="#C9BCA4" stroke-width="0.06"'
        f' stroke-linecap="round" stroke-linejoin="round"/>\n'
        f'    <path d="{svg}" fill="none" stroke="#F3E8CF" stroke-width="0.048"'
        f' stroke-linecap="round" stroke-linejoin="round"/>\n'
        f"  </g>\n"
        f'  <circle cx="{marge + depart_x * interieur}"'
        f' cy="{marge + depart_y * interieur}" r="{0.026 * interieur}"'
        f' fill="#F6C445" stroke="#4A3B2A" stroke-width="2"/>\n'
        f"</svg>\n"
    )


def main():
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument(
        "--apercu",
        metavar="DOSSIER",
        help="écrit un SVG par chemin (pour regarder avant de livrer)",
    )
    args = analyseur.parse_args()

    if not POLICE.is_file():
        sys.exit(f"Police introuvable : {POLICE}")

    sentiers = list(SENTIERS.items())
    lettres = []
    manquantes = []
    police = TTFont(POLICE)
    for caractere in LETTRES:
        svg, depart_x, depart_y = lettre_vers_chemin(caractere, police)
        if svg is None:
            manquantes.append((caractere, depart_x))
            continue
        lettres.append((f"lettre.{caractere}", svg, depart_x, depart_y))

    corps = ["  // ── Sentiers (le chemin du doigt) — écrits à la main ──\n"]
    for identifiant, (svg, x, y) in sentiers:
        if not identifiant.startswith("coupe."):
            corps.append(entree_dart(identifiant, svg, x, y) + "\n")
    corps.append(
        "\n  // ── Bandes de coupe (découper avec le doigt) — écrites à la main ──\n"
    )
    for identifiant, (svg, x, y) in sentiers:
        if identifiant.startswith("coupe."):
            corps.append(entree_dart(identifiant, svg, x, y) + "\n")
    corps.append(
        "\n  // ── Lettres (la lettre en pâte à modeler) — générées depuis Andika ──\n"
    )
    for identifiant, svg, x, y in lettres:
        corps.append(entree_dart(identifiant, svg, x, y) + "\n")

    DESTINATION.parent.mkdir(parents=True, exist_ok=True)
    DESTINATION.write_text(entete() + "".join(corps) + "};\n", encoding="utf-8")

    print(f"✅ {DESTINATION.relative_to(RACINE)}")
    print(f"   {len(sentiers)} sentiers et coupes écrits à la main")
    print(f"   {len(lettres)} lettres générées depuis {POLICE.name}")
    for caractere, raison in manquantes:
        print(f"   ⚠️  « {caractere} » retirée : {raison}")

    if args.apercu:
        dossier = Path(args.apercu)
        dossier.mkdir(parents=True, exist_ok=True)
        for identifiant, (svg, x, y) in sentiers:
            (dossier / f"{identifiant}.svg").write_text(
                apercu_svg(svg, x, y), encoding="utf-8"
            )
        for identifiant, svg, x, y in lettres:
            (dossier / f"{identifiant}.svg").write_text(
                apercu_svg(svg, x, y), encoding="utf-8"
            )
        print(f"   aperçu SVG dans {dossier}")


if __name__ == "__main__":
    main()
