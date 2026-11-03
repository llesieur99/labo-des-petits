import 'dart:math';

import 'package:flutter/material.dart';

import '../widgets/cible_tactile.dart';

/// Le portail vers l'espace parent : il faut maintenir le bouton 3 secondes,
/// PUIS répondre à un calcul à deux chiffres.
///
/// Aucun mot de passe n'est stocké : le calcul est tiré au hasard à chaque
/// fois. Un enfant de 7 ans ne maintient pas 3 secondes et ne calcule pas
/// 27 + 15 de tête — un parent, oui.
class PortailParent extends StatefulWidget {
  final VoidCallback onReussi;

  /// Quitter sans entrer (l'enfant revient à son écran).
  final VoidCallback onAnnuler;

  const PortailParent({super.key, required this.onReussi, required this.onAnnuler});

  @override
  State<PortailParent> createState() => _PortailParentState();
}

class _PortailParentState extends State<PortailParent> {
  final _alea = Random();
  late int _a;
  late int _b;
  final _controleur = TextEditingController();
  bool _maintienFini = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _nouveauCalcul();
  }

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  void _nouveauCalcul() {
    // Deux nombres à deux chiffres : hors de portée d'un enfant de maternelle.
    _a = 11 + _alea.nextInt(39);
    _b = 11 + _alea.nextInt(19);
    _controleur.clear();
  }

  void _verifier() {
    final reponse = int.tryParse(_controleur.text.trim());
    if (reponse == _a + _b) {
      widget.onReussi();
      return;
    }
    setState(() {
      _erreur = 'Ce n\'est pas la bonne réponse. On recommence.';
      _maintienFini = false;
      _nouveauCalcul();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text('Espace des parents',
                      style: theme.textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    iconSize: 40,
                    tooltip: 'Retour',
                    onPressed: widget.onAnnuler,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!_maintienFini) ...[
                Text(
                  'Pour ouvrir l\'espace des parents, maintiens ce bouton '
                  'trois secondes.',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Center(
                  child: MaintienTroisSecondes(
                    onTermine: () => setState(() => _maintienFini = true),
                  ),
                ),
              ] else ...[
                Text('Quelle est la réponse ?',
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 8),
                Text('$_a + $_b = ?',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controleur,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        style: theme.textTheme.headlineSmall,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'Réponse',
                        ),
                        onSubmitted: (_) => _verifier(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CibleTactile(
                      onTap: _verifier,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(Icons.check_rounded,
                            size: 36, color: theme.colorScheme.primary),
                      ),
                    ),
                  ],
                ),
                if (_erreur != null) ...[
                  const SizedBox(height: 12),
                  Text(_erreur!, style: theme.textTheme.bodyMedium),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton à maintenir trois secondes (avec l'anneau qui se remplit).
class MaintienTroisSecondes extends StatefulWidget {
  final VoidCallback onTermine;

  const MaintienTroisSecondes({super.key, required this.onTermine});

  @override
  State<MaintienTroisSecondes> createState() => _MaintienTroisSecondesState();
}

class _MaintienTroisSecondesState extends State<MaintienTroisSecondes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controleur = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void dispose() {
    _controleur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) => _controleur.forward(),
      onTapUp: (_) => _controleur.reset(),
      onTapCancel: () => _controleur.reset(),
      child: AnimatedBuilder(
        animation: _controleur,
        builder: (context, _) {
          if (_controleur.isCompleted) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => widget.onTermine());
          }
          return Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primaryContainer,
              border: Border.all(color: theme.colorScheme.primary, width: 4),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: _controleur.value,
                    strokeWidth: 6,
                    color: theme.colorScheme.primary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                Icon(Icons.lock_open_rounded,
                    size: 40, color: theme.colorScheme.primary),
              ],
            ),
          );
        },
      ),
    );
  }
}
