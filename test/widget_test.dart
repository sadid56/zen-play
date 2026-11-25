import 'package:flutter_test/flutter_test.dart';
import 'package:zenplay/core/services/tv_service.dart';
import 'package:zenplay/core/state/zenplay_controller.dart';
import 'package:zenplay/main.dart';

void main() {
  testWidgets('ZenPlay renders Home, TV, History, Saved, and Downloads', (WidgetTester tester) async {
    final controller = ZenPlayController(enableRemoteFetch: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(ZenPlayApp(controller: controller));

    expect(find.text('ZenPlay'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('TV'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.byTooltip('Downloads'), findsOneWidget);

    await tester.tap(find.text('TV'));
    await tester.pumpAndSettle();
    expect(find.text('Bangladesh'), findsOneWidget);
    expect(find.text('Movies'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Collections'), findsOneWidget);
    expect(find.text('No saved folders yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Downloads'));
    await tester.pumpAndSettle();
    expect(find.text('No offline videos'), findsOneWidget);
  });

  test('TvService.parseM3u parses channels, deduplicates variants, and skips geo-blocked', () {
    const sampleM3u = '''
#EXTM3U
#EXTINF:-1 tvg-id="movie1.us" tvg-logo="https://example.com/m1.png" group-title="Movies",Cinema One (720p)
https://example.com/cinema1.m3u8
#EXTINF:-1 tvg-id="movie1dup" group-title="Movies",Cinema One (1080p)
https://example.com/cinema1_dup.m3u8
#EXTINF:-1 tvg-id="http1" group-title="Movies",Sony Aath (1080p)
http://example.com/sonyaath.m3u8
#EXTINF:-1 tvg-id="geo" group-title="News",Local News [Geo-blocked]
https://example.com/geoblocked.m3u8
#EXTINF:-1 tvg-id="music1.uk" tvg-logo="https://example.com/mu.png" group-title="Music",Beats HD
https://example.com/beats.m3u8
''';

    final channels = TvService.parseM3u(sampleM3u, defaultCategory: 'All');
    expect(channels.length, 3);
    expect(channels.any((c) => c.name == 'Sony Aath'), isTrue);
    expect(channels.any((c) => c.name == 'Cinema One'), isTrue);
    expect(channels.any((c) => c.name == 'Beats HD'), isTrue);
    expect(channels.any((c) => c.name.contains('Local News')), isFalse);
  });
}
