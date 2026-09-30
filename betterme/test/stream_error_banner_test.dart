import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:betterme/widgets/stream_error_banner.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('StreamErrorBanner', () {
    testWidgets('shows the summary it is given', (tester) async {
      await tester.pumpWidget(_host(
        StreamErrorBanner(summary: "Friends isn't syncing", onRetry: () {}),
      ));

      expect(find.text("Friends isn't syncing"), findsOneWidget);
    });

    testWidgets('explains that the data on screen is stale', (tester) async {
      // The whole point of the banner: the user must know the numbers they are
      // looking at are the last ones received, not the current ones.
      await tester.pumpWidget(_host(
        StreamErrorBanner(summary: 'x', onRetry: () {}),
      ));

      expect(find.text('Showing the last data received.'), findsOneWidget);
    });

    testWidgets('tapping Retry invokes the callback', (tester) async {
      var retried = 0;
      await tester.pumpWidget(_host(
        StreamErrorBanner(summary: 'x', onRetry: () => retried++),
      ));

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, 1);
    });
  });
}
