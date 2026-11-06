import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Turns the mouse wheel and trackpad swipes over the waveform into a
/// horizontal pan: it never seeks. [onPan] moves the view by that many
/// pixels (positive goes later in time) and returns false when it could
/// not move (an edge, nothing to scroll). [canPan] says whether there is
/// anything to pan: when there is, the wheel is claimed through the
/// pointer signal resolver, so a scrolling page around the waveform does
/// not scroll too; when there is not, the page gets the wheel.
///
/// macOS delivers a trackpad swipe as a pan-zoom gesture with no OS
/// momentum, so a flick is simulated on release: the release velocity
/// decays with friction until it stops or the view hits an edge.
class WaveformPan {
  WaveformPan({
    required this.onPan,
    required this.canPan,
    this.onZoom,
    this.still,
  });

  final bool Function(double pixels) onPan;
  final bool Function() canPan;

  /// Zooms the view by a factor of its visible span (below 1 zooms in).
  final void Function(double factor)? onZoom;

  /// Whether motion is reduced: a release does not coast.
  final bool Function()? still;

  Timer? _flick;
  double _velocity = 0; // pixels per second at the last update
  Duration? _lastUpdate;

  /// A wheel or a trackpad scroll signal. The larger axis wins, so both a
  /// vertical wheel and a horizontal swipe pan the view.
  ///
  /// With Ctrl (Cmd on macOS) held the wheel zooms: away from you in.
  void signal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keys = HardwareKeyboard.instance;
    final zoom = onZoom;
    if (zoom != null && (keys.isControlPressed || keys.isMetaPressed)) {
      GestureBinding.instance.pointerSignalResolver.register(event, (e) {
        final dy = (e as PointerScrollEvent).scrollDelta.dy;
        if (dy != 0) zoom(dy < 0 ? _wheelZoom : 1 / _wheelZoom);
      });
      return;
    }
    if (!canPan()) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      stop(); // a real scroll (with any OS momentum) takes over
      final d = (e as PointerScrollEvent).scrollDelta;
      final delta = d.dx.abs() >= d.dy.abs() ? d.dx : d.dy;
      if (delta != 0) onPan(delta);
    });
  }

  /// The zoom of one wheel notch: a gentler step than the buttons'.
  static const _wheelZoom = 0.85;

  /// The pinch scale at the last update, for the change since.
  double _scale = 1;

  void start() {
    stop();
    _lastUpdate = null;
    _velocity = 0;
    _scale = 1;
  }

  /// A trackpad pan update. The view follows the fingers: the opposite
  /// sign of the wheel's content scroll.
  void update(PointerPanZoomUpdateEvent event) {
    // A pinch zooms by the change of its scale: spread apart, in.
    final zoom = onZoom;
    if (zoom != null && event.scale > 0 && event.scale != _scale) {
      zoom(_scale / event.scale);
      _scale = event.scale;
    }
    final d = event.panDelta;
    final delta = -(d.dx.abs() >= d.dy.abs() ? d.dx : d.dy);
    final last = _lastUpdate;
    if (last != null) {
      final dt = (event.timeStamp - last).inMicroseconds / 1e6;
      if (dt > 1e-4) _velocity = delta / dt;
    }
    _lastUpdate = event.timeStamp;
    if (delta != 0) onPan(delta);
  }

  /// The fingers lifted: coast with the release velocity.
  void end() {
    stop();
    var velocity = _velocity;
    if (velocity.abs() < 80 || (still?.call() ?? false)) return;
    _flick = Timer.periodic(const Duration(milliseconds: 16), (_) {
      velocity *= 0.95; // friction per frame at about 60 fps
      if (velocity.abs() < 30 || !onPan(velocity * 0.016)) stop();
    });
  }

  void stop() {
    _flick?.cancel();
    _flick = null;
  }
}
