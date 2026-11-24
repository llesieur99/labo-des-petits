# État documentaire et reprise — 24 novembre 2026

Cette note confronte les anciennes cases ouvertes aux sources GitHub actuelles. Elle conserve les états historiques et distingue les preuves acquises, les restes précis et les décisions conditionnelles. Aucun service, compte fournisseur, paiement ou envoi de message n’a été exécuté pour ce classement.

## Distribution et périmètre

Le contrôle de distribution du 24 novembre 2026 donne la version iOS 1.3.0 en `READY_FOR_SALE`. Ce statut ne demande aucune nouvelle soumission. Le dépôt actif reste celui-ci; les anciennes pistes exploratoires ne prouvent pas des défauts dans la version actuelle.

## Valider la réception du canal de retours parents

**Rattaché au suivi existant**. Le brouillon de courriel parent est livré; la réception réelle n’est pas prouvée. Inclure ce point dans la recette des retours parents/enfants déjà existante, sans envoyer de message.

- [Source : README.md, ligne 12](https://github.com/llesieur99/labo-des-petits/blob/c0705b8ab172134c2470951497909a01686d461c/README.md#L12).

## Préparer le compte et la piste de test fermée Google Play

**Condition préalable, sans nouveau chantier**. Un paquet Android signé ne prouve pas une piste Google Play. Le dépôt actif explique la préparation AAB, sans preuve de compte/piste. Conserver comme choix de distribution; revalider les exigences lors d’une demande Google Play.

Condition de reprise : Une distribution Google Play est retenue; accès titulaire et exigences courantes alors vérifiés.

- [Source : docs/PUBLICATION.md, ligne 34](https://github.com/llesieur99/labo-des-petits/blob/c0705b8ab172134c2470951497909a01686d461c/docs/PUBLICATION.md#L34).

## Revoir l’état de la refonte exploratoire des 48 jeux avant de reprendre les améliorations non livrées

**Condition préalable, sans nouveau chantier**. La note exploratoire historique ne définit pas un correctif actuel. Le dépôt public actuel contient les 48 activités et les tests; aucune preuve de livraison de tous les essais exploratoires ne peut en être déduite. Avant une reprise, comparer seulement les changements exploratoires conservés au dépôt actif et retenir les défauts encore reproductibles.

Condition de reprise : Reprise explicite des améliorations de jeux; ne pas créer une refonte globale à partir de la note historique.

- [Source : README.md, ligne 3](https://github.com/llesieur99/labo-des-petits/blob/c0705b8ab172134c2470951497909a01686d461c/README.md#L3).
- [Source : AGENTS.md, ligne 9](https://github.com/llesieur99/labo-des-petits/blob/c0705b8ab172134c2470951497909a01686d461c/AGENTS.md#L9).

## Vérification et limites

Lecture des sources sur les commits indiqués, contrôle des liens du lot, conservation des textes antérieurs, revue du diff et scan de secrets avant publication GitHub. Aucun état de service ou résultat sur appareil n’est déduit de la présence du code.

`tools/verif.sh` exécuté dans une nouvelle copie isolée : cinq étapes réussies (analyse, tests, export de contenu, cohérence audio, taille des ressources). Aucun build signé ni nouvel envoi vers une boutique dans ce lot.
