import 'package:flutter/painting.dart';

import '../../../../ui/tokens.dart';

// The marks the waveform meter draws over the envelope: the A-B loop and
// the chapter starts. Each takes pixel positions already mapped by the
// meter's viewport and the palette to draw with.

/// The A-B loop: the span between [xa] and [xb] washed once both are set,
/// and each point as a full-height line in the text tone with a labelled
/// pill flag hanging from the ruler, laid out by [abLoopFlags]. A null or
/// off-screen point is not drawn.
void paintAbLoop(
  Canvas canvas,
  Size size, {
  required double? xa,
  required double? xb,
  required double top,
  required Palette palette,
}) {
  final w = size.width;
  final h = size.height;
  final loop = palette.fg;
  if (xa != null && xb != null && xb > xa) {
    final l = xa.clamp(0.0, w);
    final r = xb.clamp(0.0, w);
    if (r > l) {
      canvas.drawRect(
        Rect.fromLTRB(l, top, r, h),
        Paint()..color = palette.accentWash,
      );
    }
  }

  for (final x in [xa, xb]) {
    if (x == null || x < 0 || x > w) continue;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, top, 2, h - top),
      Paint()..color = loop,
    );
  }

  TextPainter label(String text) => TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: Tokens.mono,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: palette.onAccent,
      ),
    ),
  )..layout();

  final painters = <String, TextPainter>{};
  TextPainter painter(String text) =>
      painters.putIfAbsent(text, () => label(text));
  final flags = abLoopFlags(
    xa: xa,
    xb: xb,
    width: w,
    top: top + 1,
    measure: (text) {
      final tp = painter(text);
      return Size(tp.width + 10, tp.height + 4);
    },
  );
  for (final (text, box) in flags) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(box.height / 2)),
      Paint()..color = loop,
    );
    painter(text).paint(canvas, box.topLeft + const Offset(5, 2));
  }
  for (final tp in painters.values) {
    tp.dispose();
  }
}

/// Where the A-B loop's pill flags hang from the ruler, [top] down, for
/// the points at [xa] and [xb] on a meter [width] wide; [measure] gives a
/// flag's size for its label. Each flag hangs outward from the loop (the
/// earlier point's to the left of its line, the later one's to the right)
/// and turns inward at the meter's edge. Two flags that would still
/// touch merge into one "A-B" flag between the points, so neither hides
/// the other. A null or off-screen point has no flag.
List<(String, Rect)> abLoopFlags({
  required double? xa,
  required double? xb,
  required double width,
  required double top,
  required Size Function(String label) measure,
}) {
  bool shown(double? x) => x != null && x >= 0 && x <= width;

  /// The flag of [label] at [x]: on the [left] of its line when it fits,
  /// else on the other side.
  Rect flag(String label, double x, {required bool left}) {
    final size = measure(label);
    var bx = left ? x - 1 - size.width : x + 1;
    if (bx < 0) bx = x + 1;
    if (bx + size.width > width) bx = x - 1 - size.width;
    return Rect.fromLTWH(bx, top, size.width, size.height);
  }

  final a = shown(xa) ? xa : null;
  final b = shown(xb) ? xb : null;
  if (a == null && b == null) return const [];
  if (a == null) return [('B', flag('B', b!, left: false))];
  if (b == null) return [('A', flag('A', a, left: true))];

  final flagA = flag('A', a, left: a <= b);
  final flagB = flag('B', b, left: b < a);
  // Kept a little apart: flags that touch would read as one shape.
  if (!flagA.inflate(Tokens.s4 / 2).overlaps(flagB.inflate(Tokens.s4 / 2))) {
    return [('A', flagA), ('B', flagB)];
  }
  final size = measure('A-B');
  final centre = (a + b) / 2;
  final left = (centre - size.width / 2).clamp(
    0.0,
    (width - size.width).clamp(0.0, double.infinity),
  );
  return [('A-B', Rect.fromLTWH(left, top, size.width, size.height))];
}

/// The chapter starts at [xs]: a notch in the ruler (whose bottom edge is
/// at [rulerBottom]) and a faint dashed line down through the envelope.
/// The [current] chapter's notch is drawn in the accent.
void paintChapterTicks(
  Canvas canvas,
  Size size, {
  required List<double> xs,
  required int? current,
  required double rulerBottom,
  required Palette palette,
}) {
  final w = size.width;
  final h = size.height;
  final line = Paint()
    ..color = palette.fgDim.withValues(alpha: 0.35)
    ..strokeWidth = 1;
  for (var i = 0; i < xs.length; i++) {
    final x = xs[i];
    if (x < 0 || x > w) continue;
    for (var y = rulerBottom; y < h; y += 6) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 3).clamp(0, h)), line);
    }
    final notch = Path()
      ..moveTo(x - 4, rulerBottom)
      ..lineTo(x + 4, rulerBottom)
      ..lineTo(x, rulerBottom - 6)
      ..close();
    canvas.drawPath(
      notch,
      Paint()..color = i == current ? palette.accent : palette.fgDim,
    );
  }
}
