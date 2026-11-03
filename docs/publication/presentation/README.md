# Présentation App Store — Labo des Petits 1.3.0 (10)

Quatre visuels pour iPhone (1320 × 2868) et quatre pour iPad (2064 × 2752),
JPEG opaque de qualité 95. Exports dans exports/. Les véritables écrans
Flutter sont dans captures/, avec un profil et une progression fictifs.
L’interface n’est pas redessinée. Aucun téléphone physique n’est revendiqué.

1. 48 jeux pour les petits curieux : accueil et sept familles.
2. Écouter. Toucher. Jouer : une vraie manche de La chasse aux rimes.
3. Grandir, un niveau à la fois : catalogue, progression et huit niveaux par âge.
4. Des petits succès. De beaux collants : récompenses obtenues et à gagner.

Générer les écrans avec CAPTURES_STORE=1 flutter test
test/navigation/ecrans_adaptatifs_test.dart (22 cas au 26 octobre).
Servir la racine du dépôt en HTTP local, puis ouvrir index.html?page=0&format=iphone
ou format=ipad. Largeur 1320 ou 2064 ; exporter la page complète, sans
barre de navigateur. Les quatre pages utilisent la police Andika embarquée.
Conversions JPEG avec sips, sans retouche de l’interface. Les captures source
et les exports sont figés pour la version ; régénérer lors d’un changement.

Les textes décrivent les fonctionnalités présentes, sans promesse de résultat
pédagogique, avis inventé ni date de lancement. Sources Twemoji et Andika :
voir les crédits de l’app. Les coordonnées Apple restent privées.
