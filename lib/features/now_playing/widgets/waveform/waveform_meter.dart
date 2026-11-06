import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../studio/playback_issues.dart';
import '../../../../ui/chart_text.dart';
import '../../../../ui/layout/layout.dart';
import '../../../../ui/tokens.dart';
import '../../../../ui/widgets/round_icon_button.dart';
import '../../../../ui/widgets/studio_chip.dart';
import '../../../../util/duration_format.dart';
import '../../../../util/reactive.dart';
import '../../playback_scope.dart';
import '../double_tap_seek.dart';
import 'waveform_controls.dart';
import 'waveform_menu.dart';
import 'waveform_painter.dart';
import 'waveform_pan.dart';
import 'waveform_viewport.dart';

/// A tape-style meter: a time ruler on top, the track's envelope
/// below with the chapter starts and the A-B loop marked, and a scrollbar
/// at the bottom. It starts on the whole track; once zoomed in, the
/// playhead moves through the view and the view itself moves only when the
/// user scrolls.
///
/// Tap or drag to seek; on touch a single tap seeks once a double tap is
/// ruled out, and a double tap on either half skips 10 s. Right-click or
/// long press opens the menu (seek, loop points, chapters). The wheel and
/// trackpad pan the view; the pill zooms it. Fills its parent.
class WaveformMeter extends StatefulWidget {
  const WaveformMeter({super.key});

  /// Height of the time ruler at the top.
  static const double rulerHeight = 24;

  /// The seek step of the accessibility actions.
  static const Duration semanticStep = Duration(seconds: 5);

  /// Makes the stopwatch that runs the playhead on between position
  /// events. Tests that render frames swap in one that stands still, so
  /// the wall clock never shows in a frame.
  @visibleForTesting
  static Stopwatch Function() debugStopwatch = Stopwatch.new;

  @override
  State<WaveformMeter> createState() => _WaveformMeterState();
}

class _WaveformMeterState extends State<WaveformMeter>
    with SingleTickerProviderStateMixin, StreamListenerState<WaveformMeter> {
  /// The least meter width that fits the scrollbar beside the zoom pill.
  static const double _zoomRowWidth = 200;

  late PlayerApi _player;
  late CallGuard _guard;
  // Made when playback first starts, not lazily on first use: dispose
  // would otherwise make one for a meter that never played, and a ticker
  // cannot be made from a deactivated widget.
  Ticker? _ticker;
  Ticker get _frames => _ticker ??= createTicker((_) {
    if (mounted) setState(() {});
  });
  late final WaveformPan _pan = WaveformPan(
    onPan: _panBy,
    canPan: () => _view.canScroll,
  );

  /// The playhead between position events: [_anchor] plus the time the
  /// stopwatch has run, at the playback rate.
  final _sw = WaveformMeter.debugStopwatch();
  Duration _anchor = Duration.zero;
  double _rate = 1;
  bool _playWhenReady = false;
  bool _seekable = false;

  /// The whole track at first; the zoom pill narrows it.
  WaveformViewport _view = const WaveformViewport();
  Duration? _abA;
  Duration? _abB;
  List<Chapter> _chapters = const [];
  int? _currentChapter;

  bool _dragging = false;
  Duration _dragPos = Duration.zero;

  /// The pointer's x over the envelope (preview cursor); null when away.
  double? _hoverX;

  /// The envelope's width at the last layout, for the wheel and pan.
  double _width = 0;

  /// What the demuxer cache holds, drawn only for a network source.
  List<CacheRange> _cached = const [];

  @override
  void onSubscribe() {
    final scope = PlaybackScope.of(context);
    _player = scope.player;
    _guard = scope.guard;
    final s = _player.state;
    _anchor = s.position;
    _rate = s.rate;
    _playWhenReady = s.playWhenReady;
    _seekable = s.seekable;
    _view = _view.withSource(duration: s.duration);
    _abA = s.abLoopA;
    _abB = s.abLoopB;
    _chapters = s.chapters;
    _currentChapter = s.currentChapter;
    _cached = s.demuxerCacheState.seekableRanges;
    if (_playWhenReady) {
      _sw.start();
      _frames.start();
    }

    void update(VoidCallback change) {
      if (mounted) setState(change);
    }

    listen(_player.stream.position, (p) {
      _anchor = p;
      _sw
        ..reset()
        ..start();
      update(() {});
    });
    listen(_player.stream.duration, (d) {
      update(() => _view = _view.withSource(duration: d));
    });
    // A seek or a new track: the position just jumped to an exact value.
    // Re-sync the interpolated playhead so it never runs on from the old
    // position and then snaps back.
    listen(_player.stream.seekCompleted, (_) {
      _anchor = _player.state.position;
      _sw.reset();
      update(() {});
    });
    listen(_player.stream.rate, (r) => update(() => _rate = r));
    listen(
      _player.stream.demuxerCacheState,
      (c) => update(() => _cached = c.seekableRanges),
    );
    listen(_player.stream.seekable, (v) => update(() => _seekable = v));
    listen(_player.stream.waveform, (w) {
      update(
        () =>
            _view = w == null ? _view.withoutWave() : _view.withSource(wave: w),
      );
    });
    listen(_player.stream.abLoopA, (v) => update(() => _abA = v));
    listen(_player.stream.abLoopB, (v) => update(() => _abB = v));
    listen(_player.stream.chapters, (v) => update(() => _chapters = v));
    listen(
      _player.stream.currentChapter,
      (v) => update(() => _currentChapter = v),
    );
    listen(_player.stream.playWhenReady, (v) {
      _playWhenReady = v;
      if (v) {
        _sw
          ..reset()
          ..start();
        if (!_frames.isActive) _frames.start();
      } else {
        _anchor = _livePos();
        _sw.stop();
        if (_ticker?.isActive ?? false) _ticker!.stop();
      }
      update(() {});
    });
  }

  @override
  void dispose() {
    _pan.stop();
    _ticker?.dispose();
    super.dispose();
  }

  /// The smooth playhead, interpolated between position events.
  Duration _livePos() {
    if (!_playWhenReady || !_sw.isRunning) return _anchor;
    final micros =
        _anchor.inMicroseconds + (_sw.elapsedMicroseconds * _rate).round();
    var d = Duration(microseconds: micros);
    if (d < Duration.zero) d = Duration.zero;
    final dur = _view.duration;
    if (dur > Duration.zero && d > dur) d = dur;
    return d;
  }

  /// Live streams seek within the cached window even though mpv flags the
  /// stream as not seekable; a track needs a known length.
  bool get _canSeek =>
      _view.live || (_seekable && _view.duration > Duration.zero);

  void _seekTo(Duration target) {
    setState(() {
      _dragPos = target;
      _anchor = target;
    });
    // Sample-accurate: this is a precise editor, where an exact landing
    // (instead of the nearest keyframe) matters.
    _guard(() => _player.seek(target, exact: true));
  }

  void _seekToX(double x) => _seekTo(_view.timeAtX(x, _width));

  bool _panBy(double pixels) {
    if (!mounted) return false;
    final next = _view.scrollByPixels(pixels, _width);
    if (next.leftRel == _view.leftRel &&
        next.followsLive == _view.followsLive) {
      return false;
    }
    setState(() => _view = next);
    return true;
  }

  /// Zooms around the playhead while it is in view.
  void _zoom(double factor) =>
      setState(() => _view = _view.zoomBy(factor, around: _livePos()));

  void _openMenu(Offset global, double x) {
    showWaveformMenu(
      context,
      player: _player,
      guard: _guard,
      at: _view.timeAtX(x, _width),
      position: global,
    );
  }

  Widget _envelope(BuildContext context, bool touch) {
    final canSeek = _canSeek;
    final canvas = LayoutBuilder(
      builder: (context, c) {
        _width = c.maxWidth;
        return Listener(
          onPointerSignal: _pan.signal,
          onPointerPanZoomStart: (_) => _pan.start(),
          onPointerPanZoomUpdate: _pan.update,
          onPointerPanZoomEnd: (_) => _pan.end(),
          child: MouseRegion(
            cursor: canSeek ? SystemMouseCursors.precise : MouseCursor.defer,
            onHover: (e) => setState(() => _hoverX = e.localPosition.dx),
            onExit: (_) => setState(() => _hoverX = null),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // The trackpad is left out: a two-finger swipe must pan the
              // view (through the Listener above), not be claimed as a
              // drag that seeks. Trackpad clicks arrive as mouse events.
              supportedDevices: const {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.stylus,
                PointerDeviceKind.invertedStylus,
                PointerDeviceKind.unknown,
              },
              // A pointer seeks on press; touch waits for the tap to be a
              // single one, so a double tap only skips.
              onTapDown: canSeek && !touch
                  ? (d) => _seekToX(d.localPosition.dx)
                  : null,
              onTapUp: canSeek && touch
                  ? (d) => _seekToX(d.localPosition.dx)
                  : null,
              onSecondaryTapUp: canSeek
                  ? (d) => _openMenu(d.globalPosition, d.localPosition.dx)
                  : null,
              onLongPressStart: canSeek
                  ? (d) => _openMenu(d.globalPosition, d.localPosition.dx)
                  : null,
              onHorizontalDragStart: canSeek
                  ? (d) {
                      setState(() => _dragging = true);
                      _seekToX(d.localPosition.dx);
                    }
                  : null,
              onHorizontalDragUpdate: canSeek
                  ? (d) => _seekToX(d.localPosition.dx)
                  : null,
              onHorizontalDragEnd: canSeek
                  ? (_) => setState(() => _dragging = false)
                  : null,
              child: CustomPaint(
                size: Size.infinite,
                painter: WaveformPainter(
                  view: _view,
                  position: _dragging ? _dragPos : _livePos(),
                  rulerHeight: WaveformMeter.rulerHeight,
                  palette: Tokens.palette,
                  hoverX: canSeek && !_dragging ? _hoverX : null,
                  abA: _abA,
                  abB: _abB,
                  chapters: _chapters,
                  currentChapter: _currentChapter,
                  cached: _player.state.demuxerViaNetwork ? _cached : const [],
                  scaler: chartTextScaler(context),
                ),
              ),
            ),
          ),
        );
      },
    );
    return DoubleTapSeek(
      enabled: touch && canSeek,
      onSeek: (by) => _guard(() => _player.seek(by, relative: true)),
      child: canvas,
    );
  }

  @override
  Widget build(BuildContext context) {
    final touch = context.layout.isTouch;
    final canSeek = _canSeek;
    final dur = _view.duration;
    String at(Duration d) {
      final clamped = d < Duration.zero ? Duration.zero : (d > dur ? dur : d);
      return '${formatDuration(clamped)} of ${formatDuration(dur)}';
    }

    const step = WaveformMeter.semanticStep;
    final zoom = WaveformZoomControls(
      canZoomIn: _view.canZoomIn,
      canZoomOut: _view.canZoomOut,
      onZoomIn: () => _zoom(WaveformViewport.zoomStep),
      onZoomOut: () => _zoom(1 / WaveformViewport.zoomStep),
    );
    // The zoom pill sits beside the scrollbar, never over the waveform,
    // on every input. On touch the scrollbar is a full touch target tall.
    final scrollBar = WaveformScrollBar(
      height: touch ? context.layout.minTap : 16,
      thickness: touch ? 12 : 8,
      enabled: _view.canScroll,
      viewStart: _view.leftRel,
      visibleSecs: _view.visibleSecs,
      maxStart: _view.maxStart,
      timelineSecs: _view.timelineSecs,
      onChanged: (v) => setState(() => _view = _view.scrollTo(v)),
    );
    return Semantics(
      container: true,
      slider: true,
      label: 'Waveform and position',
      value: canSeek ? at(_anchor) : 'Not seekable',
      increasedValue: canSeek ? at(_anchor + step) : null,
      decreasedValue: canSeek ? at(_anchor - step) : null,
      onIncrease: canSeek
          ? () => _guard(() => _player.seek(step, relative: true))
          : null,
      onDecrease: canSeek
          ? () => _guard(() => _player.seek(-step, relative: true))
          : null,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _envelope(context, touch)),
                Positioned(
                  top: WaveformMeter.rulerHeight + Tokens.s8,
                  left: Tokens.s8,
                  child: WaveformScanIndicator(
                    visible: _view.wave?.decoding == true,
                    fraction: _view.wave?.decodeFraction,
                  ),
                ),
              ],
            ),
          ),
          // A meter too narrow for both keeps the scrollbar; the wheel,
          // the pinch and the keyboard still zoom. Scrolled back on a live
          // stream it keeps the way to the live end, as an icon.
          LayoutBuilder(
            builder: (context, c) => c.maxWidth < _zoomRowWidth
                ? Row(
                    children: [
                      Expanded(child: scrollBar),
                      if (_view.live && !_view.followsLive) ...[
                        const SizedBox(width: Tokens.s4),
                        RoundIconButton(
                          icon: Icons.fast_forward_rounded,
                          size: Tokens.iconMd,
                          tooltip: 'Follow the live end',
                          onTap: () => setState(() => _view = _view.toLive()),
                        ),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: scrollBar),
                      // Scrolled back on a live stream: back to the
                      // newest audio, following it again.
                      if (_view.live && !_view.followsLive) ...[
                        const SizedBox(width: Tokens.s8),
                        StudioChip(
                          label: 'Live',
                          icon: Icons.fast_forward_rounded,
                          tooltip: 'Follow the live end',
                          onTap: () => setState(() => _view = _view.toLive()),
                        ),
                      ],
                      const SizedBox(width: Tokens.s8),
                      zoom,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
