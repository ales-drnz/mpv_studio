import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';

/// A LUFS scale with the live EBU R128 readings on it: momentary as the
/// bar, short-term as a bright tick, integrated as the marker the bar
/// should settle around. A [target] draws the loudness range around it
/// (the loudnorm aim) and [truePeak] the ceiling, so the reading is seen
/// against where the chain is trying to go.
class LoudnessGauge extends StatelessWidget {
  /// The live reading, `null` while the meter is off.
  final Loudness? reading;

  /// Integrated loudness target, LUFS.
  final double? target;

  /// Loudness range around [target], LU.
  final double? range;

  /// True peak ceiling, dBTP.
  final double? truePeak;

  final bool enabled;

  const LoudnessGauge({
    super.key,
    this.reading,
    this.target,
    this.range,
    this.truePeak,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      width: double.infinity,
      child: CustomPaint(
        size: Size.infinite,
        painter: _GaugePainter(
          reading: reading,
          target: target,
          range: range,
          truePeak: truePeak,
          enabled: enabled,
        ),
      ),
    );
  }
}

const double _luMin = -48;
const double _luMax = 0;

class _GaugePainter extends CustomPainter {
  final Loudness? reading;
  final double? target;
  final double? range;
  final double? truePeak;
  final bool enabled;

  _GaugePainter({
    required this.reading,
    required this.target,
    required this.range,
    required this.truePeak,
    required this.enabled,
  });

  static const _ticks = [-48, -36, -24, -18, -12, -6, 0];

  @override
  void paint(Canvas canvas, Size size) {
    final accent = enabled ? Tokens.accent : Tokens.fgFaint;
    const padX = 6.0;
    const barTop = 22.0;
    const barH = 22.0;
    final left = padX;
    final w = size.width - 2 * padX;
    if (w <= 0) return;

    double x(double lu) =>
        left + ((lu.clamp(_luMin, _luMax) - _luMin) / (_luMax - _luMin)) * w;

    // Rail.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(left, barTop, w, barH), const Radius.circular(4)),
      Paint()..color = Tokens.surface2,
    );

    // Target and its range.
    final t = target;
    if (t != null) {
      final lra = range ?? 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(x(t - lra / 2), barTop, x(t + lra / 2), barTop + barH),
          const Radius.circular(4),
        ),
        Paint()..color = accent.withValues(alpha: 0.14),
      );
      canvas.drawRect(Rect.fromLTWH(x(t) - 0.5, barTop, 1, barH),
          Paint()..color = accent.withValues(alpha: 0.6));
      paintChartLabel(canvas, 'target ${t.round()}', Offset(x(t), 6),
          Tokens.fgDim,
          center: true);
    }

    // Momentary bar.
    final r = reading;
    final m = r?.momentary;
    if (m != null && m > _luMin) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, barTop + 6, x(m), barTop + barH - 6),
          const Radius.circular(2),
        ),
        Paint()..color = accent.withValues(alpha: 0.85),
      );
    }
    // Short-term tick.
    final s = r?.shortTerm;
    if (s != null && s > _luMin) {
      canvas.drawRect(Rect.fromLTWH(x(s) - 1.5, barTop + 2, 3, barH - 4),
          Paint()..color = Tokens.fg);
    }
    // Integrated marker, below the rail.
    final i = r?.integrated;
    if (i != null && i > _luMin) {
      final xi = x(i);
      final tri = Path()
        ..moveTo(xi, barTop + barH + 1)
        ..lineTo(xi - 4, barTop + barH + 7)
        ..lineTo(xi + 4, barTop + barH + 7)
        ..close();
      canvas.drawPath(tri, Paint()..color = Tokens.amber);
    }

    // True peak ceiling.
    final tp = truePeak;
    if (tp != null) {
      canvas.drawRect(Rect.fromLTWH(x(tp) - 1, barTop - 2, 2, barH + 4),
          Paint()..color = enabled ? Tokens.red : Tokens.fgFaint);
    }

    // Scale.
    for (final lu in _ticks) {
      final xx = x(lu.toDouble());
      canvas.drawLine(Offset(xx, barTop + barH), Offset(xx, barTop + barH + 3),
          Paint()..color = Tokens.fgFaint);
      paintChartLabel(canvas, '$lu', Offset(xx, barTop + barH + 10),
          Tokens.fgFaint,
          center: true);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.reading != reading ||
      old.target != target ||
      old.range != range ||
      old.truePeak != truePeak ||
      old.enabled != enabled;
}
