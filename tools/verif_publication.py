#!/usr/bin/env python3
"""Contrôles locaux de l’identité et du dossier boutique, sans envoi réseau."""
import argparse
import json
import plistlib
import re
import struct
import sys
from pathlib import Path
from xml.etree import ElementTree

racine = Path(__file__).resolve().parents[1]
erreurs = []

def verifier(condition, message):
    if not condition:
        erreurs.append(message)

def png(chemin, cote):
    donnees = chemin.read_bytes()
    verifier(donnees[:8] == b'\x89PNG\r\n\x1a\n', f'PNG invalide : {chemin}')
    largeur, hauteur, _, couleur = struct.unpack('>IIBB', donnees[16:26])
    verifier((largeur, hauteur) == (cote, cote), f'Dimensions incorrectes : {chemin}')
    verifier(couleur == 2, f'RGB opaque attendu : {chemin}')

args = argparse.ArgumentParser(description=__doc__)
args.add_argument('--soumission', action='store_true', help='Exiger aussi les renseignements de soumission ; ne soumet rien.')
options = args.parse_args()
fiche = json.loads((racine / 'docs/publication/fiche-fr-CA.json').read_text())
for champ, limite in [('title', 30), ('subtitle', 30), ('promotional_text', 170), ('keywords', 100), ('description', 4000), ('short_description', 80)]:
    verifier(0 < len(fiche[champ]) <= limite, f'{champ} dépasse {limite} caractères')
verifier(fiche['name'] == 'Labo des Petits', 'Nom public incorrect')
verifier(fiche['release_mode'] in {'MANUAL', 'AFTER_APPROVAL'}, 'Mode de publication Apple invalide')
pubspec = (racine / 'pubspec.yaml').read_text()
verifier(f"version: {fiche['version']}+{fiche['build']}" in pubspec, 'Version boutique/pubspec différente')
identite = (racine / 'lib/core/identite.dart').read_text()
verifier(f"nom = '{fiche['name']}'" in identite, 'Nom dans l’application différent')
verifier(f"version = '{fiche['version']}'" in identite, 'Version de l’écran À propos différente')
info = plistlib.loads((racine / 'ios/Runner/Info.plist').read_bytes())
verifier(info['CFBundleDisplayName'] == fiche['name'], 'Nom iOS incorrect')
android = ElementTree.parse(racine / 'android/app/src/main/AndroidManifest.xml').getroot()
verifier(android.find('application').get('{http://schemas.android.com/apk/res/android}label') == fiche['name'], 'Nom Android incorrect')
app = (racine / 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
for image in json.loads((app / 'Contents.json').read_text())['images']:
    cote = round(float(image['size'].split('x')[0]) * float(image['scale'][:-1]))
    png(app / image['filename'], cote)
png(racine / 'assets/identite/ludiballon.png', 1024)
for densite, cote in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    png(racine / f'android/app/src/main/res/mipmap-{densite}/ic_launcher.png', cote)
confidentialite = (racine / 'assets/textes/confidentialite.txt').read_text()
verifier(fiche['support_email'] in confidentialite, 'Contact absent de la politique')
privacy = plistlib.loads((racine / 'ios/Runner/PrivacyInfo.xcprivacy').read_bytes())
verifier(privacy['NSPrivacyTracking'] is False and privacy['NSPrivacyCollectedDataTypes'] == [], 'Déclaration confidentialité incohérente')
verifier('PrivacyInfo.xcprivacy in Resources' in (racine / 'ios/Runner.xcodeproj/project.pbxproj').read_text(), 'Manifeste non intégré à la cible iOS')
contacts = racine / '_local/publication/contacts-apple.json'
if contacts.is_file():
    prive = json.loads(contacts.read_text())
    for champ in ['review_contact_name', 'review_contact_phone', 'review_contact_email', 'app_store_connect_id']:
        fiche[champ] = prive.get(champ)
champs_manquants = [c for c in ['support_url', 'privacy_url', 'review_contact_name', 'review_contact_phone', 'review_contact_email', 'app_store_connect_id'] if not fiche.get(c)]
if options.soumission:
    verifier(not champs_manquants, 'Renseignements de soumission manquants : ' + ', '.join(champs_manquants))
    verifier(fiche.get('urls_publicly_verified') is True, 'Pages publiques non vérifiées en ligne')
    for champ in ['support_url', 'privacy_url']:
        verifier(bool(re.match(r'^https://[^/]+/.+', fiche.get(champ) or '')), f'{champ} : URL HTTPS publique requise')
if erreurs:
    print('\n'.join('ERREUR : ' + e for e in erreurs))
    sys.exit(1)
print('Identité, icônes, versions, textes et confidentialité : conformes localement.')
if champs_manquants:
    print('Avant soumission : ' + ', '.join(champs_manquants))
if not fiche.get('urls_publicly_verified'):
    print('Avant soumission : vérifier les pages publiques en ligne.')
print('Ce contrôle ne procède à aucun envoi ; le mode de publication autorisé est décrit dans docs/PUBLICATION.md.')
