import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/saved_chains.dart';

import '../support/fake_engine.dart';
import '../support/finders.dart';
import 'rack_harness.dart';

const _bass = BassEffect(gain: 4);
const _comp = AcompressorEffect(ratio: 4);

Future<void> _openChains(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('rack-chains')));
  await tester.pumpAndSettle();
}

void main() {
  test('a chain goes to text and back', () {
    final text = chainToText([_bass, _comp]);
    expect(chainFromText(text), [_bass, _comp]);
    expect(chainFromText('not a chain'), isNull);
    expect(chainFromText('{}'), isNull);
  });

  testWidgets('save the chain under a name and load it back with an undo', (
    tester,
  ) async {
    final engine = FakeEngine([_bass, _comp]);
    final library = MemoryChainLibrary();
    final rack = await pumpRack(tester, engine, chains: library);
    await _openChains(tester);
    await tester.tap(find.text('Save as…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Late night');
    await tester.tap(buttonWithText<FilledButton>('Save'));
    await tester.pumpAndSettle();
    expect(library.chains, {
      'Late night': [_bass, _comp],
    });
    expect(find.text('Saved "Late night"'), findsOneWidget);

    rack.remove(rack.chain.stages.first.id);
    await tester.pumpAndSettle();
    await _openChains(tester);
    await tester.tap(find.text('Late night'));
    await tester.pumpAndSettle();
    expect(engine.current, [_bass, _comp]);
    expect(find.text('Loaded "Late night"'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(engine.current, [_comp]);
  });

  testWidgets('copy as text and paste it back', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final engine = FakeEngine([_bass]);
    await pumpRack(tester, engine, chains: MemoryChainLibrary());
    await _openChains(tester);
    await tester.tap(find.text('Copy as text'));
    await tester.pumpAndSettle();
    expect(chainFromText(copied!), [_bass]);

    await _openChains(tester);
    await tester.tap(find.text('Paste a chain…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, chainToText([_comp]));
    await tester.tap(buttonWithText<FilledButton>('Load'));
    await tester.pumpAndSettle();
    expect(engine.current, [_comp]);

    await _openChains(tester);
    await tester.tap(find.text('Paste a chain…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'hello');
    await tester.tap(buttonWithText<FilledButton>('Load'));
    await tester.pumpAndSettle();
    expect(find.text('That text is not an effects chain.'), findsOneWidget);
    expect(engine.current, [_comp]);
  });

  testWidgets('a saved chain can be deleted, with an undo', (tester) async {
    final library = MemoryChainLibrary()..save('Warm', [_bass]);
    await pumpRack(tester, FakeEngine(), chains: library);
    await _openChains(tester);
    await tester.tap(find.text('Delete a saved chain…'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete "Warm"'));
    await tester.pumpAndSettle();
    expect(library.chains, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(library.chains.keys, ['Warm']);
  });
}
