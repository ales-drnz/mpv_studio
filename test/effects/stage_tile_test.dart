import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_controller.dart';
import 'package:mpv_studio/features/effects/widgets/stage_tile.dart';

import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

void main() {
  testWidgets('the header ink spans the whole tile, handle included', (
    tester,
  ) async {
    final rack = RackController(FakeEngine([const BassEffect(gain: 4)]));
    addTearDown(rack.dispose);
    final id = rack.chain.stages.first.id;
    var taps = 0;
    await pumpStudio(
      tester,
      Scaffold(
        body: ReorderableListView(
          // ignore: deprecated_member_use
          onReorder: (_, _) {},
          buildDefaultDragHandles: false,
          children: [
            StageTile(
              key: const ValueKey('tile'),
              rack: rack,
              id: id,
              index: 0,
              inline: false,
              selected: true,
              onTap: () => taps++,
              onAction: (_) {},
            ),
          ],
        ),
      ),
      size: const Size(480, 200),
    );
    final tile = tester.getRect(find.byType(StageTile));
    final ink = tester.getRect(find.byKey(ValueKey('stage-header-$id')));
    // Edge to edge: the tile's clip rounds the hover, not a corner of
    // its own in the middle of the tile.
    expect(ink.left, tile.left);
    expect(ink.right, tile.right);

    await tester.tap(find.text('Bass'));
    expect(taps, 1);
    // The drag handle does not open the stage.
    await tester.tap(find.byIcon(Icons.drag_indicator_rounded));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}
