import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/cible_tactile.dart';
import '../../core/widgets/image_concept.dart';
import '../../theme/palette.dart';
import '../shell/shell_controller.dart';

/// Création d'un profil : un prénom, un avatar, un âge. Vingt secondes.
class CreationProfilScreen extends StatefulWidget {
  /// Vrai quand c'est le tout premier profil (pas de bouton retour).
  final bool premier;

  const CreationProfilScreen({super.key, this.premier = false});

  @override
  State<CreationProfilScreen> createState() => _CreationProfilScreenState();
}

class _CreationProfilScreenState extends State<CreationProfilScreen> {
  static const _avatars = [
    'chat',
    'souris',
    'loup',
    'hibou',
    'mouton',
    'cochon',
    'lapin',
    'poisson',
  ];

  final _nom = TextEditingController();
  String _avatar = 'chat';
  int _age = 4;
  bool _enCours = false;

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    final nom = _nom.text.trim();
    if (nom.isEmpty || _enCours) return;
    setState(() => _enCours = true);
    await context.read<ShellController>().creerProfil(nom, _avatar, _age);
    // Le shell bascule tout seul sur l'accueil ou le choix de profil.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.premier
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              toolbarHeight: 88,
              leadingWidth: 88,
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
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Qui va jouer ?',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Palette.encre,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nom,
              style: const TextStyle(fontSize: 28, color: Palette.encre),
              decoration: const InputDecoration(
                labelText: 'Le prénom',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            const Text(
              'Son avatar',
              style: TextStyle(fontSize: 22, color: Palette.encreDouce),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final avatar in _avatars)
                  CibleTactile(
                    semantique: avatar,
                    onTap: () => setState(() => _avatar = avatar),
                    child: Container(
                      width: 88,
                      height: 88,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: avatar == _avatar
                              ? Palette.ciel
                              : Palette.cremeFonce,
                          width: 5,
                        ),
                      ),
                      child: ImageConcept(concept: avatar, taille: 56),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Son âge',
              style: TextStyle(fontSize: 22, color: Palette.encreDouce),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                for (final age in [4, 5, 6, 7])
                  CibleTactile(
                    semantique: '$age ans',
                    onTap: () => setState(() => _age = age),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: age == _age
                            ? Palette.soleil.withValues(alpha: 0.3)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: age == _age
                              ? Palette.soleil
                              : Palette.cremeFonce,
                          width: 4,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$age',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: Palette.encre,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 36),
            Center(
              child: CibleTactile(
                semantique: 'C\'est parti',
                onTap: _nom.text.trim().isEmpty ? null : _creer,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: _nom.text.trim().isEmpty
                        ? Palette.grisDoux
                        : Palette.verdure,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Text(
                    'C\'est parti !',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
