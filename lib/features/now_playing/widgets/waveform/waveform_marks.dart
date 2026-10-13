import 'package:flutter/painting.dart';

import '../../../../ui/tokens.dart';

// The marks the waveform meter draws over the envelope: the A-B loop and
// the chapter starts. Each takes pixel positions already mapped by the
// meter's viewport and the palette to draw with.

/// The A-B loop: the span between [xa] and [xb] washed once both are set,
/// and each point as a full-height line in the text tone with a labelled
/// pill flag hanging from the ruler. A null or off-screen point is not
/// drawn.
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

  void marker(double? x, String label) {
    if (x == null || x < 0 || x > w) return;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, top, 2, h - top),
      Paint()..color = loop,
    );
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: Tokens.mono,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: palette.onAccent,
        ),
      ),
    )..layout();
    final boxW = tp.width + 10;
    final boxH = tp.height + 4;
    // A flag to the right of its line, or to the left at the right edge;
    // B flags the other way first, so A and B close together stay apart.
    final rightFirst = label == 'A';
    var bx = rightFirst ? x + 1 : x - 1 - boxW;
    if (bx + boxW > w) bx = x - 1 - boxW;
    if (bx < 0) bx = x + 1;
    final box = Rect.fromLTWH(bx, top + 1, boxW, boxH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(boxH / 2)),
      Paint()..color = loop,
    );
    tp
      ..paint(canvas, Offset(bx + 5, top + 3))
      ..dispose();
  }

  marker(xa, 'A');
  marker(xb, 'B');
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
