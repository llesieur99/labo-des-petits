import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/say_kit.dart';
import '../../core/contenu/catalogue.dart';
import '../../core/contenu/modele/activite.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../core/widgets/collant.dart';
import '../../core/progression/collants.dart';
import '../../core/progression/depot.dart';
import '../../core/progression/modele.dart';
import '../../core/widgets/grille_cartes.dart';
import '../../core/widgets/image_concept.dart';
import '../../theme/palette.dart';
import '../../theme/libelles.dart';
import '../../theme/theme_enfant.dart';
import '../jeu/jeu_screen.dart';
import '../shell/shell_controller.dart';

/// Les jeux d'une famille, en grandes cartes. Un tap = ça démarre ;
/// le bouton « oreille » dit le titre sans lancer.
class FamilleScreen extends StatefulWidget {
  final Famille famille;

  const FamilleScreen({super.key, required this.famille});

  @override
  State<FamilleScreen> createState() => _FamilleScreenState();
}

class _FamilleScreenState extends State<FamilleScreen> {
  int? _profilId;
  Future<List<EtatActivite>>? _progression;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profilId = context.watch<ShellController>().profilActif?.id;
    if (_profilId != profilId) {
      _profilId = profilId;
      _progression = profilId == null
          ? null
          : context.read<DepotProgression>().etats(profilId);
    }
  }

  void _rafraichir() {
    if (!mounted || _profilId == null) return;
    final progression = context.read<DepotProgression>().etats(_profilId!);
    setState(() {
      _progression = progression;
    });
  }

  @override
  Widget build(BuildContext context) {
    final jeux = activitesDe(widget.famille);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 88,
        leadingWidth: 88,
        title: Text(
          libelleFamille(widget.famille),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: CibleTactile(
          onTap: () => Navigator.of(context).pop(),
          semantique: 'Retour',
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 44,
            color: Palette.encreDouce,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<EtatActivite>>(
          key: ValueKey(_profilId),
          future: _progression,
          builder: (context, instantane) {
            final etats = {
              for (final etat in instantane.data ?? <EtatActivite>[])
                etat.activiteId: etat,
            };
            return GrilleCartes(
              enfants: [
                for (final jeu in jeux)
                  _CarteJeu(
                    jeu: jeu,
                    etat: etats[jeu.id],
                    progressionChargee: instantane.hasData,
                    onRetour: _rafraichir,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CarteJeu extends StatelessWidget {
  final Activite jeu;
  final EtatActivite? etat;
  final bool progressionChargee;
  final VoidCallback onRetour;
  const _CarteJeu({
    required this.jeu,
    required this.etat,
    required this.progressionChargee,
    required this.onRetour,
  });

  @override
  Widget build(BuildContext context) {
    final profil = context.watch<ShellController>().profilActif;
    final titre = jeu.clips.firstWhere((c) => c.id == jeu.titreCle).texte;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Palette.cremeFonce, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CibleTactile(
            key: ValueKey('jeu.ouvrir.${jeu.id}'),
            semantique: 'Jouer à $titre',
            onTap: profil == null
                ? null
                : () async {
                    context.read<SayKit>().stopper();
                    await Navigator.of(context).push(
                      routeDouce(JeuScreen(activite: jeu, profil: profil)),
                    );
                    onRetour();
                  },
            child: LayoutBuilder(
              builder: (context, place) {
                final empiler =
                    place.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(22) > 30;
                final image = ImageConcept(
                  concept: jeu.id,
                  fichier: jeu.illustration,
                  taille: 88,
                );
                final titreEcrit = Text(
                  titre,
                  textAlign: empiler ? TextAlign.center : TextAlign.start,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Palette.encre,
                  ),
                );
                const jouer = Icon(
                  Icons.play_circle_fill_rounded,
                  size: 36,
                  color: Palette.verdure,
                );
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: empiler
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                image,
                                const SizedBox(width: 24),
                                jouer,
                              ],
                            ),
                            const SizedBox(height: 16),
                            titreEcrit,
                          ],
                        )
                      : Row(
                          children: [
                            image,
                            const SizedBox(width: 16),
                            Expanded(child: titreEcrit),
                            const SizedBox(width: 8),
                            jouer,
                          ],
                        ),
                );
              },
            ),
          ),
          if (progressionChargee)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _PetitsCollants(activiteId: jeu.id, etat: etat),
            ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          // L'écoute et le lancement ont des zones distinctes, sans
          // superposition de gestes : l'image ouvre toujours le jeu.
          CibleTactile(
            key: ValueKey('jeu.ecouter.${jeu.id}'),
            semantique: 'Écouter le titre de $titre',
            onTap: () => context.read<SayKit>().dire(jeu.titreCle),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volume_up_rounded, size: 32, color: Palette.ciel),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Écouter le titre',
                      style: TextStyle(fontSize: 18, color: Palette.encreDouce),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetitsCollants extends StatelessWidget {
  final String activiteId;
  final EtatActivite? etat;
  const _PetitsCollants({required this.activiteId, required this.etat});

  @override
  Widget build(BuildContext context) {
    final obtenus = TypeCollant.values.where((t) => t.gagne(etat)).length;
    return Semantics(
      label:
          '$obtenus collants sur 4${obtenus == 0
              ? ', aucune partie terminée'
              : obtenus == 4
              ? ', tous les collants obtenus'
              : ''}',
      child: Wrap(
        key: ValueKey('jeu.collants.$activiteId'),
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final type in TypeCollant.values)
            Collant(type: type, gagne: type.gagne(etat), taille: 36),
          ExcludeSemantics(
            child: Text(
              '$obtenus/4',
              style: const TextStyle(fontSize: 16, color: Palette.encreDouce),
            ),
          ),
        ],
      ),
    );
  }
}
