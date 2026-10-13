import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/effects_page.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/widgets/stage_meters.dart';
import 'package:mpv_studio/ui/widgets/back_bar.dart';

import '../support/fake_engine.dart';

class RecordingTaps {
  final opened = <(AudioFilter, int, TapSide)>[];
  Stream<PcmFrame> call(AudioFilter f, int instance, TapSide side) {
    opened.add((f, instance, side));
    return const Stream.empty();
  }
}

Future<RackController> pumpRack(
  WidgetTester tester,
  FakeEngine engine, {
  RecordingTaps? taps,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final rack = RackController(engine);
  addTearDown(rack.dispose);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RackEnvironment(
          taps: (taps ?? RecordingTaps()).call,
          spectrum: const SpectrumSettings(),
          loudness: const Stream.empty(),
          child: SignalChainView(rack: rack),
        ),
      ),
    ),
  );
  return rack;
}

void main() {
  const bass = BassEffect(gain: 4);
  const comp = AcompressorEffect(ratio: 4);

  testWidgets('shows the chain in order between input and output', (
    tester,
  ) async {
    await pumpRack(tester, FakeEngine([bass, comp, kMeterStage]));
    expect(find.text('INPUT'), findsOneWidget);
    expect(find.text('OUTPUT'), findsOneWidget);
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
    expect(find.text('METER'), findsOneWidget);
    expect(find.text('3 stages, 3 on. Drag to reorder.'), findsOneWidget);
  });

  testWidgets('power, expand, duplicate and remove a stage', (tester) async {
    final engine = FakeEngine([bass]);
    final rack = await pumpRack(tester, engine);
    final id = rack.chain.stages.single.id;

    await tester.tap(find.byKey(ValueKey('stage-power-$id')));
    await tester.pump();
    expect(engine.current, [bass.copyWith(enabled: false)]);

    await tester.tap(find.byKey(ValueKey('stage-header-$id')));
    await tester.pump();
    expect(rack.isExpanded(id), isTrue);
    expect(find.text('Frequency'), findsOneWidget, reason: 'bass editor');
    expect(find.text('Stage is off'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('stage-menu-$id')));
    await tester.pumpAndSettle();
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

  testWidgets('move down from the menu reorders the chain', (tester) async {
    final engine = FakeEngine([bass, comp]);
    final rack = await pumpRack(tester, engine);
    final id = rack.chain.stages.first.id;
    await tester.tap(find.byKey(ValueKey('stage-menu-$id')));
    await tester.pumpAndSettle();
    expect(find.text('Move up'), findsNothing);
    await tester.tap(find.text('Move down').last);
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
    expect(engine.current.first, comp);
    expect(engine.current.toSet(), {bass, comp, kMeterStage});
  });

  testWidgets('add a raw lavfi stage from the sheet and edit it', (
    tester,
  ) async {
    final engine = FakeEngine([bass]);
    final rack = await pumpRack(tester, engine);
    await tester.tap(find.byKey(const ValueKey('rack-add')));
    await tester.pumpAndSettle();
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
    await tester.tap(find.byKey(const ValueKey('add-chorus')));
    await tester.pumpAndSettle();
    expect(engine.current.single, isA<ChorusEffect>());
    expect(engine.current.single.enabled, isTrue, reason: 'valid defaults');
  });

  testWidgets('a refused chain shows an error and rolls back', (tester) async {
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

  testWidgets('bypass plays the chain off and keeps the rack', (tester) async {
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

  testWidgets('a quick tile adds its stage and opens the editor', (
    tester,
  ) async {
    final engine = FakeEngine([comp]);
    final rack = await pumpRack(tester, engine);
    await tester.tap(find.byKey(const ValueKey('quick-bass')));
    await tester.pumpAndSettle();
    expect(engine.current, [comp, const BassEffect()]);
    expect(find.byType(QuickEditorScreen), findsOneWidget);
    expect(find.text('Stage 2 of 2. Low shelf'), findsOneWidget);
    await tester.tap(find.byType(BackBar));
    await tester.pumpAndSettle();
    // A second tap opens the same stage instead of adding one.
    await tester.tap(find.byKey(const ValueKey('quick-bass')));
    await tester.pumpAndSettle();
    expect(rack.chain.length, 2);
  });
}
