import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/identite.dart';
import '../../core/parent/courriel_retour.dart';
import '../../core/widgets/cible_tactile.dart';
import '../../theme/palette.dart';

typedef OuvrirCourriel = Future<bool> Function(String sujet, String message);

enum TypeRetour {
  recommandation('Recommandation', Icons.lightbulb_outline_rounded),
  commentaire('Commentaire', Icons.chat_bubble_outline_rounded),
  probleme('Problème', Icons.bug_report_outlined);

  final String libelle;
  final IconData icone;

  const TypeRetour(this.libelle, this.icone);
}

/// Formulaire réservé à l'adulte, déjà entré par le portail parental.
class RetourParentScreen extends StatefulWidget {
  final OuvrirCourriel ouvrirCourriel;

  const RetourParentScreen({
    super.key,
    this.ouvrirCourriel = CourrielRetour.ouvrir,
  });

  @override
  State<RetourParentScreen> createState() => _RetourParentScreenState();
}

class _RetourParentScreenState extends State<RetourParentScreen> {
  final _message = TextEditingController();
  TypeRetour _type = TypeRetour.recommandation;
  bool _ouvertureEnCours = false;

  String get _sujet => '${Identite.nom} — ${_type.libelle}';
  String get _texte => _message.text.trim();

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _ouvrir() async {
    final texte = _texte;
    if (texte.isEmpty || _ouvertureEnCours) return;
    setState(() => _ouvertureEnCours = true);
    final ouvert = await widget.ouvrirCourriel(_sujet, texte);
    if (!mounted) return;
    setState(() => _ouvertureEnCours = false);
    if (!ouvert) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucune application de courriel disponible. Copiez le message et envoyez-le depuis votre courriel.',
          ),
        ),
      );
    }
  }

  Future<void> _copier() async {
    if (_texte.isEmpty) return;
    await Clipboard.setData(
      ClipboardData(
        text: 'À : ${Identite.soutien}\nObjet : $_sujet\n\n$_texte',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message et adresse copiés.')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88,
      leadingWidth: 88,
      title: const Text('Vos idées pour les jeux'),
      leading: CibleTactile(
        semantique: 'Retour à l’espace parent',
        onTap: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_rounded, size: 40),
      ),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Une idée, un commentaire ou un problème à signaler ?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Palette.encre,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Votre message sera préparé pour ${Identite.soutien}. Vous le vérifierez et l’enverrez vous-même depuis votre application de courriel.',
            style: const TextStyle(fontSize: 17, color: Palette.encreDouce),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              for (final type in TypeRetour.values)
                ChoiceChip(
                  key: ValueKey('retour.type.${type.name}'),
                  avatar: Icon(type.icone, size: 20),
                  label: Text(type.libelle),
                  selected: _type == type,
                  onSelected: (_) => setState(() => _type = type),
                ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('retour.message'),
            controller: _message,
            minLines: 5,
            maxLines: 8,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Votre message',
              hintText: 'Décrivez votre idée ou ce qui s’est passé…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const Text(
            'N’incluez pas de nom complet d’enfant, de photo ni d’enregistrement vocal. Aucun profil ou détail de l’appareil n’est ajouté au message.',
            style: TextStyle(fontSize: 15, color: Palette.encreDouce),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('retour.ouvrirCourriel'),
            onPressed: _texte.isEmpty || _ouvertureEnCours ? null : _ouvrir,
            icon: const Icon(Icons.mail_outline_rounded),
            label: const Text('Ouvrir le courriel'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('retour.copier'),
            onPressed: _texte.isEmpty ? null : _copier,
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copier le message'),
          ),
          const SizedBox(height: 12),
          const Text(
            'L’ouverture du courriel ne confirme pas son envoi. Appuyez sur Envoyer dans votre application de courriel pour nous le transmettre.',
            style: TextStyle(fontSize: 14, color: Palette.encreDouce),
          ),
        ],
      ),
    ),
  );
}
