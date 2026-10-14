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
/// With [touch] the pointer is a finger instead: it shows as a soft
/// circle only while it touches, and [tap], [doubleTap], [longPress],
/// [swipe] and [fingerDrag] play the gestures.
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
    this.touch = false,
    Offset start = Offset.zero,
  }) : fps = fps ?? showcaseFps,
       scale = scale ?? showcaseScale,
       _pointerAt = start,
       _mouse = TestPointer(
         1,
         touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
         null,
         kPrimaryButton,
       );

  /// Whether the pointer is a finger on a touch screen.
  final bool touch;

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
  TestPointer _mouse;

  /// The next pointer id: each touch is a new pointer, as on a screen.
  int _nextTouch = 2;
  final SceneRandom random = SceneRandom();

  /// Where key caps show: top right by default, clear of the page title
  /// and of the toasts at the foot; a scene moves them off its controls.
  Alignment keyAlignment = Alignment.topRight;

  Offset _pointerAt;
  bool _pointerShown = false;
  double _press = 0;

  /// The finger's fade: when it last lifted, or null while it touches or
  /// before the first touch.
  Duration? _liftedAt;
  static const Duration _fingerFade = Duration(milliseconds: 220);
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

  /// Frames recorded so far (written, when there is an [outDir]).
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
      shape: touch ? CursorShape.finger : _shape(),
      press: _press,
      opacity: _opacity(),
      rings: List.of(_rings),
      keys: List.of(_keys),
    );
    await tester.pump(step);
    if (_recording) {
      if (outDir != null) await _capture();
      _written++;
    }
    _frame++;
  }

  double _opacity() {
    if (!touch) return 1;
    if (_mouse.isDown) return 1;
    final lifted = _liftedAt;
    if (lifted == null) return 0;
    final t = (time - lifted).inMicroseconds / _fingerFade.inMicroseconds;
    return (1 - easeOut(t)).clamp(0.0, 1.0);
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
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: scale);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await File(name).writeAsBytes(png!.buffer.asUint8List());
    });
  }

  /// Lets images that just appeared finish decoding, which happens off
  /// the fake clock: real time passes, scene time does not, so the next
  /// frame shows them on every run.
  Future<void> settleImages() async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump(Duration.zero);
    }
  }

  /// Holds still for [ms] milliseconds.
  Future<void> wait(int ms) async {
    for (var i = framesFor(ms); i > 0; i--) {
      await frame();
    }
  }

  Future<void> _hoverTo(Offset at) async {
    _pointerAt = at;
    // A lifted finger moves unseen and tells the app nothing.
    if (touch && !_mouse.isDown) return;
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

  /// A double click where the pointer is.
  Future<void> doubleClick() async {
    await wait(140);
    for (var i = 0; i < 2; i++) {
      _press = 1;
      _rings.add(ClickRing(_pointerAt, time));
      await tester.sendEventToBinding(
        _mouse.down(_pointerAt, timeStamp: time, buttons: kPrimaryButton),
      );
      await wait(50);
      await tester.sendEventToBinding(_mouse.up(timeStamp: time));
      _press = 0;
      await wait(70);
    }
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
    _keys.add(
      KeyCap(
        label,
        time,
        Duration(milliseconds: holdMs),
        alignment: keyAlignment,
      ),
    );
    await wait(80);
    await tester.sendKeyDownEvent(key);
    await wait(90);
    await tester.sendKeyUpEvent(key);
  }

  Future<void> _touchDown(Offset at) async {
    _mouse = TestPointer(_nextTouch++, PointerDeviceKind.touch);
    _pointerAt = at;
    _pointerShown = true;
    _liftedAt = null;
    _press = 1;
    await tester.sendEventToBinding(_mouse.down(at, timeStamp: time));
  }

  Future<void> _touchUp() async {
    await tester.sendEventToBinding(_mouse.up(timeStamp: time));
    _press = 0;
    _liftedAt = time;
  }

  /// A tap of the finger at [at], held [holdMs], with a ring as it lands.
  Future<void> tap(Offset at, {int holdMs = 90}) async {
    _rings.add(ClickRing(at, time));
    await _touchDown(at);
    await wait(holdMs);
    await _touchUp();
    await frame();
  }

  /// A tap on [finder]'s widget, at [alignment] inside it.
  Future<void> tapOn(Finder finder, {Alignment alignment = Alignment.center}) =>
      tap(alignment.withinRect(rectOf(finder)));

  /// Two quick taps at [at].
  Future<void> doubleTap(Offset at) async {
    await tap(at, holdMs: 60);
    await wait(60);
    await tap(at, holdMs: 60);
  }

  /// Presses at [at] for [holdMs]; with [then], drags there afterwards
  /// (a long press that picks something up), and lifts.
  Future<void> longPress(
    Offset at, {
    int holdMs = 700,
    Offset? then,
    int? ms,
  }) async {
    await _touchDown(at);
    await wait(holdMs);
    if (then != null) await moveTo(then, ms: ms);
    await wait(80);
    await _touchUp();
    await frame();
  }

  /// A swipe from [from] to [to] in [ms]: it speeds up and lets go while
  /// moving, so lists and pages carry on with their own inertia. Without
  /// [fling] it slows down before letting go.
  Future<void> swipe(
    Offset from,
    Offset to, {
    int ms = 260,
    bool fling = true,
  }) async {
    await _touchDown(from);
    await frame();
    // Several moves a frame, the last one with the lift: Flutter's
    // velocity tracker takes a pointer that pauses 40 ms as stopped, which
    // would leave a swipe with no speed.
    const perFrame = 5;
    final n = framesFor(ms) * perFrame;
    final sub = step ~/ perFrame;
    for (var i = 1; i <= n; i++) {
      final t = i / n;
      final s = fling ? t * t : easeInOut(t);
      final at = Offset.lerp(from, to, s)!;
      final stamp = time - step + sub * ((i - 1) % perFrame + 1);
      _pointerAt = at;
      await tester.sendEventToBinding(_mouse.move(at, timeStamp: stamp));
      if (i % perFrame == 0 && i < n) await frame();
    }
    await tester.sendEventToBinding(_mouse.up(timeStamp: time));
    _press = 0;
    _liftedAt = time;
    await frame();
  }

  /// A finger that lands on [from], glides to [to] and lifts, with short
  /// holds at both ends (dragging a slider or a handle).
  Future<void> fingerDrag(Offset from, Offset to, {int? ms}) async {
    await _touchDown(from);
    await wait(120);
    await moveTo(to, ms: ms);
    await wait(100);
    await _touchUp();
    await frame();
  }

  /// Presses Enter in the focused text field: the key cap shows, the key
  /// goes to the app's key handlers, then the field submits, as the
  /// keyboard's action would.
  Future<void> submit({
    TextInputAction action = TextInputAction.done,
    String label = 'Enter',
  }) async {
    await press(LogicalKeyboardKey.enter, label: label);
    await tester.testTextInput.receiveAction(action);
    await frame();
  }

  /// Takes the pointer off screen and lets the remaining timers run out,
  /// so the test ends clean.
  Future<void> finish() async {
    stop();
    if (_pointerShown && !touch) {
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
