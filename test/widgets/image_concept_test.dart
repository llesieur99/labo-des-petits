import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeux_enfants/core/widgets/image_concept.dart';

class ImagesControlees extends CachingAssetBundle {
  final demandes = <String, Completer<ByteData>>{};

  @override
  Future<ByteData> load(String key) =>
      (demandes[key] ??= Completer<ByteData>()).future;

  void fournir(String nom, String svg) =>
      demandes['assets/images/concepts/$nom.svg']!.complete(
        ByteData.sublistView(Uint8List.fromList(utf8.encode(svg))),
      );
}

void main() {
  testWidgets(
    'une image réutilisée change de concept et ignore l’ancien chargement',
    (tester) async {
      final images = ImagesControlees();
      Widget monter(String concept) => DefaultAssetBundle(
        bundle: images,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ImageConcept(concept: concept),
        ),
      );
      await tester.pumpWidget(monter('auditancien'));
      await tester.pumpWidget(monter('auditnouveau'));
      const svgNeuf =
          '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><rect width="10" height="10" fill="blue"/></svg>';
      const svgAncien =
          '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><circle r="4" fill="red"/></svg>';
      images.fournir('auditnouveau', svgNeuf);
      await tester.pump();
      images.fournir('auditancien', svgAncien);
      await tester.pump();
      final illustration = tester.widget<SvgPicture>(find.byType(SvgPicture));
      expect(illustration.bytesLoader, const SvgStringLoader(svgNeuf));
      expect(tester.takeException(), isNull);
    },
  );
}
