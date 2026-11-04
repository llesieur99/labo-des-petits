import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/manifeste_audio.dart';
import '../../core/audio/say_kit.dart';
import '../../core/audio/session_audio.dart';
import '../../core/micro/mic_kit.dart';
import '../../core/contenu/catalogue.dart';
import '../../core/parent/reglages.dart';
import '../../core/progression/depot.dart';
import '../../core/progression/modele.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../theme/palette.dart';
import '../shell/shell_controller.dart';
import 'guide_parent_screen.dart';
import 'informations_app_screen.dart';
import 'retour_parent_screen.dart';

/// L'espace des parents : le peu qu'il faut, sans tableau de bord de
/// surveillance. Chaque enfant, son temps, sa progression, et les textes.
class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  /// Vrai quand la permission du téléphone a été refusée à l'instant.
  bool _microRefuse = false;

  Future<void> _changerVoix(String voix) async {
    final reglages = context.read<Reglages>();
    final say = context.read<SayKit>();
    await reglages.setVoix(voix);
    await say.changerVoix(voix);
    if (mounted) setState(() {});
    // Une petite démonstration immédiate : le parent entend la nouvelle voix.
    await say.dire('consigne.ecoute');
  }

  Future<void> _autoriserMicro() async {
    final micro = context.read<Micro>();
    final reglages = context.read<Reglages>();
    final accorde = await micro.demander();
    if (accorde) await reglages.setMicroAutorise(true);
    if (!mounted) return;
    setState(() => _microRefuse = !accorde);
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final reglages = context.read<Reglages>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 88,
        leadingWidth: 88,
        title: const Text(
          'Espace des parents',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Palette.encre,
          ),
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_rounded),
              title: const Text('Accompagner les 48 jeux'),
              subtitle: const Text(
                'Objectifs, gestes et aides pour chaque activité',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const GuideParentScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('Labo des Petits : confidentialité et soutien'),
              subtitle: const Text(
                'Informations, contact et crédits hors ligne',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const InformationsAppScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              key: const ValueKey('parent.retours'),
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('Recommandations et commentaires'),
              subtitle: const Text(
                'Écrire à support@le-sieur.ca depuis votre courriel',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const RetourParentScreen(),
                ),
              ),
            ),
          ),
          for (final profil in shell.profils)
            _SectionEnfant(
              profil: profil,
              reglages: reglages,
              onChangement: () => setState(() {}),
            ),
          const SizedBox(height: 8),
          _Section(
            titre: 'Le son et la voix',
            enfants: [
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'La voix : ',
                    style: TextStyle(fontSize: 18, color: Palette.encre),
                  ),
                  for (final (id, nom) in [
                    (VoixDisponibles.antoine, 'Antoine (homme)'),
                    (VoixDisponibles.sylvie, 'Sylvie (femme)'),
                  ])
                    ChoiceChip(
                      label: Text(nom),
                      selected: reglages.voix == id,
                      onSelected: (_) => _changerVoix(id),
                    ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  'Le changement s\'applique tout de suite — la voix de '
                  'démonstration se fait entendre.',
                  style: TextStyle(fontSize: 15, color: Palette.encreDouce),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Respecter le mode silencieux du téléphone',
                  style: TextStyle(fontSize: 18, color: Palette.encre),
                ),
                subtitle: const Text(
                  'Par défaut, l\'app parle même si le petit interrupteur '
                  'est activé — un enfant ne peut pas le comprendre.',
                  style: TextStyle(color: Palette.encreDouce),
                ),
                value: reglages.respecterSilencieux,
                onChanged: (valeur) async {
                  await reglages.setRespecterSilencieux(valeur);
                  await SessionAudio.configurer(respecterSilencieux: valeur);
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
          _Section(
            titre: 'Le micro',
            enfants: [
              const Text(
                'Le microphone est facultatif. Certains jeux permettent de '
                's’enregistrer pour se réécouter (« La bouche à sons »). '
                'L’enregistrement reste sur l’appareil puis est effacé. '
                'Aucune reconnaissance vocale ni transmission. Tous les jeux '
                'restent utilisables sans micro. En continuant, vous accédez '
                'à la demande de permission du système.',
                style: TextStyle(fontSize: 15, color: Palette.encreDouce),
              ),
              const SizedBox(height: 10),
              if (!reglages.microAutorise)
                CibleTactile(
                  semantique: 'Continuer',
                  onTap: _autoriserMicro,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Palette.ciel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Continuer',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Le micro est autorisé',
                    style: TextStyle(fontSize: 18, color: Palette.encre),
                  ),
                  value: true,
                  onChanged: (valeur) async {
                    await reglages.setMicroAutorise(valeur);
                    if (mounted) setState(() {});
                  },
                ),
              if (_microRefuse)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'L’accès au microphone n’est pas accordé. Vous pouvez '
                    'continuer à jouer sans micro. Ce choix peut être modifié '
                    'dans les réglages de confidentialité du téléphone.',
                    style: TextStyle(fontSize: 15, color: Color(0xFFB3543C)),
                  ),
                ),
            ],
          ),
          const _Section(
            titre: 'Confidentialité',
            enfants: [
              Text(
                'Cette app ne collecte aucune donnée de jeu. Aucun compte, '
                'aucune publicité ni mesure d\'usage ; les jeux fonctionnent '
                'sans internet. Profils, progression et voix restent sur cet '
                'appareil. Le parent peut choisir d\'ouvrir un brouillon de '
                'courriel pour nous écrire ; aucune donnée de profil n\'y est ajoutée.',
                style: TextStyle(fontSize: 16, color: Palette.encreDouce),
              ),
            ],
          ),
          const _Section(
            titre: 'Crédits',
            enfants: [
              Text(
                'Illustrations : Twemoji (CC-BY 4.0). Police : Andika '
                '(SIL OFL 1.1). Les chansons sont du domaine public. '
                'Détail dans Labo des Petits : confidentialité et soutien, ci-dessus.',
                style: TextStyle(fontSize: 16, color: Palette.encreDouce),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionEnfant extends StatelessWidget {
  final Profil profil;
  final Reglages reglages;
  final VoidCallback onChangement;

  const _SectionEnfant({
    required this.profil,
    required this.reglages,
    required this.onChangement,
  });

  @override
  Widget build(BuildContext context) {
    final depot = context.read<DepotProgression>();
    final limite = reglages.limiteMinutes(profil.id!);
    final minutes = reglages.minutesAujourdhui(profil.id!);

    return _Section(
      titre:
          '${profil.nom}${profil.ageDeclare == null ? '' : ' · ${profil.ageDeclare} ans'}',
      enfants: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text(
              'Temps de jeu par jour : ',
              style: TextStyle(fontSize: 18, color: Palette.encre),
            ),
            for (final choix in [0, 15, 30, 45])
              ChoiceChip(
                label: Text(choix == 0 ? 'illimité' : '$choix min'),
                selected: limite == choix,
                onSelected: (_) async {
                  await reglages.setLimiteMinutes(profil.id!, choix);
                  onChangement();
                },
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Joué aujourd\'hui : $minutes min',
                style: const TextStyle(fontSize: 16, color: Palette.encreDouce),
              ),
              TextButton(
                onPressed: () async {
                  await reglages.remettreTempsAZero(profil.id!);
                  onChangement();
                },
                child: const Text('Remettre le temps à zéro'),
              ),
            ],
          ),
        ),
        FutureBuilder<List<EtatActivite>>(
          future: depot.etats(profil.id!),
          builder: (context, instantane) {
            final etats = instantane.data ?? const <EtatActivite>[];
            if (etats.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Aucune partie jouée pour le moment.',
                  style: TextStyle(fontSize: 16, color: Palette.encreDouce),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final etat in etats)
                    Chip(
                      label: Text(
                        '${_titre(etat.activiteId)} · '
                        '${_etoiles(etat.meilleureEtoile)} '
                        '· étape ${etat.niveau}/3 (${etat.partiesJouees} parties)',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => _confirmerRemiseAZero(context, depot),
                child: const Text(
                  'Recommencer sa progression',
                  style: TextStyle(color: Color(0xFFB3543C)),
                ),
              ),
              TextButton(
                onPressed: () => _confirmerSuppression(context, depot),
                child: const Text(
                  'Supprimer ce profil',
                  style: TextStyle(color: Color(0xFFB3543C)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _titre(String activiteId) =>
      activiteParId(activiteId)?.clips
          .firstWhere((c) => c.id == activiteParId(activiteId)!.titreCle)
          .texte ??
      activiteId;

  String _etoiles(int nombre) => '★' * nombre + '☆' * (3 - nombre);

  Future<void> _confirmerRemiseAZero(
    BuildContext context,
    DepotProgression depot,
  ) async {
    final ok = await _confirmer(
      context,
      'Recommencer ${profil.nom} ?',
      'Toute sa progression et ses collants seront remis à zéro.',
    );
    if (ok != true) return;
    await depot.remettreAZero(profil.id!);
    await reglages.remettreTempsAZero(profil.id!);
    onChangement();
  }

  Future<void> _confirmerSuppression(
    BuildContext context,
    DepotProgression depot,
  ) async {
    final ok = await _confirmer(
      context,
      'Supprimer ${profil.nom} ?',
      'Tout sera effacé. Cette action ne peut pas être annulée.',
    );
    if (ok != true) return;
    await depot.supprimerProfil(profil.id!);
    if (context.mounted) {
      await context.read<ShellController>().rafraichirProfils();
    }
  }

  Future<bool?> _confirmer(BuildContext context, String titre, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titre),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final List<Widget> enfants;

  const _Section({required this.titre, required this.enfants});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titre,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Palette.encre,
              ),
            ),
            const SizedBox(height: 12),
            ...enfants,
          ],
        ),
      ),
    );
  }
}
