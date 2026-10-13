import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/widgets/stage_detail.dart';
import 'package:mpv_studio/ui/layout/layout.dart';

import '../support/fake_engine.dart';
import 'rack_harness.dart';

void main() {
  const bass = BassEffect(gain: 4);
  const comp = AcompressorEffect(ratio: 4);

  group('inline rack (pointer, medium window)', () {
    testWidgets('shows the chain in order between input and output', (
      tester,
    ) async {
      await pumpRack(tester, FakeEngine([bass, comp, kMeterStage]));
      expect(find.text('Effects'), findsOneWidget);
      expect(find.text('Input'), findsOneWidget);
      expect(find.text('Output'), findsOneWidget);
      final y = [
        for (final t in ['Bass', 'Compressor', 'Loudness meter'])
          tester
              .getTopLeft(
                find.descendant(
                  of: find.byType(SliverReorderableList),
                  matching: find.text(t),
                ),
              )
              .dy,
      ];
      expect(y, orderedEquals([...y]..sort()));
      expect(find.text('Meter'), findsOneWidget);
      expect(
        find.text('3 stages, 3 on. Drag to reorder, right-click for actions.'),
        findsOneWidget,
      );
    });

    testWidgets('power, expand, duplicate and remove a stage', (tester) async {
      final engine = FakeEngine([bass]);
      final rack = await pumpRack(tester, engine);
      final id = rack.chain.stages.single.id;

      await tester.tap(find.byKey(ValueKey('stage-power-$id')));
      await tester.pump();
      expect(engine.current, [bass.copyWith(enabled: false)]);

      await tester.tap(find.byKey(ValueKey('stage-header-$id')));
      await tester.pumpAndSettle();
      expect(rack.isExpanded(id), isTrue);
      expect(find.text('Frequency'), findsOneWidget, reason: 'bass editor');
      expect(find.text('Stage is off'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('stage-menu-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing, reason: 'a popup');
      await tester.tap(find.text('Duplicate').last);
      await tester.pumpAndSettle();
      expect(engine.current.length, 2);

      final copy = rack.chain.stages[1].id;
      await tester.tap(find.byKey(ValueKey('stage-menu-$copy')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove').last);
      await tester.pumpAndSettle();
      expect(engine.current, [bass.copyWith(enabled: false)]);
    });

    testWidgets('right-click opens the stage menu as a popup', (tester) async {
      final engine = FakeEngine([bass, comp]);
      final rack = await pumpRack(tester, engine);
      final id = rack.chain.stages.first.id;
      await tester.tap(
        find.byKey(ValueKey('stage-header-$id')),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Move down'), findsOneWidget);
      await tester.tap(find.text('Move down'));
      await tester.pumpAndSettle();
      expect(engine.current, [comp, bass]);
    });

    testWidgets('dragging the handle reorders the chain', (tester) async {
      final engine = FakeEngine([bass, comp, kMeterStage]);
      await pumpRack(tester, engine);
      final handle = find.byIcon(Icons.drag_indicator_rounded).first;
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await tester.pump(const Duration(milliseconds: 100));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(0, 14));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      // 140 px down carries the first stage past both others.
      expect(engine.current, [comp, kMeterStage, bass]);
    });

    testWidgets('add a raw lavfi stage from the dialog and edit it', (
      tester,
    ) async {
      final engine = FakeEngine([bass]);
      final rack = await pumpRack(tester, engine);
      await tester.tap(find.byKey(const ValueKey('rack-add')));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('add-raw')));
      await tester.pumpAndSettle();
      expect(engine.current, [bass, const RawAudioEffect('lavfi-anull')]);
      final id = rack.chain.stages.last.id;
      expect(rack.isExpanded(id), isTrue);
      expect(find.text('lavfi entry'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'lavfi-anull'),
        'lavfi-volume=0.5',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(engine.current.last, const RawAudioEffect('lavfi-volume=0.5'));
    });

    testWidgets('search the catalog and add a filter', (tester) async {
      final engine = FakeEngine();
      await pumpRack(tester, engine);
      expect(find.text('The audio plays as decoded.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rack-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('add-stage-search')),
        'chorus',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-acompressor')), findsNothing);
      expect(find.byKey(const ValueKey('add-raw')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-chorus')));
      await tester.pumpAndSettle();
      expect(engine.current.single, isA<ChorusEffect>());
      expect(engine.current.single.enabled, isTrue, reason: 'valid defaults');
    });

    testWidgets('a search with no match says so', (tester) async {
      await pumpRack(tester, FakeEngine());
      await tester.tap(find.byKey(const ValueKey('rack-add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('add-stage-search')),
        'zzzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('No filter matches "zzzz".'), findsOneWidget);
    });

    testWidgets('add a stage before another from its menu', (tester) async {
      final engine = FakeEngine([bass, comp]);
      final rack = await pumpRack(tester, engine);
      await tester.tap(
        find.byKey(ValueKey('stage-menu-${rack.chain.stages[1].id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add a stage before'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-raw')));
      await tester.pumpAndSettle();
      expect(engine.current, [bass, const RawAudioEffect('lavfi-anull'), comp]);
    });

    testWidgets('a refused chain shows an error and rolls back', (
      tester,
    ) async {
      final engine = FakeEngine([bass])
        ..refuse = (fx) => fx.any((e) => e is RawAudioEffect);
      final rack = await pumpRack(tester, engine);
      await tester.tap(find.byKey(const ValueKey('rack-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-raw')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('rack-error')), findsOneWidget);
      expect(find.textContaining('invalid parameter'), findsOneWidget);
      expect(rack.chain.effects, [bass]);
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pump();
      expect(find.byKey(const ValueKey('rack-error')), findsNothing);
    });

    testWidgets('bypass plays the chain off and keeps the rack', (
      tester,
    ) async {
      final engine = FakeEngine([bass, kMeterStage]);
      final rack = await pumpRack(tester, engine);
      await tester.tap(find.byKey(const ValueKey('rack-bypass')));
      await tester.pumpAndSettle();
      expect(find.text('Bypassed'), findsOneWidget);
      expect(engine.current, [bass.copyWith(enabled: false), kMeterStage]);
      expect(rack.chain.effects, [bass, kMeterStage]);
      await tester.tap(find.byKey(const ValueKey('rack-bypass')));
      await tester.pumpAndSettle();
      expect(engine.current, [bass, kMeterStage]);
    });

    testWidgets('open stages tap their own instance, before and after', (
      tester,
    ) async {
      final taps = RecordingTaps();
      final engine = FakeEngine([
        const EqualizerEffect(frequency: 100, gain: 2),
        const EqualizerEffect(frequency: 8000, gain: -2),
      ]);
      final rack = await pumpRack(tester, engine, taps: taps);
      await tester.tap(
        find.byKey(ValueKey('stage-header-${rack.chain.stages[1].id}')),
      );
      await tester.pump();
      expect(taps.opened, [
        (AudioFilter.equalizer, 1, TapSide.pre),
        (AudioFilter.equalizer, 1, TapSide.post),
      ]);
    });

    testWidgets('a quick editor adds its stage once and opens it', (
      tester,
    ) async {
      final engine = FakeEngine([comp]);
      final rack = await pumpRack(tester, engine);
      await tester.tap(find.byKey(const ValueKey('quick-bass')));
      await tester.pumpAndSettle();
      expect(engine.current, [comp, const BassEffect()]);
      expect(rack.isExpanded(rack.chain.stages.last.id), isTrue);
      expect(find.text('Frequency'), findsOneWidget);
      // A second tap opens the same stage instead of adding one.
      await tester.tap(find.byKey(const ValueKey('quick-bass')));
      await tester.pumpAndSettle();
      expect(rack.chain.length, 2);
    });

    testWidgets('opening a stage low in a small window scrolls its controls '
        'on screen', (tester) async {
      const size = Size(800, 560);
      final engine = FakeEngine([
        for (var i = 0; i < 6; i++) BassEffect(gain: i.toDouble()),
      ]);
      final rack = await pumpRack(tester, engine, size: size);
      final last = rack.chain.stages.last.id;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('stage-header-$last')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(ValueKey('stage-header-$last')));
      await tester.pumpAndSettle();
      expect(rack.isExpanded(last), isTrue);
      final gain = tester.getRect(find.text('Gain'));
      expect(gain.bottom, lessThanOrEqualTo(size.height));
      expect(gain.top, greaterThanOrEqualTo(0));
    });
  });

  group('detail rack (touch, compact)', () {
    const phone = Size(360, 780);

    testWidgets('a stage opens over the chain and back closes it', (
      tester,
    ) async {
      final engine = FakeEngine([
        for (var i = 0; i < 6; i++) BassEffect(gain: i.toDouble()),
      ]);
      final rack = await pumpRack(
        tester,
        engine,
        size: phone,
        input: InputMode.touch,
      );
      final last = rack.chain.stages.last.id;
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('stage-header-$last')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(ValueKey('stage-header-$last')));
      await tester.pumpAndSettle();
      expect(find.byType(StageDetail), findsOneWidget);
      expect(find.text('Stage 6 of 6. Low shelf'), findsOneWidget);
      expect(find.byTooltip('Back'), findsOneWidget);
      final gain = tester.getRect(find.text('Gain'));
      expect(gain.bottom, lessThanOrEqualTo(phone.height));
      expect(find.text('Input'), findsNothing, reason: 'chain covered');

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(StageDetail), findsNothing);
      expect(rack.focused, isNull);
      expect(find.text('Input'), findsOneWidget);
    });

    testWidgets('long press opens the stage actions as a sheet', (
      tester,
    ) async {
      final engine = FakeEngine([bass, comp]);
      final rack = await pumpRack(
        tester,
        engine,
        size: phone,
        input: InputMode.touch,
      );
      await tester.longPress(
        find.byKey(ValueKey('stage-header-${rack.chain.stages.first.id}')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      final row = tester.getRect(
        find.ancestor(
          of: find.text('Duplicate'),
          matching: find.byType(InkWell),
        ),
      );
      expect(row.height, greaterThanOrEqualTo(48));
      await tester.tap(find.text('Switch off'));
      await tester.pumpAndSettle();
      expect(engine.current, [bass.copyWith(enabled: false), comp]);
    });

    testWidgets('add stage is a searchable sheet and opens the new stage', (
      tester,
    ) async {
      final engine = FakeEngine([bass]);
      await pumpRack(tester, engine, size: phone, input: InputMode.touch);
      await tester.tap(find.byKey(const ValueKey('rack-add')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('add-stage-search')),
        'chorus',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-chorus')));
      await tester.pumpAndSettle();
      expect(engine.current.last, isA<ChorusEffect>());
      expect(find.byType(StageDetail), findsOneWidget);
    });

    testWidgets('header buttons and stage controls are 48 dp', (tester) async {
      final rack = await pumpRack(
        tester,
        FakeEngine([bass]),
        size: phone,
        input: InputMode.touch,
      );
      final id = rack.chain.stages.single.id;
      for (final key in [
        const ValueKey('rack-add'),
        const ValueKey('rack-bypass'),
        ValueKey('stage-power-$id'),
        ValueKey('stage-menu-$id'),
        const ValueKey('quick-superequalizer'),
      ]) {
        final r = tester.getRect(find.byKey(key));
        expect(r.height, greaterThanOrEqualTo(48), reason: '$key');
      }
      final handle = tester.getRect(
        find
            .ancestor(
              of: find.byIcon(Icons.drag_indicator_rounded),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(handle.width, greaterThanOrEqualTo(48), reason: 'drag handle');
      expect(handle.height, greaterThanOrEqualTo(48), reason: 'drag handle');
    });
  });

  testWidgets('a wide window edits beside the chain', (tester) async {
    final engine = FakeEngine([bass, comp]);
    final rack = await pumpRack(tester, engine, size: const Size(1440, 900));
    expect(find.text('Pick a stage to edit it here.'), findsOneWidget);
    final id = rack.chain.stages.first.id;
    await tester.tap(find.byKey(ValueKey('stage-header-$id')));
    await tester.pumpAndSettle();
    expect(find.byType(StageDetail), findsOneWidget);
    expect(find.text('Input'), findsOneWidget, reason: 'chain in view');
    expect(find.text('Gain'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('detail-close')));
    await tester.pumpAndSettle();
    expect(find.byType(StageDetail), findsNothing);
  });
}
