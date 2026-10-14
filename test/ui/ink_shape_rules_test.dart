import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/palette.dart';

import '../effects/rack_harness.dart';
import '../settings/studio_fakes.dart';
import '../stream/stream_fakes.dart';
import '../queue/queue_fixture.dart';
import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// The design rule for ink: the hover and the splash of every InkWell
/// take the shape of the surface they light up.
///
/// * An InkWell gives its ink a shape (`customBorder` or `borderRadius`),
///   or sits in a Material that clips to its own shape.
/// * An InkWell shaped like the rounded surface around it (the same
///   corner radius) covers that whole surface, so the hover never stops
///   short of the surface's edge (a row's handle column, say).
void expectInkFollowsShapes(WidgetTester tester) {
  final problems = <String>[];
  for (final element in find.byType(InkWell).evaluate()) {
    final ink = element.widget as InkWell;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) continue;
    final shaped = ink.customBorder != null || ink.borderRadius != null;
    if (!shaped && !_clippedByMaterial(element)) {
      problems.add('${_where(element)}: no ink shape and no clipping Material');
      continue;
    }
    final radius = _radiusOf(ink.customBorder);
    if (radius == null) continue;
    final surface = _roundedSurface(element, radius);
    if (surface == null) continue;
    final inkRect = box.localToGlobal(Offset.zero) & box.size;
    final surfaceRect = surface.localToGlobal(Offset.zero) & surface.size;
    if ((inkRect.width - surfaceRect.width).abs() > 1 ||
        (inkRect.height - surfaceRect.height).abs() > 1) {
      problems.add(
        '${_where(element)}: ink $inkRect inside a surface $surfaceRect '
        'of the same radius',
      );
    }
  }
  expect(problems, isEmpty, reason: problems.join('\n'));
}

String _where(Element e) {
  final keyed = e.widget.key;
  return keyed == null ? 'InkWell under ${_parentType(e)}' : 'InkWell $keyed';
}

String _parentType(Element e) {
  var type = '?';
  var steps = 0;
  e.visitAncestorElements((a) {
    steps++;
    if (a.widget is StatelessWidget || a.widget is StatefulWidget) {
      final name = a.widget.runtimeType.toString();
      if (!name.startsWith('_') && name != 'Semantics') {
        type = name;
        return false;
      }
    }
    return steps < 40;
  });
  return type;
}

bool _clippedByMaterial(Element e) {
  var clipped = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Material) {
      clipped = w.clipBehavior != Clip.none && w.shape != null;
      return false;
    }
    return true;
  });
  return clipped;
}

double? _radiusOf(ShapeBorder? shape) {
  if (shape is RoundedRectangleBorder) {
    final r = shape.borderRadius;
    if (r is BorderRadius) return r.topLeft.x;
  }
  return null;
}

/// The nearest rounded surface around [e] with corner [radius]: an Ink,
/// a DecoratedBox or a Container whose shape has that radius.
RenderBox? _roundedSurface(Element e, double radius) {
  RenderBox? found;
  var steps = 0;
  e.visitAncestorElements((a) {
    steps++;
    final w = a.widget;
    final Decoration? d = switch (w) {
      Ink() => w.decoration,
      DecoratedBox() => w.decoration,
      _ => null,
    };
    if (d is ShapeDecoration && _radiusOf(d.shape) == radius) {
      found = a.renderObject as RenderBox?;
      return false;
    }
    return steps < 16;
  });
  return found;
}

void main() {
  setUpAll(loadStudioFonts);

  for (final palette in [Palette.dark, Palette.light]) {
    final theme = palette.isDark ? 'dark' : 'light';

    testWidgets('$theme queue rows: ink spans the row in every state', (
      tester,
    ) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details, palette: palette);
      // A selected row, a hovered failed row, the playing row.
      await tester.tap(find.text('Peace Piece'));
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(find.text('Failed')));
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
      await mouse.removePointer();
    });

    testWidgets('$theme queue rows on touch', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(
        tester,
        player,
        details,
        palette: palette,
        size: const Size(412, 915),
        input: InputMode.touch,
      );
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme rack stages and the queue menu', (tester) async {
      await pumpRack(
        tester,
        FakeEngine([
          const BassEffect(gain: 6),
          const AcompressorEffect(ratio: 4),
          kMeterStage,
        ]),
        size: const Size(1280, 1600),
        palette: palette,
        before: (rack) => rack.open(rack.chain.stages.first.id),
      );
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme stream rows, the Lab and a library', (tester) async {
      final server = FakeServer(
        connected: true,
        tracks: const [
          ServerTrack(
            id: '1',
            title: 'Sundial',
            artist: 'Mira Okafor',
            album: 'Glass Orchard',
            duration: Duration(minutes: 3),
          ),
        ],
      );
      for (final tab in [StreamTab.lab, StreamTab.jellyfin]) {
        await pumpAt(
          tester,
          streamView(player: StreamPlayer(), jellyfin: server, tab: tab),
          '1440x900',
          palette: palette,
        );
        expectInkFollowsShapes(tester);
      }
    });

    testWidgets('$theme settings tiles and search', (tester) async {
      final h = await SettingsHarness.create();
      await pumpStudio(
        tester,
        h.wrap(const Scaffold(body: SettingsPage())),
        size: const Size(1440, 900),
        palette: palette,
      );
      await tester.pump(const Duration(seconds: 1));
      expectInkFollowsShapes(tester);
      await tester.enterText(find.byType(TextField).first, 'proxy');
      await tester.pump(const Duration(seconds: 1));
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme a row menu', (tester) async {
      final (player, details) = await threeEntries(() => tester.pump());
      await pumpQueue(tester, player, details, palette: palette);
      await tester.tap(find.text('Peace Piece'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
    });
  }
}
