import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import '../engine_format.dart';
import '../engine_snapshot.dart';

/// Where the cache sits on the time axis, in seconds.
class CacheGeometry {
  final double axisStart;
  final double axisEnd;
  final double position;
  final List<(double, double)> ranges;

  /// The range holding the playhead, if any.
  final (double, double)? current;

  /// `CacheSettings.secs`, or `null` when it is too large to draw.
  final Duration? cacheSecs;

  const CacheGeometry({
    required this.axisStart,
    required this.axisEnd,
    required this.position,
    required this.ranges,
    required this.current,
    required this.cacheSecs,
  });

  Duration get behind =>
      current == null ? Duration.zero : _d(math.max(0, position - current!.$1));

  Duration get ahead =>
      current == null ? Duration.zero : _d(math.max(0, current!.$2 - position));

  static Duration _d(num s) => Duration(microseconds: (s * 1e6).round());

  factory CacheGeometry.of(PlayerState s) {
    final pos = secondsOf(s.position);
    final ranges = [
      for (final r in s.demuxerCacheState.seekableRanges)
        (secondsOf(r.start), secondsOf(r.end)),
    ];
    (double, double)? current;
    for (final r in ranges) {
      if (pos >= r.$1 - 0.25 && pos <= r.$2 + 0.25) current = r;
    }
    final duration = secondsOf(s.duration);
    double start, end;
    if (duration > 0) {
      start = 0;
      end = duration;
    } else {
      // Live: frame the cached window and the playhead, with headroom.
      start = ranges.isEmpty ? pos : ranges.map((r) => r.$1).reduce(math.min);
      end = ranges.isEmpty ? pos : ranges.map((r) => r.$2).reduce(math.max);
      start = math.min(start, pos);
      end = math.max(end, pos);
      final span = math.max(end - start, 10.0);
      end = start + span * 1.15;
    }
    final secs = s.cache.secs;
    return CacheGeometry(
      axisStart: start,
      axisEnd: math.max(end, start + 1),
      position: pos,
      ranges: ranges,
      current: current,
      cacheSecs: secs > const Duration(hours: 24) ? null : secs,
    );
  }
}

/// The cache bar: waveform bars over the time axis, played in the accent,
/// cached ahead in the dim accent and not cached in the inactive tone,
/// over a wash marking the read part; the playhead, brackets for behind
/// and ahead, the cache-secs limit.
class CacheBarPainter extends CustomPainter {
  final CacheGeometry geometry;
  final WaveformData? waveform;

  CacheBarPainter({required this.geometry, this.waveform});

  static const double _top = 18;
  static const double _barH = 44;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometry;
    final w = size.width;
    double x(double t) =>
        ((t - g.axisStart) / (g.axisEnd - g.axisStart)).clamp(0.0, 1.0) * w;

    final bar = Rect.fromLTWH(0, _top, w, _barH);
    final rr = RRect.fromRectAndRadius(bar, const Radius.circular(Tokens.rMd));
    canvas.save();
    canvas.clipRRect(rr);
    canvas.drawRect(bar, Paint()..color = Tokens.surface3);

    // The part read so far.
    for (final r in g.ranges) {
      canvas.drawRect(
        Rect.fromLTRB(x(r.$1), _top, x(r.$2), _top + _barH),
        Paint()..color = Tokens.accentWash,
      );
    }

    // Waveform bars: the real envelope where it is known, a quiet
    // placeholder pattern elsewhere.
    const step = 4.0;
    final mid = _top + _barH / 2;
    final barPaint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var bx = step / 2; bx < w; bx += step) {
      final t = g.axisStart + bx / w * (g.axisEnd - g.axisStart);
      final amp = _amplitude(t, bx) * (_barH / 2 - 5);
      final inRead = g.ranges.any((r) => t >= r.$1 && t <= r.$2);
      final ahead = t >= g.position;
      barPaint.color = !inRead
          ? Tokens.surface4
          : ahead
          ? Tokens.accentDim
          : Tokens.accent;
      canvas.drawLine(
        Offset(bx, mid - math.max(amp, 1)),
        Offset(bx, mid + math.max(amp, 1)),
        barPaint,
      );
    }
    canvas.restore();

    // cache-secs limit, dashed, ahead of the playhead.
    final secs = g.cacheSecs;
    if (secs != null) {
      final t = g.position + secondsOf(secs);
      if (t < g.axisEnd) {
        final cx = x(t);
        _dashed(canvas, Offset(cx, _top - 4), Offset(cx, _top + _barH + 30));
        paintChartLabel(
          canvas,
          'cache duration',
          Offset(math.min(cx + 4, w - 60), _top + _barH + 32),
          Tokens.fgFaint,
        );
      }
    }

    // Playhead.
    final px = x(g.position);
    final head = Paint()
      ..color = Tokens.accent
      ..strokeWidth = 2;
    canvas.drawLine(Offset(px, _top - 2), Offset(px, _top + _barH + 4), head);
    canvas.drawPath(
      Path()
        ..moveTo(px - 5, _top - 8)
        ..lineTo(px + 5, _top - 8)
        ..lineTo(px, _top - 2)
        ..close(),
      Paint()..color = Tokens.accent,
    );
    paintChartLabel(
      canvas,
      'playhead',
      Offset(px.clamp(24.0, math.max(24.0, w - 24)), 0),
      Tokens.accent,
      center: true,
    );

    // Brackets under the read part: behind and ahead, their labels
    // anchored at the playhead and pushed apart so they never overlap.
    final cur = g.current;
    if (cur != null) {
      final by = _top + _barH + 8;
      final l = x(cur.$1), r = x(cur.$2);
      final behind = 'behind ${EngineFormat.seconds(g.behind)}';
      final ahead = 'ahead ${EngineFormat.seconds(g.ahead)}';
      var behindEnd = px - 4;
      if (px - l > 6) {
        _bracket(canvas, l + 1, px - 3, by);
        behindEnd = math.max(behindEnd, chartLabelWidth(behind));
        paintChartLabel(
          canvas,
          behind,
          Offset(behindEnd, by + 8),
          Tokens.fgDim,
          end: true,
        );
      }
      final aheadStart = math.min(
        math.max(px + 4, px - l > 6 ? behindEnd + 8 : 0.0),
        w - chartLabelWidth(ahead),
      );
      if (r - px > 6 && aheadStart >= (px - l > 6 ? behindEnd + 8 : 0.0)) {
        _bracket(canvas, px + 3, r - 1, by);
        paintChartLabel(
          canvas,
          ahead,
          Offset(aheadStart, by + 8),
          Tokens.fgDim,
        );
      }
    }
  }

  double _amplitude(double t, double bx) {
    final wave = waveform;
    if (wave != null && wave.bins > 0 && wave.duration > Duration.zero) {
      final f = (t - secondsOf(wave.start)) / secondsOf(wave.duration);
      final i = (f * wave.bins).floor();
      if (i >= 0 && i < wave.bins && wave.filled[i] == 1) {
        final rms = wave.rms;
        final v = rms != null
            ? rms[i] * 1.6
            : math.max(wave.max[i].abs(), wave.min[i].abs());
        return v.clamp(0.04, 1.0);
      }
    }
    // Placeholder: a calm, deterministic pattern.
    final n = bx / 4;
    return 0.22 + 0.12 * math.sin(n * 0.9) * math.cos(n * 0.23);
  }

  void _bracket(Canvas canvas, double l, double r, double y) {
    final p = Paint()
      ..color = Tokens.line2
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
      Path()
        ..moveTo(l, y - 4)
        ..lineTo(l, y)
        ..lineTo(r, y)
        ..lineTo(r, y - 4),
      p,
    );
  }

  static void _dashed(Canvas canvas, Offset a, Offset b) {
    final p = Paint()
      ..color = Tokens.fgFaint
      ..strokeWidth = 1;
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (var d = 0.0; d < len; d += 6) {
      canvas.drawLine(a + dir * d, a + dir * math.min(d + 3, len), p);
    }
  }

  @override
  bool shouldRepaint(CacheBarPainter old) => true;
}

/// Cached-ahead seconds over the last [window] seconds, with the pause
/// threshold and the stretches paused for cache.
class CacheHistoryPainter extends CustomPainter {
  final List<CacheSample> samples;
  final double now;
  final double? pauseWait;
  final double window;

  CacheHistoryPainter({
    required this.samples,
    required this.now,
    this.pauseWait,
    this.window = 60,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0;
    final w = size.width - left;
    final h = size.height - 12;
    final t0 = now - window;
    double x(double t) => left + ((t - t0) / window).clamp(0.0, 1.0) * w;

    var top = pauseWait == null ? 1.0 : pauseWait! * 2;
    for (final s in samples) {
      top = math.max(top, s.ahead);
    }
    top *= 1.1;
    double y(double v) => h - (v / top).clamp(0.0, 1.0) * h;

    // Paused stretches.
    final wash = Paint()..color = Tokens.amber.withValues(alpha: 0.12);
    double? from;
    for (final s in samples) {
      if (s.paused && from == null) from = s.t;
      if (!s.paused && from != null) {
        canvas.drawRect(Rect.fromLTRB(x(from), 0, x(s.t), h), wash);
        from = null;
      }
    }
    if (from != null) {
      canvas.drawRect(Rect.fromLTRB(x(from), 0, x(now), h), wash);
    }

    // Axis and threshold.
    final axis = Paint()
      ..color = Tokens.line2
      ..strokeWidth = 1;
    canvas.drawLine(Offset(left, h), Offset(size.width, h), axis);
    paintChartLabel(canvas, '0 s', Offset(0, h - 5), Tokens.fgFaint);
    paintChartLabel(
      canvas,
      EngineFormat.seconds(Duration(milliseconds: (top * 1000).round())),
      const Offset(0, 0),
      Tokens.fgFaint,
    );
    if (pauseWait != null) {
      final py = y(pauseWait!);
      for (var d = left; d < size.width; d += 6) {
        canvas.drawLine(
          Offset(d, py),
          Offset(math.min(d + 3, size.width), py),
          axis,
        );
      }
    }
    paintChartLabel(canvas, '-60 s', Offset(left, h + 3), Tokens.fgFaint);
    paintChartLabel(
      canvas,
      'now',
      Offset(size.width - 18, h + 3),
      Tokens.fgFaint,
    );

    // The curve.
    final visible = samples.where((s) => s.t >= t0 - 1).toList();
    if (visible.length < 2) return;
    final path = Path()..moveTo(x(visible.first.t), y(visible.first.ahead));
    for (final s in visible.skip(1)) {
      path.lineTo(x(s.t), y(s.ahead));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Tokens.accent
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CacheHistoryPainter old) => true;
}
