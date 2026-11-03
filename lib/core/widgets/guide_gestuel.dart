import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../contenu/modele/activite.dart';
import '../parent/fiches_activites.dart';
import '../../theme/palette.dart';
import 'bouton_action_enfant.dart';
import 'cible_tactile.dart';

/// Une démonstration indépendante des réponses : elle ne joue jamais à la
/// place de l'enfant et ne modifie ni sa manche ni sa progression.
class GuideGestuel extends StatefulWidget {
  final Activite activite;
  final VoidCallback onCommencer;
  const GuideGestuel({
    super.key,
    required this.activite,
    required this.onCommencer,
  });

  @override
  State<GuideGestuel> createState() => _GuideGestuelState();
}

class _GuideGestuelState extends State<GuideGestuel>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..forward();

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, _) => SizedBox(
                width: 280,
                height: 160,
                child: CustomPaint(
                  key: const ValueKey('guide.animation'),
                  painter: _GestePeint(
                    gestePour(widget.activite),
                    _animation.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              fichesActivites[widget.activite.id]!.commentJouer,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Palette.encreDouce),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: [
                CibleTactile(
                  key: const ValueKey('guide.revoir'),
                  onTap: () => _animation.forward(from: 0),
                  semantique: 'Revoir le geste',
                  child: const Icon(
                    Icons.replay_rounded,
                    size: 40,
                    color: Palette.ciel,
                  ),
                ),
                BoutonActionEnfant(
                  key: const ValueKey('guide.commencer'),
                  icone: Icons.play_arrow_rounded,
                  libelle: 'Jouer',
                  couleur: Palette.verdure,
                  onTap: widget.onCommencer,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _GestePeint extends CustomPainter {
  final GesteGuide geste;
  final double progression;
  _GestePeint(this.geste, this.progression);

  @override
  void paint(Canvas canvas, Size size) {
    if (geste == GesteGuide.programmer ||
        geste == GesteGuide.ordonner ||
        geste == GesteGuide.composer) {
      _sequence(canvas, size);
      return;
    }
    final depart = Offset(size.width * .22, size.height * .45);
    final arrivee = Offset(size.width * .76, size.height * .45);
    final fond = Paint()..color = Colors.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      fond,
    );
    final bord = Paint()
      ..color = Palette.cremeFonce
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(depart, 27, bord);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: arrivee, width: 62, height: 62),
        const Radius.circular(14),
      ),
      bord,
    );
    final deplacement = switch (geste) {
      GesteGuide.toucher ||
      GesteGuide.scene ||
      GesteGuide.rythme ||
      GesteGuide.assembler => false,
      _ => true,
    };
    final t = Curves.easeInOut.transform(progression.clamp(0.0, 1.0));
    final point = deplacement ? Offset.lerp(depart, arrivee, t)! : depart;
    if (geste == GesteGuide.tracer || geste == GesteGuide.peindre) {
      canvas.drawLine(
        depart,
        arrivee,
        Paint()
          ..color = Palette.ciel.withValues(alpha: .25)
          ..strokeWidth = 24
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        depart,
        point,
        Paint()
          ..color = Palette.ciel
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );
    } else if (deplacement) {
      // Deux touchers : on sélectionne, puis on pose. L'objet ne doit pas
      // faire croire que le glisser est obligatoire.
      canvas.drawCircle(
        progression < .75 ? depart : arrivee,
        18,
        Paint()..color = Palette.soleil,
      );
      if (progression >= .75) {
        canvas.drawCircle(
          arrivee,
          32,
          Paint()..color = Palette.verdure.withValues(alpha: .2),
        );
      }
    } else {
      final rayon = 20 + 14 * math.sin(progression * math.pi * 4).abs();
      canvas.drawCircle(
        depart,
        rayon,
        Paint()..color = Palette.verdure.withValues(alpha: .25),
      );
    }
    final doigt = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.touch_app_rounded.codePoint),
        style: TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: 44,
          color: Palette.encre,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    doigt.paint(canvas, point + const Offset(-10, 8));
  }

  void _sequence(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      Paint()..color = Colors.white,
    );
    final etape = math.min(2, (progression * 3).floor());
    final depart = Offset(size.width * .2, size.height * .8);
    var destination = depart;
    for (var i = 0; i < 3; i++) {
      final centre = Offset(size.width * (.22 + i * .28), size.height * .35);
      if (i == etape) destination = centre;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: 52, height: 52),
          const Radius.circular(12),
        ),
        Paint()
          ..color = i < etape
              ? Palette.verdure.withValues(alpha: .3)
              : Palette.cremeFonce,
      );
      if (i <= etape) {
        final icone = geste == GesteGuide.composer
            ? Icons.music_note_rounded
            : (geste == GesteGuide.programmer
                  ? Icons.arrow_forward_rounded
                  : Icons.circle);
        final symbole = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(icone.codePoint),
            style: const TextStyle(
              fontFamily: 'MaterialIcons',
              fontSize: 28,
              color: Palette.ciel,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        symbole.paint(canvas, centre - const Offset(14, 14));
      }
    }
    final fraction = (progression * 3 - etape).clamp(0.0, 1.0);
    final point = Offset.lerp(
      depart,
      destination,
      Curves.easeInOut.transform(fraction),
    )!;
    final main = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.touch_app_rounded.codePoint),
        style: const TextStyle(
          fontFamily: 'MaterialIcons',
          fontSize: 44,
          color: Palette.encre,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    main.paint(canvas, point - const Offset(8, 0));
  }

  @override
  bool shouldRepaint(covariant _GestePeint oldDelegate) =>
      oldDelegate.progression != progression || oldDelegate.geste != geste;
}
