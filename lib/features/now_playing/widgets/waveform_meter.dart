import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';
import '../../../util/duration_format.dart';
import '../../../util/reactive.dart';

/// A Reaper-style tape meter: a time ruler with values on top, the track
/// waveform below it, and a fixed-zoom view the user pans with a
/// horizontal scrollbar. The playhead advances with playback through the
/// view (it does NOT auto-follow — the view only moves when you scroll).
///
/// Fills its parent's height, so the surrounding layout can make it
/// resizable.
class WaveformMeter extends StatefulWidget {
  /// Seconds of audio visible across the full width.
  final double windowSeconds;

  const WaveformMeter({super.key, this.windowSeconds = 30});

  /// Height of the time-ruler strip at the top.
  static const double rulerHeight = 22;

  /// Height of the bottom scrollbar strip.
  static const double scrollbarHeight = 14;

  @override
  State<WaveformMeter> createState() => _WaveformMeterState();
}

class _WaveformMeterState extends State<WaveformMeter>
    with SingleTickerProviderStateMixin, StreamListenerState<WaveformMeter> {
  late final Player _player;
  late final Ticker _ticker;
  final _sw = Stopwatch();

  Duration _anchor = Duration.zero;
  Duration _dur = Duration.zero;
  double _rate = 1;

  /// Seconds visible across the full width — the horizontal zoom level.
  /// Seeded from the widget, then driven by the zoom controls.
  late double _windowSeconds = widget.windowSeconds;

  /// Bounds for the zoom range.
  static const double _minWindow = 5;
  bool _playWhenReady = false;
  bool _seekable = false;

  /// Current A-B loop markers (mpv `ab-loop-a` / `ab-loop-b`), drawn on the
  /// meter and set/cleared from the right-click / long-press context menu.
  Duration? _abA;
  Duration? _abB;

  /// The track's min/max envelope from `stream.waveform`. The engine
  /// fills this transparently: a full envelope up-front for local files,
  /// or one that grows during playback for network sources (segmented /
  /// transcode / live). Either way the meter just renders what it gets.
  WaveformData? _wave;

  bool _dragging = false;
  Duration _dragPos = Duration.zero;

  /// Mouse hover X over the waveform (preview cursor); null when away.
  double? _hoverX;

  /// First visible second of the view. Driven only by the scrollbar.
  double _viewStart = 0;

  /// Live only: the view's left edge in ABSOLUTE media time. The live view
  /// does NOT auto-follow — it stays exactly where the user left it (anchored
  /// to the content even as the cache window slides), defaulting to the start
  /// of the cached window. Navigate the history with the scrollbar.
  double _viewLeftAbs = 0;

  @override
  void onSubscribe() {
    _player = PlayerScope.of(context);
    final s = _player.state;
    _anchor = s.position;
    _dur = s.duration;
    _rate = s.rate;
    _playWhenReady = s.playWhenReady;
    _seekable = s.seekable;
    _abA = s.abLoopA;
    _abB = s.abLoopB;

    _ticker = createTicker((_) {
      if (mounted) setState(() {});
    });
    if (_playWhenReady) {
      _sw.start();
      _ticker.start();
    }

    listen(_player.stream.position, (p) {
      _anchor = p;
      _sw
        ..reset()
        ..start();
      if (mounted) setState(() {});
    });
    listen(_player.stream.duration, (d) {
      if (!mounted) return;
      setState(() {
        if (d != _dur) {
          // New source → reset the view to the start.
          _viewStart = 0;
          _viewLeftAbs = 0;
        }
        _dur = d;
      });
    });
    // PLAYBACK_RESTART (mpv's canonical discontinuity event — a seek OR a new
    // track): the position has just jumped to an authoritative value. Re-sync
    // the interpolated playhead to it so it never keeps running from the
    // previous track's (or pre-seek) position and then snaps back to align.
    listen(_player.stream.seekCompleted, (_) {
      _anchor = _player.state.position;
      _sw.reset();
      if (mounted) setState(() {});
    });
    listen(_player.stream.rate, (r) {
      if (mounted) setState(() => _rate = r);
    });
    listen(_player.stream.seekable, (v) {
      if (mounted) setState(() => _seekable = v);
    });
    listen(_player.stream.waveform, (w) {
      if (mounted) setState(() => _wave = w);
    });
    listen(_player.stream.abLoopA, (v) {
      if (mounted) setState(() => _abA = v);
    });
    listen(_player.stream.abLoopB, (v) {
      if (mounted) setState(() => _abB = v);
    });
    listen(_player.stream.playWhenReady, (v) {
      _playWhenReady = v;
      if (v) {
        _sw
          ..reset()
          ..start();
        if (!_ticker.isActive) _ticker.start();
      } else {
        _anchor = _livePos();
        _sw.stop();
        if (_ticker.isActive) _ticker.stop();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stopFlick();
    _ticker.dispose();
    super.dispose();
  }

  /// Smooth playhead position, interpolated between position emits.
  Duration _livePos() {
    if (!_playWhenReady || !_sw.isRunning) return _anchor;
    final micros =
        _anchor.inMicroseconds + (_sw.elapsedMicroseconds * _rate).round();
    var d = Duration(microseconds: micros);
    if (d < Duration.zero) d = Duration.zero;
    if (_dur > Duration.zero && d > _dur) d = _dur;
    return d;
  }

  double get _durSecs => _dur.inMicroseconds / 1e6;

  /// True when the engine is feeding a live (rolling, cache-aligned)
  /// envelope: there's no fixed track length — the window slides with the
  /// demuxer cache. The playhead sits at the true playback position (it does
  /// NOT auto-follow the tail); pan the history manually with the scrollbar.
  bool get _live => _wave?.live ?? false;

  /// Absolute media time of the timeline's left origin: the start of the
  /// cached window for a live stream, else 0.
  double get _originSecs => _live ? _wave!.start.inMicroseconds / 1e6 : 0;

  /// Timeline length for the ruler + scroll range. Falls back to a
  /// 5-minute placeholder when nothing is loaded, so the meter is always
  /// populated with a usable timeline.
  static const double _placeholderSecs = 300;
  double get _timelineSecs {
    if (_live) {
      final span = _wave!.duration.inMicroseconds / 1e6; // cached window
      return span > _minWindow ? span : _minWindow;
    }
    return _durSecs > 0 ? _durSecs : _placeholderSecs;
  }

  double get _maxStart =>
      (_timelineSecs - _windowSeconds).clamp(0, _timelineSecs);

  /// Whether the non-live timeline has off-screen history to pan to (zoomed
  /// in past the track length). Live panning is handled separately by the
  /// scrollbar (enabled whenever [_maxStart] > 0) and never auto-follows the
  /// tail, so it does not go through this getter.
  bool get _hasScroll => !_live && _maxStart > 0;

  double get _visibleSecs {
    // Live keeps a FIXED-width window so the envelope grows into it from the
    // left (occupying only the elapsed fraction) and advances with the
    // playhead, instead of being stretched across the whole width while the
    // cache is still short.
    if (_live) return _windowSeconds;
    return _hasScroll ? _windowSeconds : _timelineSecs;
  }

  /// Left edge of the view, relative to [_originSecs]. Live anchors to the
  /// user's absolute position (defaulting to the start of the cache, never
  /// auto-following the tail); a normal track uses the scrolled position.
  double get _leftRel {
    if (_live) return (_viewLeftAbs - _originSecs).clamp(0, _maxStart);
    return _viewStart.clamp(0, _maxStart);
  }

  /// Absolute media time at the left edge of the view.
  double get _viewStartAbs => _originSecs + _leftRel;

  /// Multiplies the zoom level (factor < 1 zooms in), keeping the current
  /// view centre fixed and the view start within range.
  void _zoomBy(double factor) {
    if (_live) {
      // Just change the window width; the user's absolute anchor is
      // preserved and re-clamped on the next build.
      setState(() {
        _windowSeconds =
            (_windowSeconds * factor).clamp(_minWindow, _timelineSecs);
      });
      return;
    }
    final center = _viewStart + _visibleSecs / 2;
    setState(() {
      _windowSeconds =
          (_windowSeconds * factor).clamp(_minWindow, _timelineSecs);
      _viewStart = (center - _visibleSecs / 2).clamp(0, _maxStart);
    });
  }

  /// Absolute media time at horizontal pixel [localX], clamped to the seekable
  /// region. Live clamps to the cached window (the only seekable region); a
  /// normal track clamps to [0, duration]. The live upper bound is the true
  /// cached end (`_wave.end`), not the placeholder-floored `_timelineSecs`, so
  /// a sub-`_minWindow` cache can't map a tap past what's actually buffered.
  Duration _timeAtX(double localX, double width) {
    // A zero-width meter (first layout pass, collapsed pane) makes pxPerSec 0
    // or _visibleSecs 0, so tAbs becomes Infinity/NaN and `.round().toInt()`
    // throws UnsupportedError — crashing the gesture handler. Map to the
    // region floor instead.
    if (width <= 0 || !_visibleSecs.isFinite || _visibleSecs <= 0) {
      return Duration(microseconds: _live ? _wave!.start.inMicroseconds : 0);
    }
    final pxPerSec = width / _visibleSecs;
    final tAbs = _viewStartAbs + localX / pxPerSec;
    if (!tAbs.isFinite) {
      return Duration(microseconds: _live ? _wave!.start.inMicroseconds : 0);
    }
    final loUs = _live ? _wave!.start.inMicroseconds : 0;
    final hiUs = _live ? _wave!.end.inMicroseconds : _dur.inMicroseconds;
    final micros = (tAbs * 1e6).round().clamp(loUs, hiUs).toInt();
    return Duration(microseconds: micros);
  }

  void _seekTo(Duration target) {
    setState(() {
      _dragPos = target;
      _anchor = target;
    });
    // Sample-accurate landing — this is a precise waveform editor, exactly
    // where exact (vs keyframe) seeking matters.
    PlayerScope.issuesOf(context)
        .guard(() => _player.seek(target, exact: true));
  }

  void _seekToX(double localX, double width) =>
      _seekTo(_timeAtX(localX, width));

  /// Right-click / long-press context menu at the clicked point: set/clear the
  /// A-B loop markers (the loop runs once both are set), seek there, and jump
  /// chapters. Replaces the old Settings "A-B loop" panel.
  Future<void> _openMenu(Offset globalPos, double localX, double width) async {
    final time = _timeAtX(localX, width);
    final hasLoop = _abA != null || _abB != null;
    final chapters = _player.state.chapters;
    final cur = _player.state.currentChapter ?? 0;
    final entries = <_MenuEntry>[
      _MenuEntry(
          'a', Icons.flag_outlined, 'Set loop A here', formatDuration(time)),
      _MenuEntry(
          'b', Icons.flag_rounded, 'Set loop B here', formatDuration(time)),
      if (hasLoop)
        _MenuEntry('clear', Icons.layers_clear_rounded, 'Clear A-B loop', null),
      if (chapters.isNotEmpty) ...[
        _MenuEntry.divider,
        _MenuEntry(
            'prevch', Icons.skip_previous_rounded, 'Previous chapter', null,
            enabled: cur > 0),
        _MenuEntry('nextch', Icons.skip_next_rounded, 'Next chapter', null,
            enabled: cur < chapters.length - 1),
      ],
    ];

    // Root navigator: its overlay is full-screen, so it shares the coordinate
    // space of `globalPos`. (The page sits in a branch navigator whose overlay
    // is offset by the sidebar/header — pushing there would place the menu far
    // from the cursor.)
    final choice = await Navigator.of(context, rootNavigator: true)
        .push<String>(_InstantMenuRoute(position: globalPos, entries: entries));
    if (!mounted) return;
    // The chapter list can change while the menu is open, and a setter
    // throws on a stale index: show it instead of losing it.
    await PlayerScope.issuesOf(context).guard(() async {
      switch (choice) {
        case 'a':
          await _player.setAbLoopA(time);
        case 'b':
          await _player.setAbLoopB(time);
        case 'clear':
          await _player.setAbLoopA(null);
          await _player.setAbLoopB(null);
        case 'prevch':
          await _player.setChapter(cur - 1);
        case 'nextch':
          await _player.setChapter(cur + 1);
      }
    });
  }

  void _setViewStart(double v) {
    setState(() => _viewStart = v.clamp(0, _maxStart));
  }

  // Trackpad pan inertia. macOS delivers a trackpad swipe as a pan-zoom GESTURE
  // (no OS scroll momentum), so a flick is simulated on release: a friction
  // decay whose distance scales with the zoom, like the live pan.
  Timer? _flick;
  double _flickVel = 0; // view-direction px/sec at the last pan update
  Duration? _lastPanTs;

  void _stopFlick() {
    _flick?.cancel();
    _flick = null;
  }

  /// Mouse wheel / trackpad scroll pans the view horizontally (it never seeks).
  /// A vertical wheel and a horizontal trackpad swipe both map to left/right;
  /// the pixel delta becomes seconds via the current zoom, then pans like the
  /// scrollbar would.
  void _onScroll(PointerSignalEvent signal, double width) {
    if (signal is! PointerScrollEvent || _maxStart <= 0) return;
    _stopFlick(); // a real scroll signal (incl. any OS momentum) takes over
    final d = signal.scrollDelta;
    final delta = d.dx.abs() >= d.dy.abs() ? d.dx : d.dy;
    if (delta == 0 || width <= 0 || _visibleSecs <= 0) return;
    _onScrub((_leftRel + delta / (width / _visibleSecs)).clamp(0.0, _maxStart));
  }

  /// Trackpad two-finger swipe. macOS delivers it as a pan-zoom GESTURE (not a
  /// scroll signal), so the seek drag ignores the trackpad and the pan is
  /// handled here: panning like the wheel, while tracking the release velocity
  /// so the gesture can coast (see [_startFlick]).
  void _onPanZoom(PointerPanZoomUpdateEvent e, double width) {
    if (_maxStart <= 0 || width <= 0 || _visibleSecs <= 0) return;
    // Trackpad pan follows finger movement — the opposite sign to the wheel's
    // content-scroll convention — so negate to match _onScroll's direction.
    final comp =
        e.panDelta.dx.abs() >= e.panDelta.dy.abs() ? e.panDelta.dx : e.panDelta.dy;
    if (_lastPanTs != null) {
      final dt = (e.timeStamp - _lastPanTs!).inMicroseconds / 1e6;
      if (dt > 1e-4) _flickVel = -comp / dt;
    }
    _lastPanTs = e.timeStamp;
    if (comp == 0) return;
    _onScrub((_leftRel - comp / (width / _visibleSecs)).clamp(0.0, _maxStart));
  }

  /// Coast after a trackpad flick: decay the release velocity with friction and
  /// keep panning until it falls below a threshold or hits an edge.
  void _startFlick(double width) {
    _stopFlick();
    var vel = _flickVel; // view-direction px/sec
    if (vel.abs() < 80 || _maxStart <= 0) return;
    _flick = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted || _maxStart <= 0 || width <= 0 || _visibleSecs <= 0) {
        _stopFlick();
        return;
      }
      vel *= 0.95; // friction per frame (~60 fps)
      if (vel.abs() < 30) {
        _stopFlick();
        return;
      }
      final next = (_leftRel + (vel * 0.016) / (width / _visibleSecs))
          .clamp(0.0, _maxStart);
      if (next == _leftRel) {
        _stopFlick(); // hit an edge
        return;
      }
      _onScrub(next);
    });
  }

  /// Scrollbar drag. A normal track moves the view; a live stream pans
  /// through the cached history, anchored in absolute media time so the
  /// position holds as the cache window slides.
  void _onScrub(double v) {
    if (!_live) {
      _setViewStart(v);
      return;
    }
    setState(() => _viewLeftAbs = _originSecs + v.clamp(0, _maxStart));
  }

  @override
  Widget build(BuildContext context) {
    final pos = _dragging ? _dragPos : _livePos();
    // Live is seekable within its cached window even though mpv flags the
    // whole stream non-seekable; a normal track needs a known duration.
    final canSeek = _live || (_seekable && _dur > Duration.zero);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final w = c.maxWidth;
                    return Listener(
                      onPointerSignal: (s) => _onScroll(s, w),
                      onPointerPanZoomStart: (_) {
                        _stopFlick();
                        _lastPanTs = null;
                        _flickVel = 0;
                      },
                      onPointerPanZoomUpdate: (e) => _onPanZoom(e, w),
                      onPointerPanZoomEnd: (_) => _startFlick(w),
                      child: MouseRegion(
                        cursor: canSeek
                            ? SystemMouseCursors.precise
                            : MouseCursor.defer,
                        onHover: (e) {
                          if (mounted) {
                            setState(() => _hoverX = e.localPosition.dx);
                          }
                        },
                        onExit: (_) {
                          if (mounted) setState(() => _hoverX = null);
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          // Exclude the trackpad from the seek gestures: a
                          // two-finger trackpad swipe must PAN the view (it
                          // falls through to the scroll handler, like the mouse
                          // wheel), not be claimed as a horizontal drag and
                          // seek. Trackpad CLICKS arrive as mouse events, so
                          // tap-to-seek still works.
                          supportedDevices: const {
                            PointerDeviceKind.mouse,
                            PointerDeviceKind.touch,
                            PointerDeviceKind.stylus,
                            PointerDeviceKind.invertedStylus,
                            PointerDeviceKind.unknown,
                          },
                          onTapDown: canSeek
                              ? (d) => _seekToX(d.localPosition.dx, w)
                              : null,
                          // Right-click (desktop) / long-press (touch) → the
                          // A-B loop + seek + chapter context menu.
                          onSecondaryTapDown: canSeek
                              ? (d) => _openMenu(
                                  d.globalPosition, d.localPosition.dx, w)
                              : null,
                          onLongPressStart: canSeek
                              ? (d) => _openMenu(
                                  d.globalPosition, d.localPosition.dx, w)
                              : null,
                          onHorizontalDragStart: canSeek
                              ? (d) {
                                  setState(() => _dragging = true);
                                  _seekToX(d.localPosition.dx, w);
                                }
                              : null,
                          onHorizontalDragUpdate: canSeek
                              ? (d) => _seekToX(d.localPosition.dx, w)
                              : null,
                          onHorizontalDragEnd: canSeek
                              ? (_) => setState(() => _dragging = false)
                              : null,
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _MeterPainter(
                              wave: _wave,
                              pos: pos,
                              live: _live,
                              originSecs: _originSecs,
                              timelineSecs: _timelineSecs,
                              viewStartAbs: _viewStartAbs,
                              visibleSecs: _visibleSecs,
                              rulerHeight: WaveformMeter.rulerHeight,
                              hoverX: (canSeek && !_dragging) ? _hoverX : null,
                              abA: _abA,
                              abB: _abB,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Horizontal zoom for the waveform and playhead timeline.
              Positioned(
                top: WaveformMeter.rulerHeight + 4,
                right: 6,
                child: _ZoomControls(
                  canZoomIn: _windowSeconds > _minWindow,
                  canZoomOut: _windowSeconds < _timelineSecs,
                  onZoomIn: () => _zoomBy(0.6),
                  onZoomOut: () => _zoomBy(1 / 0.6),
                ),
              ),
              // Live scan progress (the waveform decode IS the shared analysis
              // pass). Top-left so it never collides with the zoom pill; fades
              // out when the scan settles. An overlay, so it causes no reflow.
              Positioned(
                top: WaveformMeter.rulerHeight + 6,
                left: 8,
                child: _ScanIndicator(
                  visible: _wave?.decoding == true,
                  fraction: _wave?.decodeFraction,
                ),
              ),
            ],
          ),
        ),
        _HScrollBar(
          // Scrollable whenever there's history off-screen — including live,
          // where dragging pans through the cached window (no auto-follow).
          enabled: _maxStart > 0,
          viewStart: _leftRel,
          windowSeconds: _visibleSecs,
          maxStart: _maxStart,
          durSecs: _timelineSecs,
          onChanged: _onScrub,
        ),
      ],
    );
  }
}

/// A compact zoom pill (out · in) overlaid on the waveform meter.
class _ZoomControls extends StatelessWidget {
  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const _ZoomControls({
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomBtn(
            icon: Icons.remove_rounded,
            tooltip: 'Zoom out',
            enabled: canZoomOut,
            onTap: onZoomOut,
          ),
          _ZoomBtn(
            icon: Icons.add_rounded,
            tooltip: 'Zoom in',
            enabled: canZoomIn,
            onTap: onZoomIn,
          ),
        ],
      ),
    );
  }
}

/// A compact live-scan progress chip overlaid on the meter: a label, a thin
/// bar, and a percent. The waveform decode IS the shared analysis pass (the
/// loudness scan, when enabled, rides it in lockstep), so the waveform decode
/// fraction drives it. Determinate when that fraction is known, indeterminate
/// otherwise. Fades out when no scan is running; the bar glides between updates
/// (the worker regions seal in clumps) and the percent is fixed-width so the
/// chip never jitters as it grows.
class _ScanIndicator extends StatelessWidget {
  final bool visible;
  final double? fraction;
  const _ScanIndicator({required this.visible, this.fraction});

  @override
  Widget build(BuildContext context) {
    final f = visible ? fraction : 0.0;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: Tokens.s8, vertical: Tokens.s4),
          decoration: ShapeDecoration(
            color: Tokens.surface2,
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scanning audio', style: Tokens.caption),
              const SizedBox(width: Tokens.s8),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: f == null
                      ? const LinearProgressIndicator(
                          minHeight: 3,
                          color: Tokens.accent,
                          backgroundColor: Tokens.line2,
                        )
                      : TweenAnimationBuilder<double>(
                          tween: Tween(end: f.clamp(0.0, 1.0)),
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          builder: (_, v, _) => LinearProgressIndicator(
                            value: v,
                            minHeight: 3,
                            color: Tokens.accent,
                            backgroundColor: Tokens.line2,
                          ),
                        ),
                ),
              ),
              if (f != null) ...[
                const SizedBox(width: Tokens.s8),
                SizedBox(
                  // Wide enough for "100%" so it never wraps to a second line
                  // at the end of the scan; fixed so the chip never jitters.
                  width: 38,
                  child: Text(
                    '${(f * 100).round()}%',
                    style: Tokens.numeric,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _ZoomBtn({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              icon,
              size: 16,
              color: enabled ? Tokens.fgDim : Tokens.fgFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _HScrollBar extends StatefulWidget {
  final bool enabled;
  final double viewStart;
  final double windowSeconds;
  final double maxStart;
  final double durSecs;
  final ValueChanged<double> onChanged;

  const _HScrollBar({
    required this.enabled,
    required this.viewStart,
    required this.windowSeconds,
    required this.maxStart,
    required this.durSecs,
    required this.onChanged,
  });

  @override
  State<_HScrollBar> createState() => _HScrollBarState();
}

class _HScrollBarState extends State<_HScrollBar> {
  bool _hoverThumb = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: WaveformMeter.scrollbarHeight,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final frac = (widget.durSecs <= 0
                  ? 1.0
                  : widget.windowSeconds / widget.durSecs)
              .clamp(0.06, 1.0);
          final thumbW = (w * frac).clamp(28.0, w);
          final avail = w - thumbW;
          final thumbX = widget.maxStart > 0
              ? (widget.viewStart / widget.maxStart) * avail
              : 0.0;

          void setFromX(double x) {
            if (!widget.enabled || avail <= 0) return;
            final tx = (x - thumbW / 2).clamp(0.0, avail);
            widget.onChanged((tx / avail) * widget.maxStart);
          }

          // Thumb fills with the app accent while hovered (a draggable handle
          // cue); a recessed track colour otherwise.
          final thumbColour = !widget.enabled
              ? Tokens.surface2
              : _hoverThumb
                  ? Tokens.accent
                  : Tokens.surface3;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => setFromX(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => setFromX(d.localPosition.dx),
            // Flush, square strip — a recessed track colour so it reads as a
            // control, with a hairline above separating it from the waveform.
            child: Container(
              decoration: const BoxDecoration(
                color: Tokens.surface2,
                border: Border(top: BorderSide(color: Tokens.line, width: 1)),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: thumbX,
                    top: 0,
                    bottom: 0,
                    width: thumbW,
                    child: MouseRegion(
                      cursor: widget.enabled
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      onEnter: widget.enabled
                          ? (_) => setState(() => _hoverThumb = true)
                          : null,
                      onExit: (_) => setState(() => _hoverThumb = false),
                      child: Container(
                        decoration: BoxDecoration(color: thumbColour),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The vertical extent of one waveform bar: [top] to [bottom] spans the
/// bin's min and max peaks, at least 1 px tall; [body] spans plus and minus
/// its RMS, inside the peaks, and is null without an RMS value. [lo] and
/// [hi] are in [-1, 1], [rms] in [0, 1]; [maxHalf] is the pixel height of
/// full scale above [centreY].
@visibleForTesting
({double top, double bottom, ({double top, double bottom})? body}) waveBar({
  required double lo,
  required double hi,
  required double? rms,
  required double centreY,
  required double maxHalf,
}) {
  final top = centreY - hi.clamp(-1.0, 1.0) * maxHalf;
  final bottomRaw = centreY - lo.clamp(-1.0, 1.0) * maxHalf;
  final bottom = bottomRaw < top + 1 ? top + 1 : bottomRaw;
  if (rms == null || rms.isNaN) return (top: top, bottom: bottom, body: null);
  final r = rms.clamp(0.0, 1.0) * maxHalf;
  var bodyTop = (centreY - r).clamp(top, bottom);
  var bodyBottom = (centreY + r).clamp(top, bottom);
  // Keep a visible core for quiet bins.
  if (bodyBottom - bodyTop < 1) {
    bodyTop = (centreY - 0.5).clamp(top, bottom - 1);
    bodyBottom = bodyTop + 1;
  }
  return (
    top: top,
    bottom: bottom,
    body: (top: bodyTop, bottom: bodyBottom),
  );
}

class _MeterPainter extends CustomPainter {
  final WaveformData? wave;
  final Duration pos;
  final bool live;

  /// Absolute media time of the timeline's left origin (0 for a normal
  /// track, the cached-window start for live).
  final double originSecs;
  final double timelineSecs;

  /// Absolute media time at the left edge of the view.
  final double viewStartAbs;
  final double visibleSecs;
  final double rulerHeight;
  final double? hoverX;

  /// A-B loop markers (absolute media time), drawn as amber flags with the
  /// region between them shaded.
  final Duration? abA;
  final Duration? abB;

  _MeterPainter({
    required this.wave,
    required this.pos,
    required this.live,
    required this.originSecs,
    required this.timelineSecs,
    required this.viewStartAbs,
    required this.visibleSecs,
    required this.rulerHeight,
    required this.hoverX,
    required this.abA,
    required this.abB,
  });

  static double _niceStep(double visibleSecs) {
    const steps = <double>[1, 2, 5, 10, 15, 20, 30, 60, 120, 300, 600];
    final target = visibleSecs / 5;
    for (final s in steps) {
      if (s >= target) return s;
    }
    return steps.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final posSecs = pos.inMicroseconds / 1e6;
    final pxPerSec = w / visibleSecs;
    final tLeft = viewStartAbs;
    final tRight = viewStartAbs + visibleSecs;
    final tlStart = originSecs;
    final tlEnd = originSecs + timelineSecs;
    final playheadX = (posSecs - tLeft) * pxPerSec;

    final waveTop = rulerHeight;
    final waveH = h - rulerHeight;
    final centreY = waveTop + waveH / 2;

    // ── Ruler ────────────────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, rulerHeight),
      Paint()..color = Tokens.surface2,
    );
    canvas.drawLine(
      Offset(0, rulerHeight - 0.5),
      Offset(w, rulerHeight - 0.5),
      Paint()
        ..color = Tokens.line
        ..strokeWidth = 1,
    );
    if (timelineSecs > 0) {
      final tickPaint = Paint()
        ..color = Tokens.fgFaint
        ..strokeWidth = 1;
      final step = _niceStep(visibleSecs);
      final tp = TextPainter(textDirection: TextDirection.ltr);
      var t = (tLeft / step).floorToDouble() * step;
      for (; t <= tRight; t += step) {
        if (t < tlStart || t > tlEnd) continue;
        final x = (t - tLeft) * pxPerSec;
        canvas.drawLine(
          Offset(x, rulerHeight - 5),
          Offset(x, rulerHeight),
          tickPaint,
        );
        tp.text = TextSpan(
          text: formatDuration(Duration(microseconds: (t * 1e6).round())),
          style: const TextStyle(
            fontFamily: Tokens.mono,
            fontSize: 9.5,
            color: Tokens.fgDim,
          ),
        );
        tp.layout();
        var dx = x - tp.width / 2;
        if (dx < 1) dx = 1;
        if (dx + tp.width > w - 1) dx = w - 1 - tp.width;
        tp.paint(canvas, Offset(dx, 2));
      }
    }

    // ── Waveform ─────────────────────────────────────────────────────
    canvas.drawLine(
      Offset(0, centreY),
      Offset(w, centreY),
      Paint()
        ..color = Tokens.line
        ..strokeWidth = 1,
    );
    final played = Paint()..color = Tokens.accent;
    final upcoming = Paint()..color = Tokens.line2;
    // Bins not yet covered (progressive envelope ahead of the playhead, or
    // a region skipped by a seek) — drawn as a faint baseline, not as a
    // real flat-zero spike, using the per-bin `filled` flags.
    final unloaded = Paint()..color = Tokens.line;
    // With RMS (libmpv-r14 and later) the RMS is the solid body and the
    // min/max peaks a lighter outline around it, which keeps loud, limited
    // masters readable. Without it the peaks are the body, as before.
    final playedPeak = Paint()..color = Tokens.accent.withValues(alpha: 0.35);
    final upcomingPeak = Paint()..color = Tokens.fg.withValues(alpha: 0.06);
    final wv = wave;
    if (wv != null && wv.bins > 0 && wv.duration > Duration.zero) {
      final bins = wv.bins;
      final filled = wv.filled;
      final rms = wv.rms;
      // Bins are placed in ABSOLUTE media time: bin i starts at
      // `start + i * binSecs`. For a normal track `start` is 0; for a live
      // window it's the oldest cached moment, so bins line up with the
      // playhead and the seek positions.
      final waveStart = wv.start.inMicroseconds / 1e6;
      final binSecs = wv.duration.inMicroseconds / 1e6 / bins;
      var i = ((tLeft - waveStart) / binSecs).floor();
      if (i < 0) i = 0;
      final maxHalf = waveH / 2 - 3;
      final barW = (pxPerSec * binSecs * 0.7).clamp(0.6, 6.0);
      for (; i < bins; i++) {
        final t = waveStart + (i + 0.5) * binSecs;
        if (t > tRight) break;
        final x = (t - tLeft) * pxPerSec;
        if (x < -barW || x > w + barW) continue;
        final covered = i >= filled.length || filled[i] != 0;
        final bar = waveBar(
          lo: wv.min[i],
          hi: wv.max[i],
          rms: covered && rms != null && i < rms.length ? rms[i] : null,
          centreY: centreY,
          maxHalf: maxHalf,
        );
        final isPlayed = t <= posSecs;
        final peaks = Rect.fromLTRB(x, bar.top, x + barW, bar.bottom);
        if (!covered) {
          canvas.drawRect(peaks, unloaded);
        } else if (bar.body == null) {
          canvas.drawRect(peaks, isPlayed ? played : upcoming);
        } else {
          canvas.drawRect(peaks, isPlayed ? playedPeak : upcomingPeak);
          canvas.drawRect(
            Rect.fromLTRB(x, bar.body!.top, x + barW, bar.body!.bottom),
            isPlayed ? played : upcoming,
          );
        }
      }
    }

    // ── A-B loop markers + region ────────────────────────────────────
    double xOfSecs(double tSecs) => (tSecs - tLeft) * pxPerSec;
    final xa = abA == null ? null : xOfSecs(abA!.inMicroseconds / 1e6);
    final xb = abB == null ? null : xOfSecs(abB!.inMicroseconds / 1e6);
    const loop = Tokens.amber;
    // Shade the loop span once both ends are set (A < B).
    if (xa != null && xb != null && xb > xa) {
      final l = xa.clamp(0.0, w);
      final r = xb.clamp(0.0, w);
      if (r > l) {
        canvas.drawRect(
          Rect.fromLTRB(l, waveTop, r, h),
          Paint()..color = loop.withValues(alpha: 0.12),
        );
      }
    }
    void drawMarker(double? x, String label) {
      if (x == null || x < 0 || x > w) return;
      canvas.drawRect(
        Rect.fromLTWH(x - 0.75, rulerHeight, 1.5, h - rulerHeight),
        Paint()..color = loop,
      );
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontFamily: Tokens.mono,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Tokens.onAccent,
          ),
        ),
      )..layout();
      final boxW = tp.width + 6;
      final boxH = tp.height + 2;
      var bx = x + 1;
      if (bx + boxW > w) bx = x - 1 - boxW;
      final box = Rect.fromLTWH(bx, rulerHeight + 1, boxW, boxH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(2)),
        Paint()..color = loop,
      );
      tp.paint(canvas, Offset(bx + 3, rulerHeight + 2));
    }

    drawMarker(xa, 'A');
    drawMarker(xb, 'B');

    // ── Hover preview cursor ─────────────────────────────────────────
    final hx = hoverX;
    if (hx != null && hx >= 0 && hx <= w) {
      canvas.drawRect(
        Rect.fromLTWH(hx - 0.5, rulerHeight, 1, h - rulerHeight),
        Paint()..color = Tokens.fg.withValues(alpha: 0.28),
      );
      final t = (tLeft + hx / pxPerSec).clamp(tlStart, tlEnd);
      final tp = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: formatDuration(Duration(microseconds: (t * 1e6).round())),
          style: const TextStyle(
            fontFamily: Tokens.mono,
            fontSize: 9.5,
            color: Tokens.fg,
          ),
        ),
      )..layout();
      var bx = hx + 4;
      if (bx + tp.width + 6 > w) bx = hx - 4 - tp.width - 6;
      final bubble =
          Rect.fromLTWH(bx, rulerHeight + 3, tp.width + 6, tp.height + 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubble, const Radius.circular(3)),
        Paint()..color = Tokens.surface3,
      );
      tp.paint(canvas, Offset(bx + 3, rulerHeight + 4));
    }

    // ── Reaper playhead: one continuous line through the ruler, capped
    //    by a downward triangle pip (no gap). ──────────────────────────
    if (playheadX >= 0 && playheadX <= w) {
      final ph = Paint()..color = Tokens.accent;
      canvas.drawRect(Rect.fromLTWH(playheadX - 0.75, 0, 1.5, h), ph);
      final pip = Path()
        ..moveTo(playheadX - 5, 0)
        ..lineTo(playheadX + 5, 0)
        ..lineTo(playheadX, 9)
        ..close();
      canvas.drawPath(pip, ph);
    }
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.wave != wave ||
      old.pos != pos ||
      old.live != live ||
      old.originSecs != originSecs ||
      old.timelineSecs != timelineSecs ||
      old.viewStartAbs != viewStartAbs ||
      old.visibleSecs != visibleSecs ||
      old.rulerHeight != rulerHeight ||
      old.hoverX != hoverX ||
      old.abA != abA ||
      old.abB != abB;
}

/// One row of the meter context menu (or a divider).
class _MenuEntry {
  final String? value;
  final IconData? icon;
  final String? label;
  final String? trailing;
  final bool enabled;
  final bool isDivider;

  const _MenuEntry(this.value, this.icon, this.label, this.trailing,
      {this.enabled = true})
      : isDivider = false;

  const _MenuEntry._divider()
      : value = null,
        icon = null,
        label = null,
        trailing = null,
        enabled = false,
        isDivider = true;

  static const divider = _MenuEntry._divider();
}

/// A context-menu route with **no transition** — it just appears and
/// disappears (the default `showMenu` scale/fade is what we're avoiding).
/// Dismisses on tap-outside; pops the chosen entry's value.
class _InstantMenuRoute<T> extends PopupRoute<T> {
  final Offset position;
  final List<_MenuEntry> entries;

  _InstantMenuRoute({required this.position, required this.entries});

  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => null;
  @override
  String get barrierLabel => 'Dismiss menu';

  @override
  Widget buildPage(
      BuildContext context, Animation<double> a, Animation<double> s) {
    return CustomSingleChildLayout(
      delegate: _MenuLayoutDelegate(position),
      child: _InstantMenu(entries: entries),
    );
  }
}

/// Places the menu at the tap point, nudged back on-screen if it would spill
/// off the right/bottom edge.
class _MenuLayoutDelegate extends SingleChildLayoutDelegate {
  final Offset target;
  _MenuLayoutDelegate(this.target);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var x = target.dx;
    var y = target.dy;
    if (x + childSize.width > size.width) x = size.width - childSize.width;
    if (y + childSize.height > size.height) y = size.height - childSize.height;
    return Offset(x.clamp(0, size.width), y.clamp(0, size.height));
  }

  @override
  bool shouldRelayout(_MenuLayoutDelegate old) => old.target != target;
}

/// The flat squircle menu card (matches the app surfaces).
class _InstantMenu extends StatelessWidget {
  final List<_MenuEntry> entries;
  const _InstantMenu({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4),
      // A colour-bearing Material (not transparency + Container) so the row
      // ink/hover renders over the surface; flat squircle, like the app.
      child: Material(
        color: Tokens.surface2,
        clipBehavior: Clip.antiAlias,
        shape: Tokens.squircle(
          Tokens.rMd,
          side: const BorderSide(color: Tokens.line2),
        ),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Tokens.s4),
              for (final e in entries)
                if (e.isDivider)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: Tokens.s4),
                    child:
                        Divider(height: 1, thickness: 1, color: Tokens.line2),
                  )
                else
                  _MenuRow(entry: e),
              const SizedBox(height: Tokens.s4),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuEntry entry;
  const _MenuRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final enabled = entry.enabled;
    return InkWell(
      onTap: enabled ? () => Navigator.of(context).pop(entry.value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12, vertical: Tokens.s8),
        child: Row(
          children: [
            Icon(entry.icon,
                size: 16, color: enabled ? Tokens.fgDim : Tokens.fgFaint),
            const SizedBox(width: Tokens.s12),
            Expanded(
              child: Text(
                entry.label!,
                style: Tokens.body
                    .copyWith(color: enabled ? Tokens.fg : Tokens.fgFaint),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (entry.trailing != null) ...[
              const SizedBox(width: Tokens.s16),
              Text(entry.trailing!, style: Tokens.numeric),
            ],
          ],
        ),
      ),
    );
  }
}
