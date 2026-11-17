import 'package:flutter_test/flutter_test.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/main.dart';

void main() {
  testWidgets('ZenPlay renders Home, History, Saved, and Downloads', (WidgetTester tester) async {
    final controller = ZenPlayController(enableRemoteFetch: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(ZenPlayApp(controller: controller));

    expect(find.text('ZenPlay'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byTooltip('Downloads'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Collections'), findsOneWidget);
    expect(find.text('No saved folders yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('No offline videos'), findsOneWidget);
  });
}
