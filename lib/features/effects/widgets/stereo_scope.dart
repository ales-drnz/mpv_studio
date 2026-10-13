import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../audio/pcm_analysis.dart';
import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import '../rack_environment.dart';

/// A stereo vectorscope (goniometer) — the live picture of the stereo
/// image. Each L/R sample pair is rotated into mid/side and scattered in
/// the plane: a vertical pencil means mono, a wide cloud means a broad
/// stereo field, and a horizontal smear means the channels are drifting
/// out of phase. A phase-correlation bar underneath puts a number on it
/// (+1 mono → −1 inverted).
///
/// Fed by the chain's output ([RackEnvironment.pcm]) so it reflects whatever the width control is
/// doing to the output. Flat house style; scales to fit any width.
class StereoScope extends StatefulWidget {
  final bool enabled;
  const StereoScope({super.key, required this.enabled});

  @override
  State<StereoScope> createState() => _StereoScopeState();
}

class _StereoScopeState extends State<StereoScope> {
  static const int _capacity = 900;
  final Float32List _xs = Float32List(_capacity);
  final Float32List _ys = Float32List(_capacity);
  int _count = 0;
  int _head = 0;
  final _corr = ValueNotifier<double>(0);
  final _tick = ValueNotifier<int>(0);

  Stream<PcmFrame>? _pcm;
  StreamSubscription<PcmFrame>? _sub;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pcm = RackEnvironment.maybeOf(context)?.pcm;
    if (pcm == _pcm) return;
    _pcm = pcm;
    _sub?.cancel();
    _sub = pcm?.listen(_onFrame);
  }

  void _onFrame(PcmFrame f) {
    if (!mounted) return;
    final s = f.samples;
    final ch = f.channels;
    if (ch < 2 || s.length < 2) {
      // Mono: a single vertical line; still update correlation to +1.
      _corr.value = 1;
      return;
    }
    // Decimate to a bounded number of scatter points per frame so dense
    // frames don't blow the ring or the paint cost.
    final pairs = s.length ~/ ch;
    final step = math.max(1, pairs ~/ 220);
    for (var p = 0; p < pairs; p += step) {
      final point = midSide(s[p * ch], s[p * ch + 1]);
      _xs[_head] = point.x;
      _ys[_head] = point.y;
      _head = (_head + 1) % _capacity;
      if (_count < _capacity) _count++;
    }
    _corr.value = emaTowards(_corr.value, stereoCorrelation(f), 0.25);
    _tick.value++;
  }

  @override
  void dispose() {
    _sub?.cancel();
    _corr.dispose();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 188,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ScopePainter(
            xs: _xs,
            ys: _ys,
            count: () => _count,
            head: () => _head,
            capacity: _capacity,
            corr: _corr,
            tick: _tick,
            enabled: widget.enabled,
          ),
        ),
      ),
    );
  }
}

class _ScopePainter extends CustomPainter {
  final Float32List xs;
  final Float32List ys;
  final int Function() count;
  final int Function() head;
  final int capacity;
  final ValueListenable<double> corr;
  final ValueListenable<int> tick;
  final bool enabled;

  _ScopePainter({
    required this.xs,
    required this.ys,
    required this.count,
    required this.head,
    required this.capacity,
    required this.corr,
    required this.tick,
    required this.enabled,
  }) : super(repaint: Listenable.merge([tick, corr]));

  static const double _barH = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final scopeH = size.height - _barH;
    final side = math.min(size.width, scopeH);
    final cx = size.width / 2;
    final cy = scopeH / 2;
    // 95% of the radius is "full scale" so peaks don't clip at the edge.
    final radius = side / 2 * 0.92;
    final accent = enabled ? Tokens.accent : Tokens.fgFaint;

    // Frame: circle + the mono(vertical)/anti-phase(horizontal) crosshair.
    final guide = Paint()
      ..color = Tokens.line2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(cx, cy), radius, guide);
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.5,
      Paint()
        ..color = Tokens.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final cross = Paint()
      ..color = Tokens.line
      ..strokeWidth = 1;
    canvas.drawLine(Offset(cx, cy - radius), Offset(cx, cy + radius), cross);
    canvas.drawLine(Offset(cx - radius, cy), Offset(cx + radius, cy), cross);
    // Diagonal L / R axes (the pure-left and pure-right directions).
    final diag = Paint()
      ..color = Tokens.line
      ..strokeWidth = 1;
    final d = radius * 0.70710678;
    canvas.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), diag);
    canvas.drawLine(Offset(cx + d, cy - d), Offset(cx - d, cy + d), diag);
    paintChartLabel(
      canvas,
      'L',
      Offset(cx - d - 10, cy - d - 10),
      Tokens.fgFaint,
    );
    paintChartLabel(
      canvas,
      'R',
      Offset(cx + d + 4, cy - d - 10),
      Tokens.fgFaint,
    );
    paintChartLabel(
      canvas,
      'M',
      Offset(cx + 4, cy - radius - 1),
      Tokens.fgFaint,
    );

    // Scatter — newest points brightest. Draw as tiny dots.
    final n = count();
    if (enabled && n > 0) {
      final h = head();
      final dot = Paint()..color = accent;
      for (var i = 0; i < n; i++) {
        // age 0 = newest (just before head), age n-1 = oldest.
        final idx = (h - 1 - i + capacity * 2) % capacity;
        final age = i / n;
        final px = cx + xs[idx].clamp(-1.0, 1.0) * radius;
        final py = cy - ys[idx].clamp(-1.0, 1.0) * radius;
        dot.color = accent.withValues(alpha: (1 - age) * 0.5 + 0.05);
        canvas.drawCircle(Offset(px, py), 1.1, dot);
      }
    }

    // Phase-correlation bar.
    final barTop = scopeH + 3;
    final barRect = Rect.fromLTWH(2, barTop, size.width - 4, _barH - 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
      Paint()..color = Tokens.surface2,
    );
    final c = corr.value;
    final mid = barRect.center.dx;
    final half = barRect.width / 2;
    // 0 correlation is dead-centre; +1 (mono) to the right, −1 to the left.
    final fillX = mid + c * half;
    final fillColor = c < -0.1
        ? Tokens.red
        : c < 0.35
        ? Tokens.green
        : Tokens.accent;
    final lo = math.min(mid, fillX);
    final hi = math.max(mid, fillX);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(lo, barRect.top, hi, barRect.bottom),
        const Radius.circular(3),
      ),
      Paint()..color = enabled ? fillColor : Tokens.fgFaint,
    );
    canvas.drawLine(
      Offset(mid, barRect.top),
      Offset(mid, barRect.bottom),
      Paint()
        ..color = Tokens.fgFaint
        ..strokeWidth = 1,
    );
    paintChartLabel(
      canvas,
      '−1',
      Offset(4, barTop + _barH - 8),
      Tokens.fgFaint,
    );
    paintChartLabel(
      canvas,
      enabled ? c.toStringAsFixed(2) : 'corr',
      Offset(mid - 9, barTop + _barH - 8),
      enabled ? fillColor : Tokens.fgFaint,
    );
    paintChartLabel(
      canvas,
      '+1',
      Offset(size.width - 14, barTop + _barH - 8),
      Tokens.fgFaint,
    );
  }

  @override
  bool shouldRepaint(_ScopePainter old) => old.enabled != enabled;
}
