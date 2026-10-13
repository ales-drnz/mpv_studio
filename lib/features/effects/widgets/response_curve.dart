import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';

/// A magnitude-vs-frequency plot — the response any tone control draws on
/// the signal, sketched in the flat house style over a log-frequency
/// lattice (the same 20 Hz … 20 kHz decades a spectrum analyzer uses).
///
/// The shape is supplied analytically by [response] (dB at a given Hz),
/// so a shelf, a resonant boost, or a combination all share one widget
/// and one look. A faint marker line pins the control's corner frequency
/// and the curve fills a bipolar wash from the 0 dB centre.
class ResponseCurve extends StatelessWidget {
  /// Magnitude in dB at frequency [hz].
  final double Function(double hz) response;
  final bool enabled;

  /// Symmetric dB extent of the vertical axis.
  final double maxDb;

  /// Optional corner/centre frequency to mark with a vertical hairline.
  final double? markerHz;

  /// What the curve shows, for screen readers (`+6 dB below 120 Hz`).
  final String? description;

  const ResponseCurve({
    super.key,
    required this.response,
    required this.enabled,
    this.maxDb = 24,
    this.markerHz,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Frequency response',
      value: description,
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: (c.maxWidth * 0.24).clamp(132.0, 220.0),
          width: double.infinity,
          child: CustomPaint(
            size: Size.infinite,
            painter: _ResponsePainter(
              response: response,
              enabled: enabled,
              maxDb: maxDb,
              markerHz: markerHz,
            ),
          ),
        ),
      ),
    );
  }
}

const double _fMin = 20;
const double _fMax = 20000;
const _decades = [
  (20.0, '20'),
  (100.0, '100'),
  (1000.0, '1k'),
  (10000.0, '10k'),
];

class _ResponsePainter extends CustomPainter {
  final double Function(double hz) response;
  final bool enabled;
  final double maxDb;
  final double? markerHz;

  _ResponsePainter({
    required this.response,
    required this.enabled,
    required this.maxDb,
    required this.markerHz,
  });

  static const double _rightGutter = 22;
  static const double _bottomGutter = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      2,
      6,
      size.width - _rightGutter,
      size.height - _bottomGutter,
    );
    if (plot.width <= 0 || plot.height <= 0) return;

    final accent = enabled ? Tokens.accent : Tokens.fgFaint;
    final logMin = math.log(_fMin);
    final logMax = math.log(_fMax);

    double xOf(double hz) =>
        plot.left + ((math.log(hz) - logMin) / (logMax - logMin)) * plot.width;
    double yOf(double db) =>
        plot.top + (1 - (db + maxDb) / (2 * maxDb)) * plot.height;

    // dB gridlines: 0 centre brighter, ±half-scale faint.
    final grid = Paint()..strokeWidth = 1;
    for (final db in [maxDb, maxDb / 2, 0.0, -maxDb / 2, -maxDb]) {
      final yy = yOf(db);
      grid.color = db == 0 ? Tokens.line2 : Tokens.line;
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
    }
    paintChartLabel(
      canvas,
      '+${maxDb.toInt()}',
      Offset(plot.right + 3, yOf(maxDb) - 5),
      Tokens.fgFaint,
    );
    paintChartLabel(
      canvas,
      '${(-maxDb).toInt()}',
      Offset(plot.right + 3, yOf(-maxDb) - 5),
      Tokens.fgFaint,
    );

    // Frequency decade lines + labels.
    for (final d in _decades) {
      final xx = xOf(d.$1);
      canvas.drawLine(
        Offset(xx, plot.top),
        Offset(xx, plot.bottom),
        Paint()..color = Tokens.line,
      );
      paintChartLabel(
        canvas,
        d.$2,
        Offset(xx, plot.bottom + 2),
        Tokens.fgFaint,
        center: true,
      );
    }

    // Corner-frequency marker.
    if (markerHz != null && markerHz! >= _fMin && markerHz! <= _fMax) {
      final mx = xOf(markerHz!);
      canvas.drawLine(
        Offset(mx, plot.top),
        Offset(mx, plot.bottom),
        Paint()..color = Tokens.accentDim,
      );
    }

    // Sample the analytic response across the plotted decades.
    final curve = Path();
    const steps = 200;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final hz = math.exp(logMin + t * (logMax - logMin));
      final px = plot.left + t * plot.width;
      final py = yOf(response(hz).clamp(-maxDb, maxDb));
      if (i == 0) {
        curve.moveTo(px, py);
      } else {
        curve.lineTo(px, py);
      }
    }

    final zeroY = yOf(0);
    final fill = Path.from(curve)
      ..lineTo(plot.right, zeroY)
      ..lineTo(plot.left, zeroY)
      ..close();
    canvas.save();
    canvas.clipRect(plot.inflate(1));
    canvas.drawPath(fill, Paint()..color = accent.withValues(alpha: 0.12));
    canvas.restore();

    canvas.drawPath(
      curve,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ResponsePainter old) =>
      old.enabled != enabled ||
      old.maxDb != maxDb ||
      old.markerHz != markerHz ||
      old.response != response;
}
