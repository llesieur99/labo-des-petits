import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/identite.dart';
import '../../core/widgets/cible_tactile.dart';

/// Informations pour l'adulte, disponibles sans connexion.
class InformationsAppScreen extends StatefulWidget {
  const InformationsAppScreen({super.key});

  @override
  State<InformationsAppScreen> createState() => _InformationsAppScreenState();
}

class _InformationsAppScreenState extends State<InformationsAppScreen> {
  late final _politique = rootBundle.loadString(
    'assets/textes/confidentialite.txt',
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 88,
      leadingWidth: 88,
      leading: CibleTactile(
        semantique: 'Retour',
        onTap: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back_rounded, size: 40),
      ),
      title: const Text('À propos de Labo des Petits'),
    ),
    body: SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(Identite.icone, width: 104, height: 104),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '${Identite.nom} ${Identite.version}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          FutureBuilder<String>(
            future: _politique,
            builder: (context, resultat) => SelectableText(
              resultat.data ?? 'Chargement de la politique de confidentialité…',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Crédits',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const SelectableText(
            'Illustrations : Twemoji, © Twitter, Inc. et contributeurs. Licence Creative Commons Attribution 4.0. Source : github.com/jdecked/twemoji.\n\nPolice : Andika, © SIL International. Licence SIL Open Font License 1.1. Source : software.sil.org/andika/.\n\nIcône Labo des Petits : création pour ce projet avec l’outil de génération d’images OpenAI, inspirée de l’illustration maison de La chasse aux rimes.\n\nLes mélodies traditionnelles sont adaptées pour l’application.',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: Identite.nom,
              applicationVersion: Identite.version,
            ),
            child: const Text('Licences des composants'),
          ),
        ],
      ),
    ),
  );
}
