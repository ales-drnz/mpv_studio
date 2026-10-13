import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../audio/pcm_analysis.dart';
import '../../../ui/chart_text.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../rack_environment.dart';

/// A stage's before and after view: the input spectrum as a faint line,
/// the output spectrum filled over it, and the input and output levels
/// with their difference, the way a plugin's analyzer overlays them.
///
/// It listens to `stream.tap(filter, instance:, side:)` only while
/// [active], which the rack grants to a few open stages, since libmpv
/// taps eight stages at a time.
class StageMeters extends StatefulWidget {
  final AudioFilter filter;
  final int instance;
  final bool active;

  /// Why there is nothing to show while not [active].
  final String idleText;

  const StageMeters({
    super.key,
    required this.filter,
    required this.instance,
    required this.active,
    this.idleText = 'Meters off',
  });

  @override
  State<StageMeters> createState() => _StageMetersState();
}

class _Side {
  BandProcessor? bands;
  Float32List? shown;
  double peakDb = _floor;
  double rmsDb = _floor;
  StreamSubscription<PcmFrame>? sub;

  void reset() {
    shown = null;
    peakDb = _floor;
    rmsDb = _floor;
  }
}

const double _floor = -60;

class _StageMetersState extends State<StageMeters> {
  final _pre = _Side();
  final _post = _Side();
  final _tick = ValueNotifier<int>(0);
  TapSource? _taps;
  SpectrumSettings? _spectrum;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final env = RackEnvironment.maybeOf(context);
    if (env?.taps != _taps || env?.spectrum != _spectrum) {
      _taps = env?.taps;
      _spectrum = env?.spectrum;
      _resubscribe();
    }
  }

  @override
  void didUpdateWidget(StageMeters old) {
    super.didUpdateWidget(old);
    if (old.filter != widget.filter ||
        old.instance != widget.instance ||
        old.active != widget.active) {
      _resubscribe();
    }
  }

  void _resubscribe() {
    _cancel();
    final taps = _taps;
    if (!widget.active || taps == null) return;
    for (final (side, s) in [(TapSide.pre, _pre), (TapSide.post, _post)]) {
      s.bands = _spectrum == null ? null : BandProcessor(_spectrum!);
      s.sub = taps(widget.filter, widget.instance, side).listen((pcm) {
        _onFrame(s, pcm);
      });
    }
  }

  void _onFrame(_Side s, PcmFrame pcm) {
    if (!mounted) return;
    final peak = amplitudeToDb(framePeak(pcm), floorDb: _floor);
    final rms = amplitudeToDb(frameRms(pcm), floorDb: _floor);
    s.peakDb = emaTowards(s.peakDb, peak, peak > s.peakDb ? 0.6 : 0.08);
    s.rmsDb = emaTowards(s.rmsDb, rms, 0.25);
    final fft = s.bands?.process(pcm);
    if (fft != null) s.shown = Float32List.fromList(fft.bands);
    _tick.value++;
  }

  void _cancel() {
    for (final s in [_pre, _post]) {
      s.sub?.cancel();
      s.sub = null;
      s.reset();
    }
    _tick.value++;
  }

  @override
  void dispose() {
    _cancel();
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Stage meters, before and after',
      value: widget.active ? null : widget.idleText,
      child: Container(
        height: context.layout.isShort ? 52 : 72,
        decoration: ShapeDecoration(
          color: Tokens.surface3,
          shape: Tokens.shape(Tokens.rSm),
        ),
        child: widget.active
            ? RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MetersPainter(_pre, _post, _tick),
                ),
              )
            : Center(
                child: ExcludeSemantics(
                  child: Text(widget.idleText, style: Tokens.caption),
                ),
              ),
      ),
    );
  }
}

class _MetersPainter extends CustomPainter {
  final _Side pre;
  final _Side post;
  _MetersPainter(this.pre, this.post, Listenable tick) : super(repaint: tick);

  static const _readoutW = 92.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(6, 6, size.width - _readoutW, size.height - 6);
    if (plot.width > 8) {
      _bands(canvas, plot, pre.shown, fill: false);
      _bands(canvas, plot, post.shown, fill: true);
    }
    // Readouts: IN, OUT and the change.
    final x = size.width - _readoutW + 8;
    // Three 10 px lines spread over the height.
    final step = (size.height - 30) / 4;
    final inDb = pre.rmsDb;
    final outDb = post.rmsDb;
    paintChartLabel(
      canvas,
      'IN  ${_db(inDb)}',
      Offset(x, step),
      Tokens.fgDim,
      fontSize: 10,
    );
    paintChartLabel(
      canvas,
      'OUT ${_db(outDb)}',
      Offset(x, 2 * step + 10),
      Tokens.accent,
      fontSize: 10,
    );
    final silent = inDb <= _floor + 1 && outDb <= _floor + 1;
    final delta = outDb - inDb;
    paintChartLabel(
      canvas,
      silent
          ? 'no signal'
          : '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} dB',
      Offset(x, 3 * step + 20),
      silent
          ? Tokens.fgFaint
          : delta.abs() < 0.5
          ? Tokens.fgDim
          : (delta > 0 ? Tokens.amber : Tokens.green),
      fontSize: 10,
    );
  }

  static String _db(double db) =>
      db <= _floor + 0.5 ? '  -inf' : db.toStringAsFixed(1).padLeft(6);

  void _bands(Canvas canvas, Rect r, Float32List? bands, {required bool fill}) {
    if (bands == null || bands.length < 2) return;
    final n = bands.length;
    final path = Path();
    for (var i = 0; i < n; i++) {
      final x = r.left + r.width * i / (n - 1);
      final y = r.bottom - r.height * bands[i].clamp(0.0, 1.0);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(r.right, r.bottom)
        ..lineTo(r.left, r.bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = Tokens.accent.withValues(alpha: 0.18),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Tokens.accent,
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Tokens.fgDim.withValues(alpha: 0.7),
      );
    }
  }

  @override
  bool shouldRepaint(_MetersPainter old) => old.pre != pre || old.post != post;
}
