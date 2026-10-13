import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import '../engine_format.dart';
import '../engine_snapshot.dart';
import 'engine_parts.dart';

/// The prefetch of the next entry, drawn like the `mpv_prefetch_state`
/// diagram: the five states, a timeline of the last two minutes and how
/// much of the next entry is cached.
class PrefetchView extends StatelessWidget {
  final EngineSnapshot snapshot;
  const PrefetchView({super.key, required this.snapshot});

  static Color colorOf(PrefetchState s) => switch (s) {
        PrefetchState.idle => Tokens.fgFaint,
        PrefetchState.loading => Tokens.accent,
        PrefetchState.ready => Tokens.accent,
        PrefetchState.used => Tokens.green,
        PrefetchState.failed => Tokens.red,
      };

  static String? _nextTitle(Playlist pl) {
    final i = pl.index + 1;
    if (pl.index < 0 || i >= pl.items.length) return null;
    final m = pl.items[i];
    final t = m.extras?['title'];
    if (t is String && t.isNotEmpty) return t;
    final uri = m.uri;
    final slash = uri.lastIndexOf('/');
    return Uri.decodeComponent(slash >= 0 ? uri.substring(slash + 1) : uri);
  }

  @override
  Widget build(BuildContext context) {
    final s = snapshot.state;
    final current = snapshot.prefetchState;
    final cached = snapshot.prefetchCacheDuration;
    final secs = s.cache.secs;
    // cache-secs is the prefetch target; its default is effectively
    // unbounded, so fall back to a readable scale.
    final target =
        secs > const Duration(minutes: 10) ? const Duration(seconds: 30) : secs;
    final next = _nextTitle(s.playlist);

    return EngineCard(
      title: 'Prefetch',
      caption: s.prefetchPlaylist
          ? (next == null ? 'No next entry.' : 'Next: $next')
          : 'Prefetch is off. Turn it on in Settings, Streaming.',
      trailing: StatePill(
        current.mpvValue,
        color: colorOf(current),
        strong: current != PrefetchState.idle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: Tokens.s6,
            runSpacing: Tokens.s6,
            children: [
              for (final p in PrefetchState.values)
                StatePill(
                  p.mpvValue,
                  color: colorOf(p),
                  strong: p == current,
                ),
            ],
          ),
          const SizedBox(height: Tokens.s12),
          Semantics(
            label: 'Prefetch timeline, now ${current.mpvValue}',
            excludeSemantics: true,
            child: SizedBox(
              height: 40,
              child: CustomPaint(
                painter: PrefetchTimelinePainter(
                  marks: snapshot.prefetchHistory,
                  now: snapshot.now,
                ),
              ),
            ),
          ),
          const SizedBox(height: Tokens.s12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: Tokens.s8,
            children: [
              Text('Next entry cached', style: Tokens.caption),
              Text(
                '${EngineFormat.seconds(cached)} of '
                '${EngineFormat.seconds(target)}',
                style: Tokens.numeric,
              ),
            ],
          ),
          const SizedBox(height: Tokens.s6),
          ThinBar(
            fraction: target.inMicroseconds == 0
                ? 0
                : cached.inMicroseconds / target.inMicroseconds,
            color: colorOf(
              current == PrefetchState.idle ? PrefetchState.ready : current,
            ),
          ),
        ],
      ),
    );
  }
}

/// The prefetch state over the last [window] seconds, one band per
/// stretch, with loading drawn striped as in the diagram.
class PrefetchTimelinePainter extends CustomPainter {
  final List<PrefetchMark> marks;
  final double now;
  final double window;

  PrefetchTimelinePainter({
    required this.marks,
    required this.now,
    this.window = 120,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - 14;
    final t0 = now - window;
    double x(double t) => ((t - t0) / window).clamp(0.0, 1.0) * size.width;

    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, h),
      const Radius.circular(Tokens.rSm),
    );
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(track.outerRect, Paint()..color = Tokens.surface2);

    for (var i = 0; i < marks.length; i++) {
      final m = marks[i];
      final end = i + 1 < marks.length ? marks[i + 1].t : now;
      if (end < t0) continue;
      final r = Rect.fromLTRB(x(m.t), 0, x(end), h);
      if (r.width <= 0) continue;
      _band(canvas, r, m.state);
    }
    canvas.restore();

    // Boundaries between stretches, as the diagram's dotted lines.
    final tick = Paint()
      ..color = Tokens.line2
      ..strokeWidth = 1;
    for (final m in marks.skip(1)) {
      if (m.t < t0) continue;
      canvas.drawLine(Offset(x(m.t), 0), Offset(x(m.t), h + 3), tick);
    }

    paintChartLabel(canvas, '-2 min', Offset(0, h + 4), Tokens.fgFaint);
    paintChartLabel(
      canvas,
      'now',
      Offset(size.width - 18, h + 4),
      Tokens.fgFaint,
    );
  }

  void _band(Canvas canvas, Rect r, PrefetchState s) {
    switch (s) {
      case PrefetchState.idle:
        return;
      case PrefetchState.loading:
        canvas.drawRect(r, Paint()..color = Tokens.accentDim);
        canvas.save();
        canvas.clipRect(r);
        final stripe = Paint()
          ..color = Tokens.accent.withValues(alpha: 0.35)
          ..strokeWidth = 3;
        for (var sx = r.left - r.height; sx < r.right; sx += 9) {
          canvas.drawLine(
            Offset(sx, r.bottom),
            Offset(sx + r.height, r.top),
            stripe,
          );
        }
        canvas.restore();
      case PrefetchState.ready:
        canvas.drawRect(r, Paint()..color = Tokens.accentDim);
      case PrefetchState.used:
        canvas.drawRect(
          r,
          Paint()..color = Tokens.green.withValues(alpha: 0.45),
        );
      case PrefetchState.failed:
        canvas.drawRect(
          r,
          Paint()..color = Tokens.red.withValues(alpha: 0.35),
        );
    }
    if (r.width > 44) {
      paintChartLabel(
        canvas,
        s.mpvValue,
        Offset(r.left + math.min(r.width / 2, 40), r.center.dy),
        Tokens.fg,
        center: true,
        middle: true,
      );
    }
  }

  @override
  bool shouldRepaint(PrefetchTimelinePainter old) => true;
}
