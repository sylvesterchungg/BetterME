import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:betterme/utils/image_helpers.dart';

// A 2x8 red PNG — deliberately tall (1:4), the shape that used to get cropped
// when journal photos were rendered into a fixed-height box with BoxFit.cover.
const String _tallPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAIAAAAICAIAAABcT7kVAAAAEElEQVR4nGP4z8AARAyk'
    'UgDOdw/xdpGrWQAAAABJRU5ErkJggg==';

void main() {
  group('storedImage', () {
    testWidgets('maxHeight caps the box without forcing a fixed height',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: storedImage(
            _tallPng,
            width: double.infinity,
            maxHeight: 320,
            fit: BoxFit.contain,
          ),
        ),
      ));

      final constrained = tester.widget<ConstrainedBox>(
        find
            .ancestor(
              of: find.byType(Image),
              matching: find.byType(ConstrainedBox),
            )
            .first,
      );
      expect(constrained.constraints.maxHeight, 320);

      final image = tester.widget<Image>(find.byType(Image));
      // A null height is what lets the image keep its own aspect ratio; a fixed
      // height combined with BoxFit.cover is exactly what cropped photos.
      expect(image.height, isNull);
      expect(image.fit, BoxFit.contain);
    });

    testWidgets('without maxHeight the widget is a bare Image (avatar case)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: storedImage(_tallPng, width: 40, height: 40),
        ),
      ));

      expect(
        find.ancestor(
          of: find.byType(Image),
          matching: find.byType(ConstrainedBox),
        ),
        findsNothing,
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.cover);
      expect(image.height, 40);
    });

    testWidgets('empty value renders the fallback', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: Text('fallback-shown')),
      ));
      expect(find.byType(Image), findsNothing);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: storedImage('', maxHeight: 320, fallback: const Text('nope')),
        ),
      ));
      expect(find.text('nope'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
  });
}
