import 'package:flutter_test/flutter_test.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/main.dart';

void main() {
  testWidgets('ZenPlay renders Home, History, and Downloads', (WidgetTester tester) async {
    final controller = ZenPlayController(enableRemoteFetch: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(ZenPlayApp(controller: controller));

    expect(find.text('ZenPlay'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);

    await tester.tap(find.text('Downloads'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Deep Focus Ambient Session'), findsOneWidget);
  });
}
