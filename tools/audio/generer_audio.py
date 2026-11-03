#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère les voix pré-enregistrées de l'application « jeux-enfants ».

Entrée : tools/audio/scripts.json (export du contenu Dart, écrit par un autre outil).
Sortie : assets/audio/<deck>/….mp3 + assets/audio/<deck>/manifest.json lu par l'app.
Bibliothèque standard uniquement (aucune dépendance à installer).

  python3 tools/audio/generer_audio.py --rapport
  python3 tools/audio/generer_audio.py --fournisseur azure
  python3 tools/audio/generer_audio.py --verifier
  python3 tools/audio/generer_audio.py --probe act.rimes.titre
"""

import argparse
import base64
import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

# --- Emplacements (ancrés au projet : le script marche depuis n'importe quel cwd) ---
RACINE_OUTILS = Path(__file__).resolve().parent      # tools/audio
RACINE_PROJET = RACINE_OUTILS.parent.parent          # racine du projet
DOSSIER_CACHE = RACINE_OUTILS / ".cache"             # MP3 réutilisables par empreinte
DOSSIER_ECOUTES = RACINE_OUTILS / "ecoutes"          # extraits produits par --probe

FORMAT_AZURE = "audio-24khz-48kbitrate-mono-mp3"
PRIX_AZURE_PAR_MILLION = 16.0        # $ / million de caractères
CATEGORIES = {"consigne": "consignes", "retour": "retours", "lexique": "lexique",
              "phrase": "phrases", "chanson": "chansons"}
CATEGORIE_DEFAUT = "divers"

# MP3 silencieux d'une seconde, mono 24 kHz (MPEG-2 Layer III, 984 octets) : en-tête
# 0xFF 0xF3 suivi de 41 trames identiques de 24 octets à données nulles, ce qui décode
# en silence. Une trame fait 24 octets = 18 caractères base64 sans remplissage, donc
# répéter son base64 donne exactement le base64 du fichier entier. Fabriqué hors ligne,
# puis validé avec afinfo, afplay et un décodage afconvert en WAV.
TRAME_SILENCIEUSE_B64 = "//MUxAAAAAAAAAAAAAAAAAAAAAAAAAAA"
MP3_SILENCIEUX_B64 = TRAME_SILENCIEUSE_B64 * 41


class ErreurAudio(Exception):
    """Erreur attendue : message clair pour l'utilisateur, sortie non nulle."""


# --- Petits utilitaires -----------------------------------------------------
def maintenant_iso():
    """Horodatage ISO 8601 en UTC, ex. 2026-10-16T18:00:00Z."""
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def ecrire_atomique(destination, octets):
    """Écrit via un temporaire puis os.replace : jamais de fichier à moitié écrit."""
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporaire = destination.with_name(destination.name + ".tmp")
    with open(temporaire, "wb") as flux:
        flux.write(octets)
    os.replace(temporaire, destination)


def lire_json(chemin):
    """Lit un JSON en UTF-8."""
    with open(chemin, "r", encoding="utf-8") as flux:
        return json.load(flux)


def ecrire_json(chemin, donnees):
    """Écrit un JSON lisible et stable (indent=2, UTF-8, sans échappement ASCII)."""
    chemin = Path(chemin)
    chemin.parent.mkdir(parents=True, exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as flux:
        flux.write(json.dumps(donnees, indent=2, ensure_ascii=False) + "\n")


def echapper_xml(texte):
    """Échappe un texte pour l'insérer dans du XML."""
    return (texte.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                 .replace('"', "&quot;").replace("'", "&apos;"))


def formater_octets(nombre):
    """2 180 o — séparateur de milliers à la française."""
    return "{:,}".format(nombre).replace(",", " ")


def formater_dollars(montant):
    """0,13 $ — arrondi au cent, virgule décimale française."""
    return ("%.2f" % montant).replace(".", ",")


# --- Lecture de scripts.json ------------------------------------------------
def charger_scripts(chemin):
    """Valide scripts.json ; renvoie (deck, voix par défaut, clips normalisés, brut)."""
    if not Path(chemin).is_file():
        raise ErreurAudio("scripts.json introuvable : %s" % chemin)
    donnees = lire_json(chemin)

    deck = str(donnees.get("deck") or "").strip()
    if not deck:
        raise ErreurAudio("scripts.json : le champ « deck » est manquant.")
    clips = donnees.get("clips")
    if not isinstance(clips, list) or not clips:
        raise ErreurAudio("scripts.json : la liste « clips » est vide ou manquante.")
    voix_defaut = str((donnees.get("voix") or {}).get("principale") or "").strip()
    if not voix_defaut:
        raise ErreurAudio("scripts.json : « voix.principale » est manquant.")

    vus, normalises = set(), []
    for clip in clips:
        identifiant = str(clip.get("id") or "").strip()
        texte = str(clip.get("texte") or "").strip()
        if not identifiant:
            raise ErreurAudio("scripts.json : un clip n'a pas d'identifiant « id ».")
        if identifiant in vus:
            raise ErreurAudio("scripts.json : identifiant en double « %s »." % identifiant)
        if not texte:
            raise ErreurAudio("scripts.json : le clip « %s » n'a pas de texte." % identifiant)
        vus.add(identifiant)
        prosodie = clip.get("prosodie") or {}
        normalises.append({
            "id": identifiant,
            "texte": texte,
            "categorie": str(clip.get("categorie") or "").strip().lower(),
            "activite": str(clip.get("activite") or "").strip(),
            "rate": str(prosodie.get("rate") or "+0%").strip(),
            "pitch": str(prosodie.get("pitch") or "+0%").strip(),
            "style": str(clip.get("style") or "").strip(),
        })
    return deck, voix_defaut, normalises, donnees


def dossier_voix(voix):
    """Dossier d'une voix : « fr-CA-AntoineNeural » → « antoine ».

    Chaque voix a SON jeu de clips : assets/audio/<deck>/<voix>/… — c'est
    ce qui permet de choisir la voix (femme/homme) dans l'app sans dupliquer
    le contenu, et de remplacer un clip par une voix humaine au besoin.
    """
    nom = voix.strip().split("-")[-1]
    if nom.lower().endswith("neural"):
        nom = nom[: -len("neural")]
    return nom.lower() or "voix"


def chemin_relatif(deck, voix, clip):
    """Chemin du MP3 relatif à assets/audio, ex. « qc/antoine/lexique/chapeau.mp3 ».

    Le dossier suit <deck>/<voix>, puis la catégorie ; le nom vient de l'id
    préfixe retiré. Pour les consignes, l'activité (champ « activite » sinon
    2e segment de l'id) devient un sous-dossier : act.rimes.titre →
    consignes/rimes/titre.mp3, consigne.repete → consignes/repete.mp3.
    Catégorie inconnue ou absente → divers/<id-complet>.mp3.
    """
    prefixe_voix = "%s/%s" % (deck, dossier_voix(voix))
    identifiant = clip["id"]
    dossier = CATEGORIES.get(clip["categorie"])
    if not dossier:
        return "%s/%s/%s.mp3" % (prefixe_voix, CATEGORIE_DEFAUT, identifiant)

    morceaux = identifiant.split(".")
    if clip["categorie"] == "consigne":
        activite = clip.get("activite") or ""
        if not activite and morceaux[0] == "act" and len(morceaux) >= 3:
            activite = morceaux[1]
        if morceaux[0] in ("act", "consigne"):
            morceaux = morceaux[1:]
        if activite and morceaux and morceaux[0] == activite:
            morceaux = morceaux[1:]
        nom = ".".join(morceaux) or identifiant
        return "%s/%s/%s%s.mp3" % (prefixe_voix, dossier, activite + "/" if activite else "", nom)

    if len(morceaux) >= 2:
        morceaux = morceaux[1:]
    return "%s/%s/%s.mp3" % (prefixe_voix, dossier, ".".join(morceaux) or identifiant)


def calculer_empreinte(deck, voix, style, rate, pitch, texte):
    """sha1 tronqué à 8 caractères hexadécimaux : identifie le contenu audio."""
    brut = "|".join([deck, voix, style, rate, pitch, texte]).encode("utf-8")
    return hashlib.sha1(brut).hexdigest()[:8]


# --- Fournisseurs de synthèse ----------------------------------------------
def synthetiser_dummy(texte, voix, rate, pitch, style):
    """MP3 silencieux embarqué : ni réseau ni clé, pour les tests et la structure."""
    return base64.b64decode(MP3_SILENCIEUX_B64)


def construire_ssml(texte, voix, rate, pitch, style):
    """Construit le SSML Azure (texte échappé, sans mstts si le style est vide)."""
    interieur = '<prosody rate="%s" pitch="%s">%s</prosody>' % (rate, pitch, echapper_xml(texte))
    declaration = ""
    if style:
        interieur = ('<mstts:express-as style="%s">%s</mstts:express-as>'
                     % (echapper_xml(style), interieur))
        declaration = ' xmlns:mstts="https://www.w3.org/2001/mstts"'
    return ('<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis"%s xml:lang="fr-CA">'
            '<voice name="%s">%s</voice></speak>' % (declaration, echapper_xml(voix), interieur))


def synthetiser_azure(texte, voix, rate, pitch, style):
    """POST Azure Speech ; exige AZURE_SPEECH_KEY et AZURE_SPEECH_REGION."""
    cle = (os.environ.get("AZURE_SPEECH_KEY") or "").strip()
    region = (os.environ.get("AZURE_SPEECH_REGION") or "").strip()
    manquantes = [nom for nom, valeur in (("AZURE_SPEECH_KEY", cle), ("AZURE_SPEECH_REGION", region))
                  if not valeur]
    if manquantes:
        raise ErreurAudio("Variables d'environnement manquantes pour le fournisseur azure : %s\n"
                          "  export AZURE_SPEECH_KEY=…  et  export AZURE_SPEECH_REGION=canadacentral"
                          % ", ".join(manquantes))

    requete = urllib.request.Request(
        "https://%s.tts.speech.microsoft.com/cognitiveservices/v1" % region,
        data=construire_ssml(texte, voix, rate, pitch, style).encode("utf-8"),
        headers={"Ocp-Apim-Subscription-Key": cle,
                 "Content-Type": "application/ssml+xml",
                 "X-Microsoft-OutputFormat": FORMAT_AZURE,
                 "User-Agent": "jeux-enfants-audio/1.0"},
        method="POST")
    try:
        with urllib.request.urlopen(requete, timeout=60) as reponse:
            return reponse.read()
    except urllib.error.HTTPError as erreur:
        raise ErreurAudio("Azure a refusé la requête (HTTP %s) : %s"
                          % (erreur.code, erreur.read().decode("utf-8", "replace")[:300]))
    except urllib.error.URLError as erreur:
        raise ErreurAudio("Connexion à Azure impossible : %s" % erreur.reason)


def _pitch_edge(pitch):
    """edge-tts exige le pitch en Hz (ex. « +4Hz ») ; nos textes sont en %
    (format Azure, ex. « +2% »). Conversion approchée : 1 % ≈ 2 Hz."""
    correspondance = re.match(r"^([+-]?\d+(?:\.\d+)?)%$", pitch.strip())
    if not correspondance:
        return "+0Hz"
    hertz = round(float(correspondance.group(1)) * 2)
    return "%+dHz" % hertz


def synthetiser_edge(texte, voix, rate, pitch, style):
    """Appelle la CLI edge-tts (voix gratuites, sans compte Azure) ; style ignoré."""
    binaire = shutil.which("edge-tts")
    if binaire is None:
        local = RACINE_OUTILS / ".venv" / "bin" / "edge-tts"
        binaire = str(local) if local.is_file() else None
    if binaire is None:
        raise ErreurAudio(
            "edge-tts introuvable. Installe-le une fois :\n"
            "  python3 -m venv tools/audio/.venv && tools/audio/.venv/bin/pip install edge-tts\n"
            "puis relance avec : tools/audio/.venv/bin/python tools/audio/generer_audio.py …")

    temporaire = DOSSIER_CACHE / "edge-temporaire.mp3"
    DOSSIER_CACHE.mkdir(parents=True, exist_ok=True)
    resultat = subprocess.run([binaire, "--voice", voix, "--rate=%s" % rate,
                               "--pitch=%s" % _pitch_edge(pitch),
                               "--text", texte, "--write-media", str(temporaire)],
                              capture_output=True, text=True)
    if resultat.returncode != 0:
        raise ErreurAudio("edge-tts a échoué (code %s) : %s"
                          % (resultat.returncode, resultat.stderr.strip()[:300]))
    octets = temporaire.read_bytes()
    temporaire.unlink(missing_ok=True)
    if not octets:
        raise ErreurAudio("edge-tts n'a produit aucun octet.")
    return octets


FOURNISSEURS = {"dummy": synthetiser_dummy, "azure": synthetiser_azure, "edge": synthetiser_edge}


def obtenir_mp3(fournisseur, texte, voix, rate, pitch, style, empreinte):
    """Renvoie (octets, origine) ; réutilise le cache pour la même empreinte.

    Le fournisseur « dummy » n'utilise jamais le cache : il ne coûte rien et ses
    extraits muets ne doivent pas être resservis plus tard pour une vraie voix.
    """
    if fournisseur == "dummy":
        return synthetiser_dummy(texte, voix, rate, pitch, style), "fournisseur"
    cache = DOSSIER_CACHE / (empreinte + ".mp3")
    if cache.is_file():
        return cache.read_bytes(), "cache"
    octets = FOURNISSEURS[fournisseur](texte, voix, rate, pitch, style)
    ecrire_atomique(cache, octets)
    return octets, "fournisseur"


def duree_ms(chemin):
    """Durée en millisecondes via ffprobe si présent, sinon None (valeur inconnue)."""
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        return None
    try:
        resultat = subprocess.run([ffprobe, "-v", "error", "-show_entries", "format=duration",
                                   "-of", "default=noprint_wrappers=1:nokey=1", str(chemin)],
                                  capture_output=True, text=True, check=True)
        return int(round(float(resultat.stdout.strip()) * 1000))
    except (subprocess.SubprocessError, ValueError):
        return None


# --- Manifest ---------------------------------------------------------------
def charger_manifest(chemin, deck, donnees_scripts):
    """Charge le manifest existant ou en renvoie un neuf."""
    if Path(chemin).is_file():
        manifest = lire_json(chemin)
        if not isinstance(manifest.get("clips"), dict):
            manifest["clips"] = {}
        return manifest
    return {"version": 1, "deck": deck, "voix": donnees_scripts.get("voix") or {},
            "genere": maintenant_iso(), "clips": {}}


def ecrire_manifest(chemin, manifest):
    """Écrit le manifest, entrées triées par identifiant (diffs Git propres)."""
    manifest["clips"] = {cle: manifest["clips"][cle] for cle in sorted(manifest["clips"])}
    ecrire_json(chemin, manifest)


def clip_a_generer(clip, entree, chemin_fichier, tout, force):
    """Renvoie (à générer ?, raison) selon l'état du manifest et du fichier."""
    if force:
        return True, "forcé"
    if entree is not None and entree.get("statut") == "enregistre":
        return False, "enregistre"
    if entree is None:
        return True, "absent du manifest"
    if not chemin_fichier.is_file():
        return True, "fichier manquant"
    if entree.get("empreinte") != clip["empreinte"]:
        return True, "empreinte changée"
    return (True, "régénération complète (--tout)") if tout else (False, "à jour")


# --- Commandes --------------------------------------------------------------
def executer_generation(args, deck, voix_defaut, clips, manifest, manifest_chemin, assets, scripts_bruts):
    """Génère les clips nécessaires puis met le manifest à jour."""
    voix = args.voix or voix_defaut
    entrees, total = manifest["clips"], len(clips)
    largeur, comptes = len(str(total)), {"generes": 0, "ajour": 0, "proteges": 0}

    for position, clip in enumerate(clips, start=1):
        identifiant = clip["id"]
        relatif = chemin_relatif(deck, voix, clip)
        clip["empreinte"] = calculer_empreinte(deck, voix, clip["style"], clip["rate"],
                                               clip["pitch"], clip["texte"])
        entree, destination = entrees.get(identifiant), assets / relatif
        prefixe = "[%*d/%d]" % (largeur, position, total)
        a_faire, raison = clip_a_generer(clip, entree, destination, args.tout,
                                         args.forcer == identifiant)

        if not a_faire:
            if raison != "enregistre":
                comptes["ajour"] += 1
                print("%s %s → à jour" % (prefixe, identifiant))
                continue
            comptes["proteges"] += 1
            alerte = "" if (assets / (entree.get("fichier") or "")).is_file() else \
                "  ⚠ fichier absent (utilise --forcer %s)" % identifiant
            print("%s %s → protégé (enregistre)%s" % (prefixe, identifiant, alerte))
            continue

        octets, origine = obtenir_mp3(args.fournisseur, clip["texte"], voix, clip["rate"],
                                      clip["pitch"], clip["style"], clip["empreinte"])
        ecrire_atomique(destination, octets)
        entrees[identifiant] = {
            "fichier": relatif, "texte": clip["texte"], "voix": voix,
            "prosodie": {"rate": clip["rate"], "pitch": clip["pitch"]}, "style": clip["style"],
            "empreinte": clip["empreinte"], "statut": "genere", "octets": len(octets),
            "dureeMs": 1000 if args.fournisseur == "dummy" else duree_ms(destination)}
        comptes["generes"] += 1
        print("%s %s → %s (%s o)%s" % (prefixe, identifiant, relatif,
                                       formater_octets(len(octets)),
                                       " [cache]" if origine == "cache" else ""))

    manifest["version"] = 1
    manifest["deck"] = deck
    manifest["voix"] = scripts_bruts.get("voix") or manifest.get("voix") or {}
    manifest["genere"] = maintenant_iso()
    ecrire_manifest(manifest_chemin, manifest)

    print("\n%d généré(s), %d à jour, %d protégé(s) (enregistre) — manifest : %s"
          % (comptes["generes"], comptes["ajour"], comptes["proteges"], manifest_chemin))
    orphelines = sorted(set(entrees) - {clip["id"] for clip in clips})
    if orphelines:
        print("Note : %d entrée(s) du manifest ne sont plus dans scripts.json (conservées)."
              % len(orphelines))
    return 0


def commande_rapport(args, deck, voix_defaut, clips, manifest, assets):
    """Affiche les chiffres utiles ; n'appelle aucun fournisseur."""
    voix, entrees = args.voix or voix_defaut, manifest["clips"]
    a_generer, proteges = [], []
    for clip in clips:
        clip["empreinte"] = calculer_empreinte(deck, voix, clip["style"], clip["rate"],
                                               clip["pitch"], clip["texte"])
        a_faire, raison = clip_a_generer(clip, entrees.get(clip["id"]),
                                         assets / chemin_relatif(deck, voix, clip), args.tout,
                                         args.forcer == clip["id"])
        if raison == "enregistre":
            proteges.append(clip["id"])
        if a_faire:
            a_generer.append(clip)

    cout = round(sum(len(c["texte"]) for c in a_generer) * PRIX_AZURE_PAR_MILLION / 1_000_000.0, 2)
    print("Rapport audio — deck « %s », voix « %s », fournisseur « %s »" % (deck, voix, args.fournisseur))
    print("  Clips dans scripts.json        : %d" % len(clips))
    print("  À générer (%s) : %d" % ("--tout" if args.tout else "seulement manquants", len(a_generer)))
    print("  Caractères (tous les clips)    : %s" % formater_octets(sum(len(c["texte"]) for c in clips)))
    print("  Caractères à synthétiser       : %s" % formater_octets(sum(len(c["texte"]) for c in a_generer)))
    print("  Coût Azure estimé (%s $/M)   : %s $"
          % (formater_dollars(PRIX_AZURE_PAR_MILLION), formater_dollars(cout)))
    print("  Clips « enregistre » protégés  : %s" % (len(proteges) if proteges else "aucun"))
    for identifiant in proteges:
        print("      - %s" % identifiant)
    return 0


def commande_verifier(args, deck, voix_defaut, clips, manifest, manifest_chemin, assets):
    """Compare manifest ↔ fichiers ↔ scripts.json ; sortie non nulle en cas d'écart."""
    voix, entrees, ecarts, declares = args.voix or voix_defaut, manifest["clips"], [], set()
    for identifiant in sorted(entrees):
        relatif = entrees[identifiant].get("fichier") or ""
        if not relatif:
            ecarts.append("entrée « %s » sans champ « fichier »" % identifiant)
            continue
        declares.add(relatif)
        if not (assets / relatif).is_file():
            ecarts.append("entrée « %s » sans fichier : %s" % (identifiant, relatif))

    racine_deck = assets / deck / dossier_voix(voix)
    if racine_deck.is_dir():
        for fichier in sorted(racine_deck.rglob("*.mp3")):
            relatif = fichier.relative_to(assets).as_posix()
            if relatif not in declares:
                ecarts.append("fichier sans entrée au manifest : %s" % relatif)

    for clip in clips:
        clip["empreinte"] = calculer_empreinte(deck, voix, clip["style"], clip["rate"],
                                               clip["pitch"], clip["texte"])
        entree = entrees.get(clip["id"])
        if entree is None:
            ecarts.append("clip absent du manifest : %s" % clip["id"])
        elif entree.get("empreinte") != clip["empreinte"]:
            ecarts.append("empreinte divergente : %s (statut %s)"
                          % (clip["id"], entree.get("statut") or "genere"))

    print("Vérification — %d clip(s) dans scripts.json, %d entrée(s) au manifest : %s"
          % (len(clips), len(entrees), manifest_chemin))
    if not ecarts:
        print("  Aucun écart : manifest, fichiers et scripts.json sont cohérents.")
        return 0
    print("  %d écart(s) :" % len(ecarts))
    for ecart in ecarts:
        print("      - %s" % ecart)
    return 1


def commande_probe(args, deck, voix_defaut, clips):
    """Génère un seul extrait dans tools/audio/ecoutes/, sans toucher aux assets."""
    clip = next((c for c in clips if c["id"] == args.probe), None)
    if clip is None and not args.texte:
        raise ErreurAudio("clip « %s » absent de scripts.json : ajoute --texte \"…\" pour écouter une voix."
                          % args.probe)
    texte = args.texte or clip["texte"]
    voix = args.voix or voix_defaut
    rate = clip["rate"] if clip else "+0%"
    pitch = clip["pitch"] if clip else "+0%"
    style = clip["style"] if clip else ""
    octets, origine = obtenir_mp3(args.fournisseur, texte, voix, rate, pitch, style,
                                  calculer_empreinte(deck, voix, style, rate, pitch, texte))
    destination = DOSSIER_ECOUTES / ("%s.mp3" % args.probe)
    ecrire_atomique(destination, octets)
    print("[écoute] %s → %s (%s o, %s, voix %s)%s"
          % (args.probe, destination, formater_octets(len(octets)), args.fournisseur, voix,
             " [cache]" if origine == "cache" else ""))
    print("  Écoute : afplay %s" % destination)
    return 0


# --- Point d'entrée ---------------------------------------------------------
def construire_analyseur():
    analyseur = argparse.ArgumentParser(
        description="Génère les voix pré-enregistrées (MP3) et le manifest de l'application.")
    analyseur.add_argument("--scripts", default=str(RACINE_OUTILS / "scripts.json"),
                           help="export du contenu Dart (défaut : tools/audio/scripts.json)")
    analyseur.add_argument("--assets", default=str(RACINE_PROJET / "assets" / "audio"),
                           help="racine des assets audio (défaut : assets/audio)")
    analyseur.add_argument("--fournisseur", choices=sorted(FOURNISSEURS), default="dummy",
                           help="moteur de synthèse (défaut : dummy, hors ligne)")
    mode = analyseur.add_mutually_exclusive_group()
    mode.add_argument("--seulement-manquants", action="store_true",
                      help="ne génère que les clips manquants ou modifiés (défaut)")
    mode.add_argument("--tout", action="store_true",
                      help="régénère tout sauf les clips « enregistre »")
    analyseur.add_argument("--voix", help="force la voix (défaut : voix.principale de scripts.json)")
    analyseur.add_argument("--probe", metavar="ID",
                           help="écoute un clip dans tools/audio/ecoutes/, sans toucher aux assets")
    analyseur.add_argument("--texte", help="texte à utiliser avec --probe (clip hors scripts.json)")
    analyseur.add_argument("--forcer", metavar="ID", help="régénère même un clip « enregistre »")
    analyseur.add_argument("--rapport", action="store_true",
                           help="affiche les chiffres et le coût estimé, sans rien générer")
    analyseur.add_argument("--verifier", action="store_true",
                           help="compare manifest, fichiers et scripts.json (sortie non nulle si écart)")
    return analyseur


def main(argv=None):
    args = construire_analyseur().parse_args(argv)
    try:
        deck, voix_defaut, clips, scripts_bruts = charger_scripts(args.scripts)
        assets = Path(args.assets)
        voix_effective = args.voix or voix_defaut
        manifest_chemin = assets / deck / dossier_voix(voix_effective) / "manifest.json"
        manifest = charger_manifest(manifest_chemin, deck, scripts_bruts)

        if args.verifier:
            return commande_verifier(args, deck, voix_defaut, clips, manifest, manifest_chemin, assets)
        if args.rapport:
            return commande_rapport(args, deck, voix_defaut, clips, manifest, assets)
        if args.probe:
            return commande_probe(args, deck, voix_defaut, clips)
        return executer_generation(args, deck, voix_defaut, clips, manifest, manifest_chemin,
                                   assets, scripts_bruts)
    except ErreurAudio as erreur:
        print("ERREUR : %s" % erreur, file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
