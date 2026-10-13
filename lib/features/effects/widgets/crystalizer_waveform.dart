import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';

/// A before/after sketch of the crystalizer. A representative waveform is
/// drawn faintly (the input) under the same waveform run through the
/// crystalizer's sample-difference law — `y[n] = x[n] + i·(x[n]−x[n−1])`
/// — in accent. Positive intensity sharpens transients (the accent trace
/// grows spikier than the input); negative intensity smooths them. It's an
/// illustration of the control's behaviour, not a live capture.
class CrystalizerWaveform extends StatelessWidget {
  final double intensity; // -10..10
  final bool enabled;

  const CrystalizerWaveform({
    super.key,
    required this.intensity,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      width: double.infinity,
      child: CustomPaint(
        size: Size.infinite,
        painter: _CrystalPainter(intensity: intensity, enabled: enabled),
      ),
    );
  }
}

class _CrystalPainter extends CustomPainter {
  final double intensity;
  final bool enabled;

  _CrystalPainter({required this.intensity, required this.enabled});

  /// A representative input waveform — a couple of partials under a
  /// percussive envelope, so transients are present for the law to act on.
  static double _input(double t) {
    final env = math.exp(-3.0 * (t % 0.34) / 0.34);
    return env *
        (math.sin(2 * math.pi * 6 * t) + 0.5 * math.sin(2 * math.pi * 13 * t));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final accent = enabled ? Tokens.accent : Tokens.fgFaint;
    final w = size.width;
    final h = size.height;
    final mid = h / 2;
    final amp = h * 0.38;
    const n = 240;

    // Zero line.
    canvas.drawLine(
      Offset(0, mid),
      Offset(w, mid),
      Paint()
        ..color = Tokens.line2
        ..strokeWidth = 1,
    );

    final xs = List<double>.generate(n, (i) => i / (n - 1));
    final inVals = xs.map(_input).toList();
    // Crystalizer difference law.
    final i = intensity;
    final outVals = List<double>.generate(n, (k) {
      if (k == 0) return inVals[0];
      return inVals[k] + i * (inVals[k] - inVals[k - 1]);
    });

    double yOf(double v) => mid - v.clamp(-2.4, 2.4) / 2.4 * amp;
    double xOf(int k) => xs[k] * w;

    Path build(List<double> vals) {
      final p = Path()..moveTo(xOf(0), yOf(vals[0]));
      for (var k = 1; k < n; k++) {
        p.lineTo(xOf(k), yOf(vals[k]));
      }
      return p;
    }

    // Input (before) — faint.
    canvas.drawPath(
      build(inVals),
      Paint()
        ..color = Tokens.fgFaint.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..isAntiAlias = true,
    );
    // Output (after) — accent.
    canvas.drawPath(
      build(outVals),
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );

    paintChartLabel(
      canvas,
      intensity >= 0 ? 'sharpen' : 'smooth',
      const Offset(4, 4),
      accent,
    );
    paintChartLabel(canvas, 'input', Offset(w - 34, 4), Tokens.fgFaint);
  }

  @override
  bool shouldRepaint(_CrystalPainter old) =>
      old.intensity != intensity || old.enabled != enabled;
}
