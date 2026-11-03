/// Clips du « chrome » de l'app : retours, encouragements, encadrements.
/// Communs à tous les jeux, définis ici avec leur texte source pour que
/// l'export audio les génère comme les autres.
class ClipChrome {
  final String id;

  /// Le texte à dire — c'est la source de vérité pour la génération audio.
  final String texte;

  final String categorie;

  /// Ajustements SSML optionnels.
  final String? rate;
  final String? pitch;

  const ClipChrome(
    this.id,
    this.texte, {
    this.categorie = 'retour',
    this.rate,
    this.pitch,
  });
}

/// Tous les clips que l'app peut dire en dehors du contenu des activités.
const clipsChrome = <ClipChrome>[
  // ── Réussites (variées pour ne pas lasser) ──
  ClipChrome('retour.bravo.1', 'Bravo !', rate: '+5%'),
  ClipChrome('retour.bravo.2', 'Super !', rate: '+5%'),
  ClipChrome('retour.bravo.3', 'Oui, c\'est ça !', rate: '+5%'),
  ClipChrome('retour.bravo.4', 'Excellent !', rate: '+5%'),
  ClipChrome('retour.bravo.5', 'Wow, bien joué !', rate: '+5%'),

  // ── Encore une chance (jamais de « non », jamais de reproche) ──
  ClipChrome('retour.encore.1', 'Presque ! On écoute encore.', rate: '-5%'),
  ClipChrome('retour.encore.2', 'Hmm, essaie encore.', rate: '-5%'),
  ClipChrome('retour.encore.3', 'Pas tout à fait. Je te le redis.', rate: '-5%'),

  // ── Fin de partie ──
  ClipChrome('retour.fin.1', 'On a bien joué ! À tantôt !', rate: '-5%'),
  ClipChrome('retour.fin.2', 'C\'était super. À la prochaine !', rate: '-5%'),

  // ── Tracés (moteur M3 : lettres, sentiers, découpage) ──
  ClipChrome('trace.bravo', 'Bravo ! Tu as suivi tout le chemin !', rate: '+5%'),

  // ── Consignes génériques ──
  ClipChrome('consigne.repete', 'Je te le redis.', categorie: 'consigne', rate: '-5%'),
  ClipChrome('consigne.touche', 'Touche la bonne image.', categorie: 'consigne'),
  ClipChrome('consigne.ecoute', 'Écoute bien…', categorie: 'consigne', rate: '-5%'),
];
