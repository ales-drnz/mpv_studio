import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'motion.dart';

/// The shapes the drawn cursor takes, after the system cursor the app
/// asks for at the pointer.
enum CursorShape { arrow, hand, crosshair, text, resizeRow, resizeColumn }

/// The [CursorShape] for a system cursor kind, as Flutter names it
/// (`SystemMouseCursor.kind`).
CursorShape cursorShapeFor(String? kind) => switch (kind) {
  'click' => CursorShape.hand,
  'precise' => CursorShape.crosshair,
  'text' || 'verticalText' => CursorShape.text,
  'resizeRow' ||
  'resizeUpDown' ||
  'resizeUp' ||
  'resizeDown' => CursorShape.resizeRow,
  'resizeColumn' ||
  'resizeLeftRight' ||
  'resizeLeft' ||
  'resizeRight' => CursorShape.resizeColumn,
  _ => CursorShape.arrow,
};

/// A click's ring, expanding and fading from where it happened.
class ClickRing {
  const ClickRing(this.center, this.start);

  final Offset center;
  final Duration start;

  static const Duration life = Duration(milliseconds: 420);
}

/// A key shown on screen while it is pressed, for shortcuts the viewer
/// cannot otherwise see.
class KeyCap {
  const KeyCap(this.label, this.start, this.hold);

  final String label;
  final Duration start;
  final Duration hold;

  static const Duration fadeIn = Duration(milliseconds: 120);
  static const Duration fadeOut = Duration(milliseconds: 220);

  Duration get end => start + hold + fadeOut;
}

/// Everything the overlay draws in one frame.
class OverlayFrame {
  const OverlayFrame({
    required this.time,
    this.pointer,
    this.shape = CursorShape.arrow,
    this.press = 0,
    this.rings = const [],
    this.keys = const [],
  });

  /// The scene time of the frame.
  final Duration time;

  /// Where the pointer is, or null with no pointer on screen.
  final Offset? pointer;
  final CursorShape shape;

  /// How far the button is down: 0 up, 1 fully pressed (the cursor
  /// shrinks a little).
  final double press;
  final List<ClickRing> rings;
  final List<KeyCap> keys;
}

/// Draws the cursor, click rings and key caps of [frame] over [child],
/// without taking any pointer input. Lives inside the captured boundary,
/// above the app's own overlays (menus, dialogs, tooltips).
class ShowcaseOverlay extends StatelessWidget {
  const ShowcaseOverlay({super.key, required this.frame, required this.child});

  final ValueListenable<OverlayFrame> frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(child: CustomPaint(painter: _OverlayPainter(frame))),
        ],
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter(this.frame) : super(repaint: frame);

  final ValueListenable<OverlayFrame> frame;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame.value;
    for (final ring in f.rings) {
      _ring(canvas, ring, f.time);
    }
    for (final key in f.keys) {
      _keyCap(canvas, size, key, f.time);
    }
    final p = f.pointer;
    if (p != null) paintCursor(canvas, p, f.shape, press: f.press);
  }

  void _ring(Canvas canvas, ClickRing ring, Duration now) {
    final t = (now - ring.start).inMicroseconds / ClickRing.life.inMicroseconds;
    if (t < 0 || t > 1) return;
    final r = 5 + 19 * easeOut(t);
    final fade = 1 - easeOut(t);
    canvas.drawCircle(
      ring.center,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.10 * fade),
    );
    canvas.drawCircle(
      ring.center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.75 * fade),
    );
  }

  void _keyCap(Canvas canvas, Size size, KeyCap key, Duration now) {
    final since = now - key.start;
    if (since.isNegative || now > key.end) return;
    final double alpha;
    if (since < KeyCap.fadeIn) {
      alpha = easeOut(since.inMicroseconds / KeyCap.fadeIn.inMicroseconds);
    } else if (since < key.hold) {
      alpha = 1;
    } else {
      final out = (since - key.hold).inMicroseconds;
      alpha = 1 - easeOut(out / KeyCap.fadeOut.inMicroseconds);
    }
    final text = TextPainter(
      text: TextSpan(
        text: key.label,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = math.max(48.0, text.width + 32);
    const h = 48.0;
    // Top right, clear of the page title and of the toasts at the foot.
    final rect = Rect.fromLTWH(size.width - w - 28, 24, w, h);
    final cap = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      cap.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.35 * alpha),
    );
    canvas.drawRRect(
      cap,
      Paint()..color = const Color(0xFF2E3238).withValues(alpha: alpha),
    );
    canvas.drawRRect(
      cap,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.28 * alpha),
    );
    text.paint(canvas, rect.center - Offset(text.width / 2, text.height / 2));
    text.dispose();
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.frame != frame;
}

/// Paints a cursor of [shape] with its hot spot at [at]. [press] (0 to 1)
/// shrinks it a little, as a button goes down.
void paintCursor(
  Canvas canvas,
  Offset at,
  CursorShape shape, {
  double press = 0,
}) {
  final scale = 1.0 - 0.14 * press.clamp(0.0, 1.0);
  canvas.save();
  canvas.translate(at.dx, at.dy);
  canvas.scale(scale);
  switch (shape) {
    case CursorShape.arrow:
      _filled(canvas, _arrow, fill: Colors.black, edge: Colors.white);
    case CursorShape.hand:
      _filled(canvas, _hand, fill: Colors.white, edge: Colors.black);
    case CursorShape.crosshair:
      _crosshair(canvas);
    case CursorShape.text:
      _stroked(canvas, _ibeam);
    case CursorShape.resizeRow:
      _filled(canvas, _resize, fill: Colors.black, edge: Colors.white);
    case CursorShape.resizeColumn:
      canvas.rotate(math.pi / 2);
      _filled(canvas, _resize, fill: Colors.black, edge: Colors.white);
  }
  canvas.restore();
}

void _filled(
  Canvas canvas,
  Path path, {
  required Color fill,
  required Color edge,
}) {
  canvas.drawPath(
    path.shift(const Offset(0.8, 1.6)),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
  );
  canvas.drawPath(path, Paint()..color = fill);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeJoin = StrokeJoin.round
      ..color = edge,
  );
}

void _stroked(Canvas canvas, Path path) {
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..color = Colors.white,
  );
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.black,
  );
}

void _crosshair(Canvas canvas) {
  final path = Path()
    ..moveTo(-10, 0)
    ..lineTo(-3, 0)
    ..moveTo(3, 0)
    ..lineTo(10, 0)
    ..moveTo(0, -10)
    ..lineTo(0, -3)
    ..moveTo(0, 3)
    ..lineTo(0, 10);
  _stroked(canvas, path);
}

/// The classic arrow, its tip on the hot spot, a little larger than a
/// 1x system cursor so it reads in a scaled-down GIF.
final Path _arrow = () {
  const s = 1.18;
  return Path()
    ..moveTo(0, 0)
    ..lineTo(0, 17.5 * s)
    ..lineTo(4.2 * s, 13.6 * s)
    ..lineTo(7.0 * s, 20.0 * s)
    ..lineTo(9.8 * s, 18.8 * s)
    ..lineTo(7.1 * s, 12.6 * s)
    ..lineTo(12.6 * s, 12.6 * s)
    ..close();
}();

/// A pointing hand, the index fingertip on the hot spot.
final Path _hand = () {
  Path rr(double l, double t, double w, double h, double r) =>
      Path()..addRRect(RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(r)));
  var hand = rr(-2.1, 0, 4.4, 13, 2.2); // index finger
  for (final part in [
    rr(1.9, 6.4, 4.2, 9, 2.1), // middle finger
    rr(5.8, 7.6, 4.1, 8, 2.05), // ring finger
    rr(9.6, 9.0, 3.8, 7, 1.9), // little finger
    rr(-2.1, 9.5, 15.5, 11.5, 4.6), // palm
  ]) {
    hand = Path.combine(PathOperation.union, hand, part);
  }
  final thumb = Path()
    ..addRRect(RRect.fromLTRBR(-3, -2.2, 6, 2.2, const Radius.circular(2.2)));
  final turned = thumb.transform(
    (Matrix4.identity()
          ..translateByDouble(-3.4, 12.6, 0, 1)
          ..rotateZ(0.9))
        .storage,
  );
  hand = Path.combine(PathOperation.union, hand, turned);
  return hand.transform(Matrix4.diagonal3Values(1.12, 1.12, 1).storage);
}();

final Path _ibeam = Path()
  ..moveTo(-3.5, -9)
  ..lineTo(-1, -9)
  ..lineTo(0, -8)
  ..lineTo(1, -9)
  ..lineTo(3.5, -9)
  ..moveTo(0, -8)
  ..lineTo(0, 8)
  ..moveTo(-3.5, 9)
  ..lineTo(-1, 9)
  ..lineTo(0, 8)
  ..lineTo(1, 9)
  ..lineTo(3.5, 9);

/// A vertical double arrow centred on the hot spot.
final Path _resize = Path()
  ..moveTo(0, -11)
  ..lineTo(5, -5.5)
  ..lineTo(1.6, -5.5)
  ..lineTo(1.6, 5.5)
  ..lineTo(5, 5.5)
  ..lineTo(0, 11)
  ..lineTo(-5, 5.5)
  ..lineTo(-1.6, 5.5)
  ..lineTo(-1.6, -5.5)
  ..lineTo(-5, -5.5)
  ..close();
