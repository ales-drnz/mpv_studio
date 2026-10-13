import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../audio/level_follower.dart';
import '../../../audio/pcm_analysis.dart';
import '../../../ui/chart_text.dart';
import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';

/// A stereo peak meter fed by `player.stream.pcm`. Two bars (left and
/// right) with pro PPM ballistics (fast attack, slow release, a latched
/// peak-hold marker) and flat green, amber and red zones. The ballistics
/// live in [LevelFollower]; this widget pushes frame peaks, ticks and
/// paints.
/// It only ticks while there is something to show: frames arriving or bars
/// still falling. Subscribing arms the PCM tap (shared with the spectrum);
/// it disarms on unmount.
///
/// [axis] picks horizontal bars (default) or vertical bars (for a slim
/// meter beside the transport).
class VuMeter extends StatefulWidget {
  final Axis axis;
  const VuMeter({super.key, this.axis = Axis.horizontal});

  @override
  State<VuMeter> createState() => _VuMeterState();
}

class _VuMeterState extends State<VuMeter>
    with SingleTickerProviderStateMixin, StreamListenerState<VuMeter> {
  static const double _minDb = -60;
  static const double _maxDb = 0;

  final _left = LevelFollower(minDb: _minDb);
  final _right = LevelFollower(minDb: _minDb);

  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  @override
  void onSubscribe() {
    listen(PlaybackScope.of(context).player.stream.pcm, _onFrame);
  }

  void _onFrame(PcmFrame f) {
    final peaks = channelPeaks(f);
    _left.push(peaks.left);
    _right.push(peaks.right);
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  bool get _resting =>
      _left.db <= _minDb &&
      _right.db <= _minDb &&
      _left.holdDb <= _minDb &&
      _right.holdDb <= _minDb;

  void _onTick(Duration elapsed) {
    final dtS = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dtS <= 0) return;
    _left.tick(dtS, elapsed);
    _right.tick(dtS, elapsed);
    // Silence and the bars back at the floor: nothing moves until the
    // next frame, so stop asking for frames.
    if (_resting) _ticker.stop();
    setState(() {});
  }

  /// A level for screen readers, in 6 dB steps so the value does not
  /// change on every frame.
  static String _level(double db) =>
      db <= _minDb ? 'silent' : '${(db / 6).round() * 6} dB';

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = _VuPainter(
      axis: widget.axis,
      dbL: _left.db.clamp(_minDb, _maxDb),
      dbR: _right.db.clamp(_minDb, _maxDb),
      holdL: _left.holdDb.clamp(_minDb, _maxDb),
      holdR: _right.holdDb.clamp(_minDb, _maxDb),
      minDb: _minDb,
      maxDb: _maxDb,
      palette: Tokens.palette,
    );
    final vertical = widget.axis == Axis.vertical;
    return Semantics(
      label: 'Output level',
      value: 'left ${_level(_left.db)}, right ${_level(_right.db)}',
      excludeSemantics: true,
      child: SizedBox(
        width: vertical ? 40 : null,
        height: vertical ? null : 30,
        child: CustomPaint(size: Size.infinite, painter: painter),
      ),
    );
  }
}

class _VuPainter extends CustomPainter {
  final Axis axis;
  final double dbL, dbR, holdL, holdR, minDb, maxDb;
  final Palette palette;
  static const double _amberDb = -18;
  static const double _redDb = -6;

  _VuPainter({
    required this.axis,
    required this.dbL,
    required this.dbR,
    required this.holdL,
    required this.holdR,
    required this.minDb,
    required this.maxDb,
    required this.palette,
  });

  double _t(double db) => ((db - minDb) / (maxDb - minDb)).clamp(0.0, 1.0);

  Color _holdColor(double db) => db >= _redDb
      ? palette.red
      : db >= _amberDb
      ? palette.amber
      : palette.green;

  void _barH(Canvas canvas, Rect r, double db, double hold) {
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = palette.surface2);
    canvas.save();
    canvas.clipRRect(rrect);
    final litW = _t(db) * r.width;
    final amberX = _t(_amberDb) * r.width;
    final redX = _t(_redDb) * r.width;
    void seg(double x0, double x1, Color c) {
      final a = x0.clamp(0.0, litW);
      final b = x1.clamp(0.0, litW);
      if (b > a) {
        canvas.drawRect(
          Rect.fromLTRB(r.left + a, r.top, r.left + b, r.bottom),
          Paint()..color = c,
        );
      }
    }

    seg(0, amberX, palette.green);
    seg(amberX, redX, palette.amber);
    seg(redX, r.width, palette.red);
    canvas.restore();
    if (hold > minDb) {
      final hx = r.left + _t(hold) * r.width;
      canvas.drawLine(
        Offset(hx, r.top),
        Offset(hx, r.bottom),
        Paint()
          ..color = _holdColor(hold)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _barV(Canvas canvas, Rect r, double db, double hold) {
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(3));
    canvas.drawRRect(rrect, Paint()..color = palette.surface2);
    canvas.save();
    canvas.clipRRect(rrect);
    final litTopY = r.bottom - _t(db) * r.height;
    final amberY = r.bottom - _t(_amberDb) * r.height;
    final redY = r.bottom - _t(_redDb) * r.height;
    void seg(double yTop, double yBottom, Color c) {
      final a = math.max(yTop, litTopY);
      final b = yBottom;
      if (b > a) {
        canvas.drawRect(
          Rect.fromLTRB(r.left, a, r.right, b),
          Paint()..color = c,
        );
      }
    }

    seg(amberY, r.bottom, palette.green);
    seg(redY, amberY, palette.amber);
    seg(r.top, redY, palette.red);
    canvas.restore();
    if (hold > minDb) {
      final hy = r.bottom - _t(hold) * r.height;
      canvas.drawLine(
        Offset(r.left, hy),
        Offset(r.right, hy),
        Paint()
          ..color = _holdColor(hold)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    if (axis == Axis.horizontal) {
      const labelW = 14.0, barH = 10.0, gap = 4.0;
      final barLeft = labelW + 6;
      final barW = w - barLeft;
      if (barW <= 0) return;
      final topY = (h - (barH * 2 + gap)) / 2;
      final lRect = Rect.fromLTWH(barLeft, topY, barW, barH);
      final rRect = Rect.fromLTWH(barLeft, topY + barH + gap, barW, barH);
      paintChartLabel(
        canvas,
        'L',
        Offset(0, lRect.center.dy - 6),
        palette.fgFaint,
        fontSize: 10,
      );
      paintChartLabel(
        canvas,
        'R',
        Offset(0, rRect.center.dy - 6),
        palette.fgFaint,
        fontSize: 10,
      );
      _barH(canvas, lRect, dbL, holdL);
      _barH(canvas, rRect, dbR, holdR);
    } else {
      const labelH = 13.0, barW = 11.0, gap = 6.0;
      final barsH = h - labelH;
      final totalW = barW * 2 + gap;
      final left = (w - totalW) / 2;
      final lRect = Rect.fromLTWH(left, 0, barW, barsH);
      final rRect = Rect.fromLTWH(left + barW + gap, 0, barW, barsH);
      _barV(canvas, lRect, dbL, holdL);
      _barV(canvas, rRect, dbR, holdR);
      paintChartLabel(
        canvas,
        'L',
        Offset(lRect.center.dx - 3, barsH + 1),
        palette.fgFaint,
        fontSize: 10,
      );
      paintChartLabel(
        canvas,
        'R',
        Offset(rRect.center.dx - 3, barsH + 1),
        palette.fgFaint,
        fontSize: 10,
      );
    }
  }

  @override
  bool shouldRepaint(_VuPainter old) =>
      old.axis != axis ||
      old.dbL != dbL ||
      old.dbR != dbR ||
      old.holdL != holdL ||
      old.holdR != holdR ||
      old.palette != palette;
}
