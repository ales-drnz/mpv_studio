import 'dart:math' as math;

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

/// The times, in seconds, of the ruler's ticks in a view from [viewStart]
/// to [viewEnd]: every multiple of [step] inside both the view and the
/// timeline ([start] to [end]). A tick just before the view is left out,
/// not drawn with its label pushed in from the edge over the next one.
@visibleForTesting
List<double> rulerTicks({
  required double viewStart,
  required double viewEnd,
  required double step,
  required double start,
  required double end,
}) {
  if (step <= 0 || !viewStart.isFinite || !viewEnd.isFinite) return const [];
  // A hair of tolerance, so a tick on an edge survives rounding.
  const eps = 1e-6;
  final from = viewStart < start ? start : viewStart;
  final to = viewEnd > end ? end : viewEnd;
  return [
    for (
      var t = ((from - eps) / step).ceilToDouble() * step;
      t <= to + eps;
      t += step
    )
      t,
  ];
}

/// Paints the waveform meter: the time ruler, the envelope (played part in
/// the accent, the rest in the secondary tone, each a solid RMS body in a
/// lighter step of its peaks), the chapter and A-B loop marks, the hover
/// cursor and the playhead, all in [palette].
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
    this.cached = const [],
    this.scaler = TextScaler.noScaling,
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

  /// What the engine holds in its cache, marked along the ruler's foot;
  /// empty for a source that is all there (a local file).
  final List<CacheRange> cached;

  /// The text scale of the ruler's labels.
  final TextScaler scaler;

  /// The height of the cache band along the ruler's foot.
  static const double cacheBand = 3;

  /// Half the playhead pip's width.
  static const double _pipHalf = 5;

  /// A round step between ruler labels about every 120 px of [width].
  static double _niceStep(double visibleSecs, double width) {
    const steps = <double>[1, 2, 5, 10, 15, 20, 30, 60, 120, 300, 600];
    final target = visibleSecs * 120 / math.max(width, 120);
    for (final s in steps) {
      if (s >= target) return s;
    }
    return steps.last;
  }

  TextPainter _label(String text, Color color) => TextPainter(
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: Tokens.mono,
        fontSize: Tokens.chartLabelSize,
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

    final playheadX = view.xOf(position, w);
    _paintRuler(canvas, w, tLeft, tRight, pxPerSec, playheadX);
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
    if (playheadX >= 0 && playheadX <= w) {
      final ph = Paint()..color = palette.accent;
      canvas.drawRect(Rect.fromLTWH(playheadX - 0.75, 0, 1.5, h), ph);
      final pip = Path()
        ..moveTo(playheadX - _pipHalf, 0)
        ..lineTo(playheadX + _pipHalf, 0)
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
    double playheadX,
  ) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, rulerHeight),
      Paint()..color = palette.surface3,
    );
    // What the cache holds: a band along the ruler's foot.
    final band = Paint()..color = palette.accentDim;
    for (final r in cached) {
      final x0 = view.xOf(r.start, w).clamp(0.0, w);
      final x1 = view.xOf(r.end, w).clamp(0.0, w);
      if (x1 - x0 < 1) continue;
      canvas.drawRect(
        Rect.fromLTRB(x0, rulerHeight - cacheBand, x1, rulerHeight),
        band,
      );
    }
    final start = view.originSecs;
    final end = start + view.timelineSecs;
    final tick = Paint()
      ..color = palette.fgFaint
      ..strokeWidth = 1;
    final step = _niceStep(view.visibleSecs, w);
    for (final t in rulerTicks(
      viewStart: tLeft,
      viewEnd: tRight,
      step: step,
      start: start,
      end: end,
    )) {
      final x = (t - tLeft) * pxPerSec;
      canvas.drawLine(Offset(x, rulerHeight - 4), Offset(x, rulerHeight), tick);
      final tp = _label(
        formatDuration(Duration(microseconds: (t * 1e6).round())),
        palette.fgDim,
      );
      // Clear of the card's rounded corners at both ends.
      var dx = x - tp.width / 2;
      if (dx + tp.width > w - Tokens.s16) dx = w - Tokens.s16 - tp.width;
      if (dx < Tokens.s16) dx = Tokens.s16;
      // A label the playhead's pip would cover is left out.
      final covered =
          playheadX >= dx - _pipHalf && playheadX <= dx + tp.width + _pipHalf;
      if (!covered) tp.paint(canvas, Offset(dx, 3));
      tp.dispose();
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
    // The ring grey sits close to white: in dark it steps down a little
    // further so the played part stands apart (still 4:1 on the card);
    // light's secondary step is already the 3:1 minimum on white.
    final upcoming = Paint()
      ..color = palette.accentDim.withValues(alpha: palette.isDark ? 0.7 : 1);
    // Bins not yet covered (a progressive envelope ahead of the playhead,
    // or a region a seek skipped) are a faint baseline, not a flat spike.
    final unloaded = Paint()..color = palette.line;
    // With RMS the RMS is the solid body and the min and max peaks a
    // lighter outline around it, which keeps loud, limited masters
    // readable. Without it the peaks are the body.
    final playedPeak = Paint()..color = palette.accent.withValues(alpha: 0.45);
    final upcomingPeak = Paint()
      ..color = palette.accentDim.withValues(alpha: 0.35);
    final posSecs = position.inMicroseconds / 1e6;
    final rms = wv.rms;
    // Bin i sits at absolute media time `start + i * binSecs`: 0 based for a
    // track, the oldest cached moment for a live window.
    final waveStart = wv.start.inMicroseconds / 1e6;
    final binSecs = wv.duration.inMicroseconds / 1e6 / wv.bins;
    final maxHalf = waveH / 2 - 3;
    void paintBar(
      double x,
      double width,
      double lo,
      double hi,
      double? r,
      bool covered,
      bool isPlayed,
    ) {
      final bar = waveBar(
        lo: lo,
        hi: hi,
        rms: covered ? r : null,
        centreY: centreY,
        maxHalf: maxHalf,
      );
      final peaks = Rect.fromLTRB(x, bar.top, x + width, bar.bottom);
      if (!covered) {
        canvas.drawRect(peaks, unloaded);
      } else if (bar.body == null) {
        canvas.drawRect(peaks, isPlayed ? played : upcoming);
      } else {
        canvas.drawRect(peaks, isPlayed ? playedPeak : upcomingPeak);
        canvas.drawRect(
          Rect.fromLTRB(x, bar.body!.top, x + width, bar.body!.bottom),
          isPlayed ? played : upcoming,
        );
      }
    }

    var i = ((tLeft - waveStart) / binSecs).floor();
    if (i < 0) i = 0;
    final binPx = pxPerSec * binSecs;
    if (binPx < 1.5) {
      // More bins than pixels: each pixel column draws the extremes of
      // the bins that fall in it. Bars narrower than a pixel at
      // fractional positions beat against the pixel grid (moire).
      int? col;
      var lo = 0.0, hi = 0.0;
      double? r;
      var covered = false;
      void flush() {
        final c = col;
        if (c == null) return;
        final colT = tLeft + (c + 0.5) / pxPerSec;
        paintBar(c.toDouble(), 1, lo, hi, r, covered, colT <= posSecs);
      }

      for (; i < wv.bins; i++) {
        final t = waveStart + (i + 0.5) * binSecs;
        if (t > tRight) break;
        final x = ((t - tLeft) * pxPerSec).floor();
        if (x < 0 || x >= w) continue;
        final binCovered = i >= wv.filled.length || wv.filled[i] != 0;
        final binRms = binCovered && rms != null && i < rms.length
            ? rms[i]
            : null;
        if (x != col) {
          flush();
          col = x;
          lo = wv.min[i];
          hi = wv.max[i];
          r = binRms;
          covered = binCovered;
        } else {
          lo = math.min(lo, wv.min[i]);
          hi = math.max(hi, wv.max[i]);
          if (binRms != null) r = r == null ? binRms : math.max(r, binRms);
          covered = covered || binCovered;
        }
      }
      flush();
      return;
    }
    // Each bar spans its bin's own pixel edges, rounded, so neighbours
    // tile without beating; wide bins keep a gap between bars.
    final gap = binPx >= 3 ? math.max(1.0, (binPx * 0.3).roundToDouble()) : 0.0;
    for (; i < wv.bins; i++) {
      final t = waveStart + (i + 0.5) * binSecs;
      if (t > tRight) break;
      final x0 = ((waveStart + i * binSecs - tLeft) * pxPerSec).roundToDouble();
      final x1 = ((waveStart + (i + 1) * binSecs - tLeft) * pxPerSec)
          .roundToDouble();
      if (x1 < 0 || x0 > w) continue;
      final covered = i >= wv.filled.length || wv.filled[i] != 0;
      paintBar(
        x0,
        math.max(1.0, x1 - x0 - gap),
        wv.min[i],
        wv.max[i],
        covered && rms != null && i < rms.length ? rms[i] : null,
        covered,
        t <= posSecs,
      );
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
    // A pill beside the cursor, flipped to its left at the right edge.
    final bw = tp.width + 12;
    var bx = hx + 4;
    if (bx + bw > w) bx = hx - 4 - bw;
    final bubble = Rect.fromLTWH(bx, rulerHeight + 4, bw, tp.height + 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bubble, Radius.circular(bubble.height / 2)),
      Paint()..color = palette.surface3,
    );
    tp
      ..paint(canvas, Offset(bx + 6, rulerHeight + 6))
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
      old.currentChapter != currentChapter ||
      !listEquals(old.cached, cached) ||
      old.scaler != scaler;
}
