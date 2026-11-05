import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import 'package:mpv_studio/features/console/console_log.dart';
import 'package:mpv_studio/features/effects/rack_catalog.dart';
import 'package:mpv_studio/features/settings/settings_page.dart';
import 'package:mpv_studio/features/stream/media_server.dart';
import 'package:mpv_studio/features/stream/stream_page.dart';
import 'package:mpv_studio/ui/layout/layout.dart';
import 'package:mpv_studio/ui/tokens.dart';
import 'package:mpv_studio/ui/widgets/focus_ring.dart';

import '../console/console_fixture.dart';
import '../effects/rack_harness.dart';
import '../now_playing/playback_fake.dart';
import '../now_playing/playback_harness.dart';
import '../onboarding/onboarding_test.dart' show pumpWelcome;
import '../settings/studio_fakes.dart';
import '../stream/stream_fakes.dart';
import '../queue/queue_fake.dart';
import '../queue/queue_fixture.dart';
import '../support/fake_engine.dart';
import '../support/layout_harness.dart';

/// The design rule for ink: the hover and the splash of every InkWell
/// take the shape of the surface they light up.
///
/// * An InkWell gives its ink a shape (`customBorder` or `borderRadius`),
///   or fills a Material that clips to its own shape (a Material that only
///   clips a bigger surface, a menu around its items, leaves the item's
///   ink a rectangle).
/// * An InkWell shaped like the rounded surface around it (the same
///   corner radius) covers that whole surface, so the hover never stops
///   short of the surface's edge (a row's handle column, say).
/// * An InkWell that covers a rounded box takes that box's shape: a pill
///   of ink on a rounded card, or a rectangle on a pill, lights past or
///   short of the box's corners.
void expectInkFollowsShapes(WidgetTester tester) {
  final problems = inkProblems(tester);
  expect(problems, isEmpty, reason: problems.join('\n'));
}

/// What [expectInkFollowsShapes] finds wrong on screen.
List<String> inkProblems(WidgetTester tester) {
  final problems = <String>[];
  for (final element in find.byType(InkWell).evaluate()) {
    final ink = element.widget as InkWell;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) continue;
    final shaped = ink.customBorder != null || ink.borderRadius != null;
    if (!shaped && !_filledClippingMaterial(element, box)) {
      problems.add(
        '${_where(element)}: no ink shape and no clipping Material it fills',
      );
      continue;
    }
    final box2 = _boxCovered(element, box);
    final inkRect0 = box.localToGlobal(Offset.zero) & box.size;
    if (shaped && box2 != null && !_sameShape(ink, box2, inkRect0)) {
      problems.add(
        '${_where(element)}: ink ${_shapeName(ink.customBorder)} on a box '
        '${_shapeName(box2)} of the same size',
      );
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
  return problems;
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

/// Whether [e] sits in a Material that clips to its shape and that the
/// ink [box] fills.
bool _filledClippingMaterial(Element e, RenderBox box) {
  var clipped = false;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is Material) {
      final m = a.renderObject as RenderBox?;
      clipped =
          w.clipBehavior != Clip.none &&
          w.shape != null &&
          m != null &&
          _sameRect(box, m);
      return false;
    }
    return true;
  });
  return clipped;
}

bool _sameRect(RenderBox a, RenderBox b) {
  final ra = a.localToGlobal(Offset.zero) & a.size;
  final rb = b.localToGlobal(Offset.zero) & b.size;
  return (ra.left - rb.left).abs() <= 1 &&
      (ra.top - rb.top).abs() <= 1 &&
      (ra.width - rb.width).abs() <= 1 &&
      (ra.height - rb.height).abs() <= 1;
}

/// The shape of a filled, shaped box around [e] (a decoration or a
/// coloured Material) that the ink [box] covers exactly, if any: it climbs
/// while the ancestors keep the ink's rect, whatever widgets sit between
/// (a focus ring, the Material's own), and stops at the first bigger one.
ShapeBorder? _boxCovered(Element e, RenderBox box) {
  ShapeBorder? found;
  e.visitAncestorElements((a) {
    final r = a.renderObject;
    if (r is RenderBox && r.hasSize && !_sameRect(box, r)) return false;
    final w = a.widget;
    final ShapeBorder? shape = switch (w) {
      Ink(:final decoration?) => _shapeOfDecoration(decoration),
      DecoratedBox(:final decoration) => _shapeOfDecoration(decoration),
      Material(:final shape?, :final color?) when color.a > 0 => shape,
      _ => null,
    };
    if (shape != null) {
      found = shape;
      return false;
    }
    return true;
  });
  return found;
}

ShapeBorder? _shapeOfDecoration(Decoration d) => switch (d) {
  ShapeDecoration(:final shape, :final color?) when color.a > 0 => shape,
  BoxDecoration(:final borderRadius?, :final color?) when color.a > 0 =>
    RoundedRectangleBorder(borderRadius: borderRadius),
  BoxDecoration(shape: BoxShape.circle, :final color?) when color.a > 0 =>
    const CircleBorder(),
  _ => null,
};

/// Whether the ink's shape and [box]'s draw the same outline on [rect]:
/// a pill and a rounded rectangle of half the height's radius do.
bool _sameShape(InkWell ink, ShapeBorder box, Rect rect) {
  final inkShape =
      ink.customBorder ??
      RoundedRectangleBorder(borderRadius: ink.borderRadius!);
  final a = inkShape.getOuterPath(rect, textDirection: TextDirection.ltr);
  final b = box.getOuterPath(rect, textDirection: TextDirection.ltr);
  // Probe the corners, where shapes differ, on a fine grid.
  const steps = 12;
  final probe = math.min(rect.shortestSide, 48.0);
  for (final corner in [
    rect.topLeft,
    rect.topRight,
    rect.bottomLeft,
    rect.bottomRight,
  ]) {
    for (var i = 0; i < steps; i++) {
      for (var j = 0; j < steps; j++) {
        final dx = (i + 0.5) / steps * probe / 2;
        final dy = (j + 0.5) / steps * probe / 2;
        final p = Offset(
          corner.dx == rect.left ? rect.left + dx : rect.right - dx,
          corner.dy == rect.top ? rect.top + dy : rect.bottom - dy,
        );
        if (a.contains(p) != b.contains(p)) return false;
      }
    }
  }
  return true;
}

String _shapeName(ShapeBorder? s) => switch (s) {
  StadiumBorder() => 'pill',
  CircleBorder() => 'circle',
  RoundedRectangleBorder(:final BorderRadius borderRadius) =>
    'rounded ${borderRadius.topLeft.x}',
  RoundedRectangleBorder() => 'rounded',
  _ => '$s',
};

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
      await tester.tap(find.text('Kveld'));
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
      await tester.tap(find.text('Kveld'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme the shells and the mini-player', (tester) async {
      for (final (size, input) in [
        (const Size(1440, 900), InputMode.pointer),
        (const Size(800, 1280), InputMode.touch),
        (const Size(412, 915), InputMode.touch),
      ]) {
        await pumpShell(tester, size: size, input: input, palette: palette);
        expectInkFollowsShapes(tester);
      }
      // The phone's More sheet.
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme Playback, its menus and dialogs', (tester) async {
      final player = playingTrack();
      await pumpPlayback(
        tester,
        player,
        size: studioSize('1440x900'),
        palette: palette,
      );
      expectInkFollowsShapes(tester);
      await tester.tap(find.byTooltip('Playback speed'));
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
      await tester.tap(find.text('Speed and pitch'));
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme the Console and its suggestions', (tester) async {
      final player = QueueFakePlayer();
      final log = ConsoleLog()..attach(player);
      addTearDown(log.dispose);
      await pumpConsole(tester, player, log, palette: palette);
      expectInkFollowsShapes(tester);
    });

    testWidgets('$theme the welcome screen', (tester) async {
      await pumpWelcome(tester, size: '1440x900', palette: palette);
      expectInkFollowsShapes(tester);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('$theme the add stage dialog', (tester) async {
      await pumpRack(tester, FakeEngine(const []), palette: palette);
      await tester.tap(find.text('Add stage').first);
      await tester.pumpAndSettle();
      expectInkFollowsShapes(tester);
    });
  }

  testWidgets('the rule sees a coloured Material around a focus ring', (
    tester,
  ) async {
    await pumpStudio(
      tester,
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            height: 48,
            child: Material(
              color: Palette.dark.surface,
              shape: const StadiumBorder(),
              child: FocusRing(
                child: InkWell(
                  onTap: () {},
                  customBorder: Tokens.shape(Tokens.rXs),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(inkProblems(tester), isNotEmpty);
  });

  testWidgets('the three column pages', (tester) async {
    final (player, details) = await threeEntries(() => tester.pump());
    await pumpQueue(tester, player, details, size: const Size(2560, 1080));
    expectInkFollowsShapes(tester);
    final console = QueueFakePlayer();
    final log = ConsoleLog()..attach(console);
    addTearDown(log.dispose);
    await pumpConsole(tester, console, log, size: const Size(2560, 1080));
    expectInkFollowsShapes(tester);
    final h = await SettingsHarness.create();
    await pumpStudio(
      tester,
      h.wrap(const Scaffold(body: SettingsPage())),
      size: const Size(2560, 1080),
    );
    expectInkFollowsShapes(tester);
    await tester.pump(const Duration(seconds: 1));
  });
}
