import 'package:flutter/material.dart';

import '../../theme/palette.dart';

/// Un repère visuel sans lecture, pour une action composée de plusieurs gestes.
class AvancementGeste extends StatelessWidget {
  final int faits;
  final int total;

  const AvancementGeste({super.key, required this.faits, required this.total});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Avancement',
      value: '$faits sur $total',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          minHeight: 8,
          value: total <= 0 ? 0 : (faits / total).clamp(0.0, 1.0),
          backgroundColor: Palette.cremeFonce,
          color: Palette.verdure,
        ),
      ),
    ),
  );
}
