import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'cursor.dart';
import 'motion.dart';

/// Where a scene writes its frames, from the `SHOWCASE_OUT` environment
/// variable that `tool/showcase/render.sh` sets; null when unset (the
/// scene then plays without capturing, as a smoke test).
String? get showcaseOut {
  final dir = Platform.environment['SHOWCASE_OUT'];
  return dir == null || dir.isEmpty ? null : dir;
}

/// Frames per second of the capture, from `SHOWCASE_FPS` (default 50).
int get showcaseFps =>
    int.tryParse(Platform.environment['SHOWCASE_FPS'] ?? '') ?? 50;

/// How often a scene's live readouts (the spectrum, the playhead) move
/// on, from `SHOWCASE_UPDATE_HZ`; null (unset) moves them every frame.
/// render.sh slows them for the GIF, where each update costs bytes.
double? get showcaseUpdateHz =>
    double.tryParse(Platform.environment['SHOWCASE_UPDATE_HZ'] ?? '');

/// The capture's pixels per logical pixel, from `SHOWCASE_SCALE`
/// (default 1).
double get showcaseScale =>
    double.tryParse(Platform.environment['SHOWCASE_SCALE'] ?? '') ?? 1;

/// Wraps the app for a scene: the captured boundary with the drawn
/// cursor over everything the app shows.
class ShowcaseStage extends StatelessWidget {
  const ShowcaseStage({super.key, required this.scene, required this.child});

  final Scene scene;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: scene._boundary,
      child: ShowcaseOverlay(frame: scene._overlay, child: child),
    );
  }
}

/// Plays a scripted scene on the real app in a widget test, one fixed
/// step per frame, and captures each frame to a numbered PNG.
///
/// The pointer is a real mouse: every frame of a glide is a hover event,
/// so hover states, tooltips and the app's own cursor kinds follow it,
/// and clicks, drags and wheel steps reach the app as they would from a
/// person. The cursor itself is drawn by [ShowcaseStage], in the shape of
/// the system cursor the app asks for.
///
/// [onFrame] runs before each frame with the scene time, to drive what a
/// real player would (the position, the spectrum, the meters).
class Scene {
  Scene(
    this.tester, {
    int? fps,
    this.outDir,
    double? scale,
    this.onFrame,
    Offset start = Offset.zero,
  }) : fps = fps ?? showcaseFps,
       scale = scale ?? showcaseScale,
       _pointerAt = start;

  final WidgetTester tester;
  final int fps;

  /// Where frames go; null plays without capturing.
  final String? outDir;
  final double scale;

  /// Runs before each frame with its scene time and length.
  void Function(Duration time, Duration step)? onFrame;

  final GlobalKey _boundary = GlobalKey(debugLabel: 'showcase');
  final ValueNotifier<OverlayFrame> _overlay = ValueNotifier(
    const OverlayFrame(time: Duration.zero),
  );
  final TestPointer _mouse = TestPointer(
    1,
    PointerDeviceKind.mouse,
    null,
    kPrimaryButton,
  );
  final SceneRandom random = SceneRandom();

  Offset _pointerAt;
  bool _pointerShown = false;
  double _press = 0;
  final List<ClickRing> _rings = [];
  final List<KeyCap> _keys = [];

  /// Frames played (captured or not) and frames written.
  int _frame = 0;
  int _written = 0;
  bool _recording = false;

  /// The length of one frame.
  Duration get step => Duration(microseconds: 1000000 ~/ fps);

  /// The scene time of the next frame.
  Duration get time => step * _frame;

  /// Frames written so far.
  int get written => _written;

  /// Where the pointer is.
  Offset get pointer => _pointerAt;

  /// How many frames [ms] milliseconds take (at least one).
  int framesFor(int ms) => (ms * fps / 1000).round().clamp(1, 1 << 20);

  /// Puts the mouse on screen at [at] (a hover, no glide).
  Future<void> showPointer([Offset? at]) async {
    _pointerAt = at ?? _pointerAt;
    await tester.sendEventToBinding(
      _mouse.addPointer(location: _pointerAt, timeStamp: time),
    );
    _pointerShown = true;
    await tester.sendEventToBinding(_mouse.hover(_pointerAt, timeStamp: time));
  }

  /// Starts writing frames: what plays before is the warm-up.
  void record() => _recording = true;

  /// Stops writing frames.
  void stop() => _recording = false;

  /// Plays one frame: the frame hook, the overlay, a pump of one step,
  /// then the capture.
  Future<void> frame() async {
    onFrame?.call(time, step);
    _rings.removeWhere((r) => time - r.start > ClickRing.life);
    _keys.removeWhere((k) => time > k.end);
    _overlay.value = OverlayFrame(
      time: time,
      pointer: _pointerShown ? _pointerAt : null,
      shape: _shape(),
      press: _press,
      rings: List.of(_rings),
      keys: List.of(_keys),
    );
    await tester.pump(step);
    if (_recording && outDir != null) await _capture();
    _frame++;
  }

  CursorShape _shape() {
    // The cursor the app asks for at the pointer: a debug hook, which is
    // what this is (scenes run in widget tests, never in the app).
    final cursor = RendererBinding.instance.mouseTracker
        // ignore: invalid_use_of_visible_for_testing_member
        .debugDeviceActiveCursor(_mouse.device);
    return cursorShapeFor(cursor is SystemMouseCursor ? cursor.kind : null);
  }

  Future<void> _capture() async {
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final name = '$outDir/frame_${_written.toString().padLeft(5, '0')}.png';
    _written++;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: scale);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(name).writeAsBytes(png!.buffer.asUint8List());
    });
  }

  /// Holds still for [ms] milliseconds.
  Future<void> wait(int ms) async {
    for (var i = framesFor(ms); i > 0; i--) {
      await frame();
    }
  }

  Future<void> _hoverTo(Offset at) async {
    _pointerAt = at;
    await tester.sendEventToBinding(
      _mouse.isDown
          ? _mouse.move(at, timeStamp: time)
          : _mouse.hover(at, timeStamp: time),
    );
  }

  /// Glides to [target] along a gently curved, eased path, a hover event
  /// on every frame. [ms] defaults to a time scaled by the distance.
  Future<void> moveTo(Offset target, {int? ms}) async {
    final path = GlidePath(_pointerAt, target);
    final n = framesFor(ms ?? glideMillis(path.length));
    for (var i = 1; i <= n; i++) {
      await _hoverTo(path.at(i / n));
      await frame();
    }
  }

  /// Glides onto [finder]'s widget, at [alignment] inside it plus [nudge].
  Future<void> moveOnto(
    Finder finder, {
    Alignment alignment = Alignment.center,
    Offset nudge = Offset.zero,
    int? ms,
  }) => moveTo(rectOf(finder).inner(alignment) + nudge, ms: ms);

  /// The global rectangle of [finder]'s single widget.
  Rect rectOf(Finder finder) => tester.getRect(finder);

  /// Clicks where the pointer is: a short settle, the cursor dips, a ring
  /// spreads, and the press and release reach the app on those frames.
  Future<void> click({int buttons = kPrimaryButton, int settleMs = 140}) async {
    await wait(settleMs);
    _press = 1;
    _rings.add(ClickRing(_pointerAt, time));
    await tester.sendEventToBinding(
      _mouse.down(_pointerAt, timeStamp: time, buttons: buttons),
    );
    await wait(70);
    await tester.sendEventToBinding(_mouse.up(timeStamp: time));
    _press = 0.45;
    await frame();
    _press = 0;
  }

  /// A right click where the pointer is.
  Future<void> rightClick() => click(buttons: kSecondaryButton);

  /// Presses where the pointer is, glides to [to] holding the button, and
  /// releases there.
  Future<void> drag(Offset to, {int? ms}) async {
    await wait(120);
    _press = 1;
    await tester.sendEventToBinding(
      _mouse.down(_pointerAt, timeStamp: time, buttons: kPrimaryButton),
    );
    await wait(60);
    await moveTo(to, ms: ms);
    await wait(60);
    await tester.sendEventToBinding(_mouse.up(timeStamp: time));
    _press = 0;
    await frame();
  }

  /// Turns the wheel by [delta] in total, in [steps] notches spread over
  /// [ms] milliseconds (a few frames apart, like a hand on a wheel).
  Future<void> scroll(Offset delta, {int steps = 6, int ms = 600}) async {
    final gap = (framesFor(ms) / steps).floor().clamp(1, 1 << 20);
    for (var i = 0; i < steps; i++) {
      await tester.sendEventToBinding(
        _mouse.scroll(delta / steps.toDouble(), timeStamp: time),
      );
      for (var f = 0; f < gap; f++) {
        await frame();
      }
    }
  }

  /// Types [text] one character at a time into the focused field, with a
  /// slightly uneven rhythm around [msPerChar].
  Future<void> type(String text, {int msPerChar = 90}) async {
    final input = tester.testTextInput;
    var typed = input.editingState?['text'] as String? ?? '';
    for (final rune in text.runes) {
      typed += String.fromCharCode(rune);
      input.updateEditingValue(
        TextEditingValue(
          text: typed,
          selection: TextSelection.collapsed(offset: typed.length),
        ),
      );
      final ms = msPerChar * random.range(0.6, 1.5);
      await wait(rune == 0x20 ? (ms * 1.4).round() : ms.round());
    }
  }

  /// Presses and releases [key], showing [label] on a key cap while it
  /// is down and a moment after.
  Future<void> press(
    LogicalKeyboardKey key, {
    required String label,
    int holdMs = 650,
  }) async {
    _keys.add(KeyCap(label, time, Duration(milliseconds: holdMs)));
    await wait(80);
    await tester.sendKeyDownEvent(key);
    await wait(90);
    await tester.sendKeyUpEvent(key);
  }

  /// Takes the pointer off screen and lets the remaining timers run out,
  /// so the test ends clean.
  Future<void> finish() async {
    stop();
    if (_pointerShown) {
      await tester.sendEventToBinding(_mouse.removePointer(timeStamp: time));
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    _overlay.dispose();
  }
}

extension on Rect {
  /// The point at [a] inside this rectangle.
  Offset inner(Alignment a) => a.withinRect(this);
}
