import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../audio/dynamics.dart';
import '../../../audio/pcm_analysis.dart';
import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import 'graphic_height.dart';
import '../rack_environment.dart';

/// The compressor's transfer curve — the universal dB-in / dB-out knee
/// diagram. The accent curve bends away from the faint unity (y = x)
/// reference past the threshold; the shaded wedge between them is the
/// gain it's giving back. When audio is playing a live dot rides the
/// curve at the current input level and a compact GR readout shows how
/// many dB are being shed right now.
///
/// Drawn in the flat house style (hairline lattice, single accent, no
/// glows) and sized to fit any width, so it reads the same inline on
/// desktop and on a phone.
class CompressorCurve extends StatefulWidget {
  final double threshold; // linear amplitude (lavfi)
  final double ratio;
  final double knee; // linear lavfi "factor", 1..8
  final double makeup; // linear amplitude
  final bool enabled;

  /// Which compressor of the chain the live dot follows (0 for the first).
  final int instance;

  /// Whether to tap the stage at all: the rack turns it off for a stage
  /// that is switched off or over the tap budget.
  final bool live;

  const CompressorCurve({
    super.key,
    required this.threshold,
    required this.ratio,
    required this.knee,
    required this.makeup,
    required this.enabled,
    this.instance = 0,
    this.live = true,
  });

  @override
  State<CompressorCurve> createState() => _CompressorCurveState();
}

const double _dbFloor = -60;
const double _dbCeil = 0;

class _CompressorCurveState extends State<CompressorCurve> {
  final _inDb = ValueNotifier<double>(_dbFloor);
  final _grDb = ValueNotifier<double>(0);
  double _inRms = _dbFloor;
  double _outRms = _dbFloor;
  double _inPeak = _dbFloor;
  final List<StreamSubscription<PcmFrame>> _subs = [];
  TapSource? _taps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final taps = RackEnvironment.maybeOf(context)?.taps;
    if (taps != _taps) {
      _taps = taps;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(CompressorCurve old) {
    super.didUpdateWidget(old);
    if (old.instance != widget.instance || old.live != widget.live) {
      _subscribe();
    }
  }

  void _subscribe() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _inDb.value = _dbFloor;
    _grDb.value = 0;
    final taps = _taps;
    if (!widget.live || taps == null) return;
    _subs.add(
      taps(AudioFilter.acompressor, widget.instance, TapSide.pre).listen((pcm) {
        if (!mounted) return;
        _inPeak = _smoothPeak(pcm, _inPeak);
        _inRms = _smoothRms(pcm, _inRms);
        _inDb.value = _inPeak;
        _grDb.value = (_inRms - _outRms).clamp(0.0, 24.0);
      }),
    );
    _subs.add(
      taps(AudioFilter.acompressor, widget.instance, TapSide.post).listen((
        pcm,
      ) {
        if (!mounted) return;
        _outRms = _smoothRms(pcm, _outRms);
        _grDb.value = (_inRms - _outRms).clamp(0.0, 24.0);
      }),
    );
  }

  /// Peak level in dB, snappy attack / slow release.
  double _smoothPeak(PcmFrame f, double prev) {
    final db = amplitudeToDb(
      framePeak(f),
      floorDb: _dbFloor,
    ).clamp(_dbFloor, _dbCeil);
    return emaTowards(prev, db.toDouble(), db > prev ? 0.6 : 0.06);
  }

  /// Short-term RMS level in dB, medium smoothing.
  double _smoothRms(PcmFrame f, double prev) {
    final db = amplitudeToDb(
      frameRms(f),
      floorDb: _dbFloor,
    ).clamp(_dbFloor, _dbCeil);
    return emaTowards(prev, db.toDouble(), 0.3);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _inDb.dispose();
    _grDb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    return Semantics(
      label: 'Compressor transfer curve',
      value:
          'threshold ${amplitudeToDb(w.threshold).round()} dB, '
          'ratio ${w.ratio.toStringAsFixed(1)} to 1, '
          'make-up ${amplitudeToDb(w.makeup).round()} dB',
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(
          height: graphicHeight(
            context,
            c.maxWidth,
            ratio: 0.3,
            min: 150,
            max: 240,
          ),
          width: double.infinity,
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size.infinite,
              painter: _KneePainter(
                thresholdDb: amplitudeToDb(widget.threshold),
                ratio: widget.ratio,
                kneeDb: amplitudeToDb(widget.knee.clamp(1.0, 8.0)),
                makeupDb: amplitudeToDb(widget.makeup),
                enabled: widget.enabled,
                inDb: _inDb,
                grDb: _grDb,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KneePainter extends CustomPainter {
  final double thresholdDb;
  final double ratio;
  final double kneeDb;
  final double makeupDb;
  final bool enabled;
  final ValueListenable<double> inDb;
  final ValueListenable<double> grDb;

  _KneePainter({
    required this.thresholdDb,
    required this.ratio,
    required this.kneeDb,
    required this.makeupDb,
    required this.enabled,
    required this.inDb,
    required this.grDb,
  }) : super(repaint: Listenable.merge([inDb, grDb]));

  static const double _rightGutter = 24;
  static const double _bottomGutter = 16;
  static const _grid = [-48.0, -36.0, -24.0, -12.0];

  double _kneeOut(double inDb) => compressorKneeDb(
    inDb,
    thresholdDb: thresholdDb,
    ratio: ratio,
    kneeDb: kneeDb,
    makeupDb: makeupDb,
  );

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

    double x(double db) =>
        plot.left + ((db - _dbFloor) / (_dbCeil - _dbFloor)) * plot.width;
    double y(double db) =>
        plot.top +
        (1 -
                ((db.clamp(_dbFloor, _dbCeil) - _dbFloor) /
                    (_dbCeil - _dbFloor))) *
            plot.height;

    // Grid lattice + axis labels.
    final grid = Paint()
      ..color = Tokens.line
      ..strokeWidth = 1;
    for (final db in _grid) {
      canvas.drawLine(
        Offset(x(db), plot.top),
        Offset(x(db), plot.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(plot.left, y(db)),
        Offset(plot.right, y(db)),
        grid,
      );
      paintChartLabel(
        canvas,
        '${db.toInt()}',
        Offset(x(db), plot.bottom + 3),
        Tokens.fgFaint,
        center: true,
      );
      paintChartLabel(
        canvas,
        '${db.toInt()}',
        Offset(plot.right + 3, y(db) - 5),
        Tokens.fgFaint,
      );
    }

    // Unity reference (no compression).
    canvas.drawLine(
      Offset(x(_dbFloor), y(_dbFloor)),
      Offset(x(_dbCeil), y(_dbCeil)),
      Paint()
        ..color = Tokens.fgFaint
        ..strokeWidth = 1,
    );

    // Threshold marker + above-threshold wash.
    final tx = x(thresholdDb.clamp(_dbFloor, _dbCeil));
    canvas.drawRect(
      Rect.fromLTRB(tx, plot.top, plot.right, plot.bottom),
      Paint()..color = accent.withValues(alpha: 0.05),
    );
    canvas.drawLine(
      Offset(tx, plot.top),
      Offset(tx, plot.bottom),
      Paint()
        ..color = Tokens.accentDim
        ..strokeWidth = 1,
    );

    // Knee transfer curve + the wedge of gain reduction under unity.
    final curve = Path();
    final wedge = Path();
    const steps = 160;
    for (var i = 0; i <= steps; i++) {
      final inputDb = _dbFloor + (i / steps) * (_dbCeil - _dbFloor);
      final px = x(inputDb);
      final py = y(_kneeOut(inputDb));
      if (i == 0) {
        curve.moveTo(px, py);
        wedge.moveTo(px, y(inputDb));
      } else {
        curve.lineTo(px, py);
      }
    }
    for (var i = steps; i >= 0; i--) {
      final inputDb = _dbFloor + (i / steps) * (_dbCeil - _dbFloor);
      wedge.lineTo(x(inputDb), y(_kneeOut(inputDb)));
    }
    wedge.close();
    canvas.save();
    canvas.clipRect(plot);
    canvas.drawPath(wedge, Paint()..color = accent.withValues(alpha: 0.10));
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

    // Live dot riding the curve at the current input level.
    final iDb = inDb.value;
    if (enabled && iDb > _dbFloor + 0.5) {
      final bx = x(iDb);
      final by = y(_kneeOut(iDb));
      canvas.drawCircle(Offset(bx, by), 4, Paint()..color = Tokens.fg);
      canvas.drawCircle(
        Offset(bx, by),
        4,
        Paint()
          ..color = Tokens.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // GR readout — top-left chip.
    final gr = grDb.value;
    if (enabled && gr > 0.1) {
      paintChartLabel(
        canvas,
        '−${gr.toStringAsFixed(1)} dB GR',
        Offset(plot.left + 4, plot.top + 2),
        Tokens.accent,
      );
    }
  }

  @override
  bool shouldRepaint(_KneePainter old) =>
      old.thresholdDb != thresholdDb ||
      old.ratio != ratio ||
      old.kneeDb != kneeDb ||
      old.makeupDb != makeupDb ||
      old.enabled != enabled;
}
