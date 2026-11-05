import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// The part of the timeline the waveform meter shows: the zoom level and
/// where the view starts. Immutable; the meter swaps it on every zoom,
/// scroll and new track.
///
/// A normal track spans `[0, duration]`. A live stream (the envelope is a
/// rolling window over the demuxer cache, `wave.live`) spans the cached
/// window instead. It opens on the window's newest end and follows it as
/// the window grows ([followsLive]); scrolled back, its view is anchored
/// in absolute media time so it holds still while the window slides, and
/// scrolled to the end (or [toLive]) it follows again. A track's view
/// does not follow the playhead: it moves only when the user scrolls.
@immutable
class WaveformViewport {
  const WaveformViewport({
    this.duration = Duration.zero,
    this.wave,
    this.windowSeconds = double.infinity,
    this.viewStart = 0,
    this.viewLeftAbs = 0,
    this.followsLive = true,
  });

  /// The narrowest zoom, in seconds across the full width.
  static const double minWindow = 5;

  /// The timeline length shown with nothing loaded, so the ruler is never
  /// empty.
  static const double placeholderSecs = 300;

  /// The zoom step of the zoom buttons.
  static const double zoomStep = 0.6;

  /// The window of a live stream before the user zooms.
  static const double liveWindow = 30;

  /// The track length (zero for live or nothing loaded).
  final Duration duration;

  /// The envelope from `stream.waveform`, null before the first one.
  final WaveformData? wave;

  /// Seconds visible across the full width: the zoom level. Infinite (the
  /// default) fits the whole track, or [liveWindow] of a live stream.
  final double windowSeconds;

  /// [windowSeconds] made finite.
  double get _window {
    if (windowSeconds.isFinite) return windowSeconds;
    return live ? liveWindow : timelineSecs;
  }

  /// First visible second of a normal track.
  final double viewStart;

  /// Live only: the view's left edge in absolute media time, while it
  /// does not follow the newest end.
  final double viewLeftAbs;

  /// Live only: whether the view keeps the window's newest end in view.
  final bool followsLive;

  /// How close to the end a scroll counts as the end, in seconds.
  static const double _liveSlack = 0.5;

  /// Whether the envelope is a live rolling window.
  bool get live => wave?.live ?? false;

  double get _durSecs => duration.inMicroseconds / 1e6;

  /// Absolute media time of the timeline's left origin: the start of the
  /// cached window for a live stream, else 0.
  double get originSecs => live ? wave!.start.inMicroseconds / 1e6 : 0;

  /// The timeline length for the ruler and the scroll range.
  double get timelineSecs {
    if (live) {
      final span = wave!.duration.inMicroseconds / 1e6;
      return span > minWindow ? span : minWindow;
    }
    return _durSecs > 0 ? _durSecs : placeholderSecs;
  }

  /// The furthest the view can start, relative to [originSecs].
  double get maxStart =>
      (timelineSecs - _window).clamp(0, timelineSecs).toDouble();

  /// Whether there is timeline off screen to scroll to.
  bool get canScroll => maxStart > 0;

  /// Seconds across the full width. A live view keeps the zoom window
  /// fixed so the envelope grows into it; a track that fits shows whole.
  double get visibleSecs {
    if (live) return _window;
    return canScroll ? _window : timelineSecs;
  }

  /// The view's left edge relative to [originSecs].
  double get leftRel {
    if (live) {
      if (followsLive) return maxStart;
      return (viewLeftAbs - originSecs).clamp(0, maxStart).toDouble();
    }
    return viewStart.clamp(0, maxStart).toDouble();
  }

  /// Absolute media time at the left edge of the view.
  double get viewStartAbs => originSecs + leftRel;

  bool get canZoomIn => _window > minWindow;
  bool get canZoomOut => _window < timelineSecs;

  /// Absolute media time at pixel [x] of a [width] wide meter, clamped to
  /// what can be sought: the cached window when live, else the track.
  Duration timeAtX(double x, double width) {
    final floorUs = live ? wave!.start.inMicroseconds : 0;
    // A zero width (first layout pass, a collapsed pane) would divide by
    // zero and throw on the conversion below.
    if (width <= 0 || !visibleSecs.isFinite || visibleSecs <= 0) {
      return Duration(microseconds: floorUs);
    }
    final t = viewStartAbs + x * visibleSecs / width;
    if (!t.isFinite) return Duration(microseconds: floorUs);
    final ceilUs = live ? wave!.end.inMicroseconds : duration.inMicroseconds;
    return Duration(
      microseconds: (t * 1e6).round().clamp(floorUs, ceilUs).toInt(),
    );
  }

  /// The pixel of absolute media time [t] in a [width] wide meter.
  double xOf(Duration t, double width) =>
      (t.inMicroseconds / 1e6 - viewStartAbs) * width / visibleSecs;

  /// The view of a new [duration] and [wave]. A new track (another
  /// duration) starts whole again.
  WaveformViewport withSource({Duration? duration, WaveformData? wave}) {
    final d = duration ?? this.duration;
    // A live window only slides forward: one that starts earlier is
    // another stream, which follows its own end.
    final old = this.wave;
    final restarted =
        wave != null &&
        wave.live &&
        old != null &&
        old.live &&
        wave.start < old.start;
    final reset = d != this.duration || restarted;
    return WaveformViewport(
      duration: d,
      wave: wave ?? this.wave,
      windowSeconds: reset ? double.infinity : windowSeconds,
      viewStart: reset ? 0 : viewStart,
      viewLeftAbs: reset ? 0 : viewLeftAbs,
      followsLive: reset || followsLive,
    );
  }

  /// The view with no envelope (the stream went back to null).
  WaveformViewport withoutWave() => WaveformViewport(
    duration: duration,
    windowSeconds: windowSeconds,
    viewStart: viewStart,
    viewLeftAbs: viewLeftAbs,
    followsLive: followsLive,
  );

  /// Zoomed by [factor] (below 1 zooms in) around [around] (a media time
  /// in view, such as the playhead), else around the view's centre.
  WaveformViewport zoomBy(double factor, {Duration? around}) {
    final clamped = (_window * factor)
        .clamp(math.min(minWindow, timelineSecs), timelineSecs)
        .toDouble();
    // All of a track in view: fit it, so the view follows its length.
    final window = !live && clamped >= timelineSecs ? double.infinity : clamped;
    if (live) {
      // The anchor holds; it is clamped again on read. A view that now
      // reaches the newest end follows it again.
      final zoomed = _copy(windowSeconds: window);
      return zoomed.followsLive || zoomed.leftRel < zoomed.maxStart - _liveSlack
          ? zoomed
          : zoomed._copy(followsLive: true);
    }
    final at = around == null ? null : around.inMicroseconds / 1e6;
    final inView =
        at != null && at >= viewStartAbs && at <= viewStartAbs + visibleSecs;
    final centre = inView ? at - originSecs : viewStart + visibleSecs / 2;
    final zoomed = _copy(windowSeconds: window);
    return zoomed._copy(
      viewStart: (centre - zoomed.visibleSecs / 2)
          .clamp(0, zoomed.maxStart)
          .toDouble(),
    );
  }

  /// Scrolled so the view starts [rel] seconds after [originSecs].
  WaveformViewport scrollTo(double rel) {
    final v = rel.clamp(0, maxStart).toDouble();
    if (!live) return _copy(viewStart: v);
    return _copy(
      viewLeftAbs: originSecs + v,
      followsLive: v >= maxStart - _liveSlack,
    );
  }

  /// A live view back on the newest end, following it.
  WaveformViewport toLive() => _copy(followsLive: true);

  /// Scrolled by [pixels] of a [width] wide meter.
  WaveformViewport scrollByPixels(double pixels, double width) {
    if (width <= 0 || visibleSecs <= 0) return this;
    return scrollTo(leftRel + pixels * visibleSecs / width);
  }

  WaveformViewport _copy({
    double? windowSeconds,
    double? viewStart,
    double? viewLeftAbs,
    bool? followsLive,
  }) => WaveformViewport(
    duration: duration,
    wave: wave,
    windowSeconds: windowSeconds ?? this.windowSeconds,
    viewStart: viewStart ?? this.viewStart,
    viewLeftAbs: viewLeftAbs ?? this.viewLeftAbs,
    followsLive: followsLive ?? this.followsLive,
  );
}
