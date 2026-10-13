import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_studio/features/console/completion_engine.dart';

import '../queue/queue_fake.dart';

void main() {
  late CompletionEngine engine;

  setUp(() async {
    final player = QueueFakePlayer();
    player.rawProperties['property-list'] = 'volume,pause';
    player.rawProperties['options'] = 'volume-max';
    engine = CompletionEngine(player);
    await engine.warmUp();
  });

  test('a quoted argument completes on its text', () async {
    const line = 'get "vol';
    final r = await engine.compute(line, line.length);
    expect(r.tokenSoFar, 'vol');
    expect(r.suggestions.map((s) => s.label), ['volume']);
    expect((r.tokenStart, r.tokenEnd), (4, 8));
  });

  test('prefixes are skipped before the command', () async {
    const line = 'no-osd set vol';
    final r = await engine.compute(line, line.length);
    expect(r.suggestions.map((s) => s.label), ['volume', 'volume-max']);
  });
}
