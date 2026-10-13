import 'package:flutter/material.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import 'graphic_height.dart';

/// A schematic of headphone crossfeed: two channel sources feeding a
/// listener, with the straight same-ear paths always on and the crossed
/// paths (the bleed that makes headphones sound like speakers) fading in
/// as the strength rises. It's a diagram, not a meter — it shows what the
/// control does to the routing at a glance.
class CrossfeedDiagram extends StatelessWidget {
  final double strength; // 0..1
  final double range; // 0..1
  final bool enabled;

  const CrossfeedDiagram({
    super.key,
    required this.strength,
    required this.range,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Crossfeed routing',
      value:
          'bleed ${(strength * 100).round()}%, '
          'range ${(range * 100).round()}%',
      child: SizedBox(
        height: graphicHeight(context, 0, min: 132, max: 132),
        width: double.infinity,
        child: CustomPaint(
          size: Size.infinite,
          painter: _CrossfeedPainter(
            strength: strength,
            range: range,
            enabled: enabled,
          ),
        ),
      ),
    );
  }
}

class _CrossfeedPainter extends CustomPainter {
  final double strength;
  final double range;
  final bool enabled;

  _CrossfeedPainter({
    required this.strength,
    required this.range,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final accent = enabled ? Tokens.accent : Tokens.fgFaint;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final span = (size.width * 0.34).clamp(60.0, 220.0);

    final lSrc = Offset(cx - span, cy);
    final rSrc = Offset(cx + span, cy);
    final headR = 20.0;
    final lEar = Offset(cx - headR, cy);
    final rEar = Offset(cx + headR, cy);

    // Listener head.
    canvas.drawCircle(
      Offset(cx, cy),
      headR,
      Paint()
        ..color = Tokens.line2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    // Ears.
    for (final ear in [lEar, rEar]) {
      canvas.drawCircle(ear, 3, Paint()..color = Tokens.fgDim);
    }

    // Direct same-ear paths — always full.
    final direct = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(lSrc, lEar, direct);
    canvas.drawLine(rSrc, rEar, direct);

    // Crossed paths — arc over (L→right ear) and under (R→left ear),
    // their presence scaling with strength.
    final crossPaint = Paint()
      ..color = accent.withValues(
        alpha: enabled ? (0.2 + 0.8 * strength) : 0.25,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 + 2.5 * strength
      ..strokeCap = StrokeCap.round;
    final arch = headR + 16 + 18 * range; // higher crossover → taller arc
    final over = Path()
      ..moveTo(lSrc.dx, lSrc.dy)
      ..quadraticBezierTo(cx, cy - arch, rEar.dx, rEar.dy);
    final under = Path()
      ..moveTo(rSrc.dx, rSrc.dy)
      ..quadraticBezierTo(cx, cy + arch, lEar.dx, lEar.dy);
    canvas.drawPath(over, crossPaint);
    canvas.drawPath(under, crossPaint);

    // Source nodes + labels.
    void node(Offset at, String label) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 22, height: 16),
          const Radius.circular(4),
        ),
        Paint()..color = Tokens.surface2,
      );
      paintChartLabel(
        canvas,
        label,
        at.translate(0, -5),
        accent,
        fontSize: 9.5,
        center: true,
        middle: true,
      );
    }

    node(lSrc, 'L');
    node(rSrc, 'R');

    // Strength caption.
    paintChartLabel(
      canvas,
      'bleed ${(strength * 100).round()}%',
      Offset(cx, size.height - 14),
      enabled ? Tokens.fgDim : Tokens.fgFaint,
      fontSize: 9.5,
      center: true,
      middle: true,
    );
  }

  @override
  bool shouldRepaint(_CrossfeedPainter old) =>
      old.strength != strength || old.range != range || old.enabled != enabled;
}
