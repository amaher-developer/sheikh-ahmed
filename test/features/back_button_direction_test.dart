import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/shared/widgets/sub_screen_header.dart';

/// Renders the header inside a route that can be popped, so its back
/// control is shown at all (it hides itself when there is nowhere to go).
Future<Icon> _backIcon(WidgetTester tester, material.TextDirection dir) async {
  await tester.pumpWidget(
    MaterialApp(
      home: const Scaffold(body: Text('root')),
      builder: (context, child) => Directionality(
        textDirection: dir,
        child: child!,
      ),
    ),
  );
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => const Scaffold(
        body: SubScreenHeader(child: SubScreenTitleRow(title: 'x')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.widget<Icon>(find.byType(Icon).first);
}

void main() {
  testWidgets('the back control uses the back glyph, not forward', (
    tester,
  ) async {
    // The bug: the header used Icons.arrow_forward_rounded as a manual RTL
    // compensation. Material had already mirrored it, so the two cancelled
    // and the arrow pointed inward — the wrong way — in Arabic.
    final rtl = await _backIcon(tester, material.TextDirection.rtl);
    expect(rtl.icon, Icons.arrow_back_rounded);

    final ltr = await _backIcon(tester, material.TextDirection.ltr);
    expect(ltr.icon, Icons.arrow_back_rounded);
  });

  test('that glyph is one Material mirrors per text direction', () {
    // This flag is what makes English the mirror of Arabic without the
    // widget branching on locale. If it were ever false, the widget would
    // have to pick the glyph itself and the arrow would point one way in
    // both languages.
    expect(Icons.arrow_back_rounded.matchTextDirection, isTrue);

    // The glyph that was there before is mirrored too — which is precisely
    // why naming it "forward" to compensate produced a double flip.
    expect(Icons.arrow_forward_rounded.matchTextDirection, isTrue);
  });
}
