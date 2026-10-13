import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../ui/tokens.dart';
import '../../../../util/duration_format.dart';
import 'waveform_marks.dart';
import 'waveform_viewport.dart';

/// The vertical extent of one waveform bar: [top] to [bottom] spans the
/// bin's min and max peaks, at least 1 px tall; [body] spans plus and minus
/// its RMS, inside the peaks, and is null without an RMS value. [lo] and
/// [hi] are in [-1, 1], [rms] in [0, 1]; [maxHalf] is the pixel height of
/// full scale above [centreY].
@visibleForTesting
({double top, double bottom, ({double top, double bottom})? body}) waveBar({
  required double lo,
  required double hi,
  required double? rms,
  required double centreY,
  required double maxHalf,
}) {
  final top = centreY - hi.clamp(-1.0, 1.0) * maxHalf;
  final bottomRaw = centreY - lo.clamp(-1.0, 1.0) * maxHalf;
  final bottom = bottomRaw < top + 1 ? top + 1 : bottomRaw;
  if (rms == null || rms.isNaN) return (top: top, bottom: bottom, body: null);
  final r = rms.clamp(0.0, 1.0) * maxHalf;
  var bodyTop = (centreY - r).clamp(top, bottom);
  var bodyBottom = (centreY + r).clamp(top, bottom);
  // Keep a visible core for quiet bins.
  if (bodyBottom - bodyTop < 1) {
    bodyTop = (centreY - 0.5).clamp(top, bottom - 1);
    bodyBottom = bodyTop + 1;
  }
  return (top: top, bottom: bottom, body: (top: bodyTop, bottom: bodyBottom));
}

/// Paints the waveform meter: the time ruler, the envelope (played part in
/// the accent), the chapter and A-B loop marks, the hover cursor and the
/// playhead, all in [palette].
class WaveformPainter extends CustomPainter {
  WaveformPainter({
    required this.view,
    required this.position,
    required this.rulerHeight,
    required this.palette,
    this.hoverX,
    this.abA,
    this.abB,
    this.chapters = const [],
    this.currentChapter,
  });

  final WaveformViewport view;
  final Duration position;
  final double rulerHeight;
  final Palette palette;

  /// The pointer's x over the meter, for the preview cursor.
  final double? hoverX;

  /// The A-B loop points, in absolute media time.
  final Duration? abA;
  final Duration? abB;

  final List<Chapter> chapters;
  final int? currentChapter;

  static double _niceStep(double visibleSecs) {
    const steps = <double>[1, 2, 5, 10, 15, 20, 30, 60, 120, 300, 600];
    final target = visibleSecs / 5;
    for (final s in steps) {
      if (s >= target) return s;
    }
    return steps.last;
  }

  TextPainter _label(String text, Color color, {double size = 9.5}) =>
      TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: Tokens.mono,
            fontSize: size,
            color: color,
          ),
        ),
      )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0 || view.visibleSecs <= 0) return;

    final pxPerSec = w / view.visibleSecs;
    final tLeft = view.viewStartAbs;
    final tRight = tLeft + view.visibleSecs;
    final waveH = h - rulerHeight;
    final centreY = rulerHeight + waveH / 2;

    _paintRuler(canvas, w, tLeft, tRight, pxPerSec);
    canvas.drawLine(
      Offset(0, centreY),
      Offset(w, centreY),
      Paint()
        ..color = palette.line
        ..strokeWidth = 1,
    );
    _paintEnvelope(canvas, w, tLeft, tRight, pxPerSec, waveH, centreY);

    if (chapters.isNotEmpty) {
      paintChapterTicks(
        canvas,
        size,
        xs: [for (final c in chapters) view.xOf(c.time, w)],
        current: currentChapter,
        rulerBottom: rulerHeight,
        palette: palette,
      );
    }
    paintAbLoop(
      canvas,
      size,
      xa: abA == null ? null : view.xOf(abA!, w),
      xb: abB == null ? null : view.xOf(abB!, w),
      top: rulerHeight,
      palette: palette,
    );
    _paintHover(canvas, w, h, tLeft, pxPerSec);

    // The playhead: one line through the ruler, capped by a pip.
    final playheadX = view.xOf(position, w);
    if (playheadX >= 0 && playheadX <= w) {
      final ph = Paint()..color = palette.accent;
      canvas.drawRect(Rect.fromLTWH(playheadX - 0.75, 0, 1.5, h), ph);
      final pip = Path()
        ..moveTo(playheadX - 5, 0)
        ..lineTo(playheadX + 5, 0)
        ..lineTo(playheadX, 9)
        ..close();
      canvas.drawPath(pip, ph);
    }
  }

  void _paintRuler(
    Canvas canvas,
    double w,
    double tLeft,
    double tRight,
    double pxPerSec,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, rulerHeight),
      Paint()..color = palette.surface2,
    );
    canvas.drawLine(
      Offset(0, rulerHeight - 0.5),
      Offset(w, rulerHeight - 0.5),
      Paint()
        ..color = palette.line
        ..strokeWidth = 1,
    );
    final start = view.originSecs;
    final end = start + view.timelineSecs;
    final tick = Paint()
      ..color = palette.fgFaint
      ..strokeWidth = 1;
    final step = _niceStep(view.visibleSecs);
    for (
      var t = (tLeft / step).floorToDouble() * step;
      t <= tRight;
      t += step
    ) {
      if (t < start || t > end) continue;
      final x = (t - tLeft) * pxPerSec;
      canvas.drawLine(Offset(x, rulerHeight - 5), Offset(x, rulerHeight), tick);
      final tp = _label(
        formatDuration(Duration(microseconds: (t * 1e6).round())),
        palette.fgDim,
      );
      var dx = x - tp.width / 2;
      if (dx + tp.width > w - 1) dx = w - 1 - tp.width;
      if (dx < 1) dx = 1;
      tp
        ..paint(canvas, Offset(dx, 2))
        ..dispose();
    }
  }

  void _paintEnvelope(
    Canvas canvas,
    double w,
    double tLeft,
    double tRight,
    double pxPerSec,
    double waveH,
    double centreY,
  ) {
    final wv = view.wave;
    if (wv == null || wv.bins == 0 || wv.duration <= Duration.zero) return;
    final played = Paint()..color = palette.accent;
    final upcoming = Paint()..color = palette.fgFaint.withValues(alpha: 0.55);
    // Bins not yet covered (a progressive envelope ahead of the playhead,
    // or a region a seek skipped) are a faint baseline, not a flat spike.
    final unloaded = Paint()..color = palette.line;
    // With RMS the RMS is the solid body and the min and max peaks a
    // lighter outline around it, which keeps loud, limited masters
    // readable. Without it the peaks are the body.
    final playedPeak = Paint()..color = palette.accent.withValues(alpha: 0.35);
    final upcomingPeak = Paint()..color = palette.fg.withValues(alpha: 0.08);
    final posSecs = position.inMicroseconds / 1e6;
    final rms = wv.rms;
    // Bin i sits at absolute media time `start + i * binSecs`: 0 based for a
    // track, the oldest cached moment for a live window.
    final waveStart = wv.start.inMicroseconds / 1e6;
    final binSecs = wv.duration.inMicroseconds / 1e6 / wv.bins;
    final maxHalf = waveH / 2 - 3;
    final barW = (pxPerSec * binSecs * 0.7).clamp(0.6, 6.0);
    var i = ((tLeft - waveStart) / binSecs).floor();
    if (i < 0) i = 0;
    for (; i < wv.bins; i++) {
      final t = waveStart + (i + 0.5) * binSecs;
      if (t > tRight) break;
      final x = (t - tLeft) * pxPerSec;
      if (x < -barW || x > w + barW) continue;
      final covered = i >= wv.filled.length || wv.filled[i] != 0;
      final bar = waveBar(
        lo: wv.min[i],
        hi: wv.max[i],
        rms: covered && rms != null && i < rms.length ? rms[i] : null,
        centreY: centreY,
        maxHalf: maxHalf,
      );
      final isPlayed = t <= posSecs;
      final peaks = Rect.fromLTRB(x, bar.top, x + barW, bar.bottom);
      if (!covered) {
        canvas.drawRect(peaks, unloaded);
      } else if (bar.body == null) {
        canvas.drawRect(peaks, isPlayed ? played : upcoming);
      } else {
        canvas.drawRect(peaks, isPlayed ? playedPeak : upcomingPeak);
        canvas.drawRect(
          Rect.fromLTRB(x, bar.body!.top, x + barW, bar.body!.bottom),
          isPlayed ? played : upcoming,
        );
      }
    }
  }

  void _paintHover(
    Canvas canvas,
    double w,
    double h,
    double tLeft,
    double pxPerSec,
  ) {
    final hx = hoverX;
    if (hx == null || hx < 0 || hx > w) return;
    canvas.drawRect(
      Rect.fromLTWH(hx - 0.5, rulerHeight, 1, h - rulerHeight),
      Paint()..color = palette.fg.withValues(alpha: 0.28),
    );
    final t = (tLeft + hx / pxPerSec).clamp(
      view.originSecs,
      view.originSecs + view.timelineSecs,
    );
    final tp = _label(
      formatDuration(Duration(microseconds: (t * 1e6).round())),
      palette.fg,
    );
    var bx = hx + 4;
    if (bx + tp.width + 6 > w) bx = hx - 4 - tp.width - 6;
    final bubble = Rect.fromLTWH(
      bx,
      rulerHeight + 3,
      tp.width + 6,
      tp.height + 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, const Radius.circular(3)),
      Paint()..color = palette.surface3,
    );
    tp
      ..paint(canvas, Offset(bx + 3, rulerHeight + 4))
      ..dispose();
  }

  @override
  bool shouldRepaint(WaveformPainter old) =>
      old.view != view ||
      old.position != position ||
      old.rulerHeight != rulerHeight ||
      old.palette != palette ||
      old.hoverX != hoverX ||
      old.abA != abA ||
      old.abB != abB ||
      !listEquals(old.chapters, chapters) ||
      old.currentChapter != currentChapter;
}
