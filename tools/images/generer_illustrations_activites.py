#!/usr/bin/env python3
"""Génère les illustrations de carte des activités (act-<jeu>.svg).

Chaque carte = une pastille arrondie colorée + l'illustration Twemoji d'un
concept, centrée. Les fichiers produits vivent dans assets/images/concepts/
(déjà déclaré au pubspec) et sont référencés par `Activite.illustration`.

Usage : python3 tools/images/generer_illustrations_activites.py [--forcer]
"""
import argparse
import re
import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
DOSSIER = RACINE / "assets" / "images" / "concepts"

# Activité → (concept à illustrer, couleur du fond, couleur du contour)
CARTES = {
    "act-table.svg": ("assiette", "#4A90D9"),      # ciel
    "act-habiller.svg": ("manteau", "#9C6BAF"),    # prune
    "act-sac.svg": ("sac", "#4CAF7D"),             # verdure
    "act-bus.svg": ("bus", "#F6C445"),             # soleil
    "act-graine.svg": ("graine", "#4CAF7D"),       # verdure
    "act-journuit.svg": ("soleil", "#4A90D9"),     # ciel
    "act-histoire.svg": ("poule", "#4A90D9"),      # ciel
    "act-milo.svg": ("visage_content", "#E8734A"),  # corail
    "act-tours.svg": ("enfant", "#9C6BAF"),        # prune
    # ── Vague 2 (création, tracés, rythme, sons) ──
    "act-peinture.svg": ("couleur", "#E8734A"),   # corail
    "act-papillon.svg": ("papillon", "#9C6BAF"),  # prune
    "act-theatre.svg": ("enfant", "#4A90D9"),     # ciel
    "act-lettre.svg": ("serpent", "#4CAF7D"),     # verdure
    "act-chemin.svg": ("chemin", "#4A90D9"),      # ciel
    "act-couper.svg": ("pizza", "#F6C445"),       # soleil
    "act-rythme.svg": ("tambour", "#E8734A"),     # corail
    "act-monstre.svg": ("monstre", "#9C6BAF"),    # prune
    "act-bouche.svg": ("vache", "#4CAF7D"),       # verdure
    "act-syllabes.svg": ("grenouille", "#4A90D9"),# ciel
    # ── Vague 3 (langue, logique, monde, émotions) ──
    "act-motcache.svg": ("chat", "#4CAF7D"),      # verdure
    "act-intrus.svg": ("loup", "#E8734A"),        # corail
    "act-code.svg": ("souris", "#4A90D9"),        # ciel
    "act-manque.svg": ("ballon", "#F6C445"),      # soleil
    "act-sialors.svg": ("parapluie", "#4A90D9"),  # ciel
    "act-sens.svg": ("poule", "#4CAF7D"),         # verdure
    "act-petit.svg": ("poisson", "#4A90D9"),      # ciel
    "act-spatial.svg": ("maison", "#F6C445"),     # soleil
    "act-mots.svg": ("demander", "#E8734A"),      # corail
    "act-animal.svg": ("monstre", "#9C6BAF"),     # prune
    # ── Vague 4 (maths et monde) ──
    "act-phrase.svg": ("chat", "#E8734A"),        # corail
    "act-balance.svg": ("balance", "#F6C445"),    # soleil
    "act-gateau.svg": ("gateau", "#E8734A"),      # corail
    "act-perles.svg": ("orange", "#4CAF7D"),      # verdure
    "act-grenouille.svg": ("grenouille", "#4CAF7D"),# verdure
    "act-plusmoins.svg": ("raisin", "#9C6BAF"),   # prune
    "act-formes.svg": ("forme_carre", "#9C6BAF"), # prune
    "act-heure.svg": ("attendre", "#4A90D9"),     # ciel
    "act-flotte.svg": ("bateau", "#4A90D9"),      # ciel
    "act-ombres.svg": ("doudou", "#9C6BAF"),      # prune
    # ── Vague 5 (les 8 derniers) ──
    "act-ordres.svg": ("sac", "#E8734A"),         # corail
    "act-fenetre.svg": ("vent", "#4A90D9"),       # ciel
    "act-hauteur.svg": ("oiseau", "#9C6BAF"),     # prune
    "act-chanson.svg": ("grelot", "#E8734A"),     # corail
    "act-mains.svg": ("savon", "#4CAF7D"),        # verdure
    "act-recette.svg": ("couteau", "#F6C445"),    # soleil
    "act-ranger.svg": ("livre", "#9C6BAF"),       # prune
    "act-traverser.svg": ("panneau_stop", "#4A90D9"),# ciel
}


def contenu_svg(chemin):
    """Le contenu interne d'un SVG Twemoji (sans la balise <svg> externe)."""
    texte = chemin.read_text(encoding="utf-8")
    interieur = re.sub(r"^.*?<svg[^>]*>", "", texte, count=1, flags=re.S)
    interieur = re.sub(r"</svg>\s*$", "", interieur, count=1, flags=re.S)
    return interieur.strip()


def carte(concept, couleur):
    """Une carte 128x128 : pastille arrondie + l'illustration centrée."""
    source = DOSSIER / f"{concept}.svg"
    if not source.is_file():
        raise FileNotFoundError(source)
    # Le Twemoji dessine dans un viewBox 36x36 : mis à l'échelle ici.
    illustration = contenu_svg(source)
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <rect x="8" y="8" width="112" height="112" rx="30" fill="#FDF6E3" stroke="{couleur}" stroke-width="7"/>
  <g transform="translate(30,30) scale(1.89)">
    {illustration}
  </g>
</svg>
"""


def main():
    analyseur = argparse.ArgumentParser(description=__doc__)
    analyseur.add_argument("--forcer", action="store_true",
                           help="réécrit les cartes déjà présentes")
    args = analyseur.parse_args()

    echecs = []
    for nom, (concept, couleur) in CARTES.items():
        cible = DOSSIER / nom
        if cible.is_file() and not args.forcer:
            print(f"[déjà là] {nom}")
            continue
        try:
            cible.write_text(carte(concept, couleur), encoding="utf-8")
            print(f"[créé]     {nom} ({concept}, {couleur})")
        except FileNotFoundError as erreur:
            echecs.append(f"{nom} : illustration absente {erreur}")

    if echecs:
        print("\nÉCHECS :")
        for echec in echecs:
            print(f"  - {echec}")
        return 1
    print(f"\n{len(CARTES)} carte(s) OK dans {DOSSIER.relative_to(RACINE)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
