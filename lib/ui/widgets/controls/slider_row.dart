import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../layout/layout_scope.dart';
import '../../tokens.dart';
import 'setting_tile.dart';
import 'value_badge.dart';

/// Title (+ description) with a full-width custom [AppSlider] beneath and a
/// numeric readout in the header. Double-tap the slider to reset to
/// [resetTo] when provided.
class SliderRow extends StatelessWidget {
  final String label;
  final String? description;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double value)? format;
  final double? resetTo;
  final bool enabled;

  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.description,
    this.onChangeEnd,
    this.divisions,
    this.format,
    this.resetTo,
    this.enabled = true,
  });

  String _fmt(double v) => format?.call(v) ?? v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max).toDouble();
    Widget slider = AppSlider(
      value: clamped,
      min: min,
      max: max,
      divisions: divisions,
      enabled: enabled,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
      semanticLabel: label,
      semanticValue: _fmt,
    );
    if (resetTo != null) {
      slider = Tooltip(
        message: 'Double-tap to reset to ${_fmt(resetTo!)}',
        waitDuration: const Duration(milliseconds: 800),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: enabled ? () => onChanged(resetTo!) : null,
          child: slider,
        ),
      );
    }
    return SettingTile(
      title: label,
      description: description,
      enabled: enabled,
      trailing: ExcludeSemantics(
        child: ValueBadge(
          _fmt(clamped),
          color: enabled ? Tokens.accent : Tokens.fgFaint,
        ),
      ),
      below: slider,
    );
  }
}

/// A flat custom slider: rounded track, accent fill, rounded thumb.
/// Tap or drag to set; reports continuously through [onChanged] and once
/// through [onChangeEnd]. Snaps to [divisions] when given.
///
/// It is focusable: the arrow keys step it (a division, or a hundredth of
/// the range), Home and End jump to the ends. Screen readers see a slider
/// named [semanticLabel] with the value [semanticValue] prints. On touch
/// the hit area is a full tap target tall and the thumb grows to fit a
/// finger; with a pointer the slider stays dense.
class AppSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? semanticLabel;
  final String Function(double value)? semanticValue;

  const AppSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.enabled = true,
    this.onChangeEnd,
    this.semanticLabel,
    this.semanticValue,
  });

  @override
  State<AppSlider> createState() => _AppSliderState();
}

class _AppSliderState extends State<AppSlider> {
  /// The value under the finger during a drag.
  double? _dragged;

  static const double _track = 6;
  static const double _pointerHeight = 24;

  bool _focused = false;

  double get _step {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    final d = widget.divisions;
    return d == null || d <= 0 ? span / 100 : span / d;
  }

  double _snap(double v) {
    final min = widget.min, max = widget.max;
    final c = v.clamp(min, max).toDouble();
    final d = widget.divisions;
    if (d == null || max <= min) return c;
    final step = (max - min) / d;
    return (min + ((c - min) / step).round() * step).clamp(min, max).toDouble();
  }

  String _describe(double v) =>
      widget.semanticValue?.call(v) ?? v.toStringAsFixed(1);

  void _nudge(double delta) {
    final next = _snap(widget.value + delta);
    if (next == widget.value) return;
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  void _jump(double to) {
    if (to == widget.value) return;
    widget.onChanged(to);
    widget.onChangeEnd?.call(to);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _nudge(_step);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _nudge(-_step);
    } else if (key == LogicalKeyboardKey.home) {
      _jump(widget.min);
    } else if (key == LogicalKeyboardKey.end) {
      _jump(widget.max);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.min, max = widget.max, value = widget.value;
    final enabled = widget.enabled;
    // On touch the thumb and the grab band grow to fit a finger.
    final touch = context.layout.isTouch;
    final thumb = touch ? 22.0 : 16.0;
    final height = math.max(_pointerHeight, context.layout.minTap);
    final up = _snap(value + _step), down = _snap(value - _step);
    return Semantics(
      slider: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: _describe(value),
      increasedValue: _describe(up),
      decreasedValue: _describe(down),
      onIncrease: enabled && up != value ? () => _nudge(_step) : null,
      onDecrease: enabled && down != value ? () => _nudge(-_step) : null,
      child: Focus(
        canRequestFocus: enabled,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: LayoutBuilder(
            builder: (context, c) {
              final span = (c.maxWidth - thumb).clamp(1.0, double.infinity);
              final frac = max <= min
                  ? 0.0
                  : ((value - min) / (max - min)).clamp(0.0, 1.0);

              double valueAt(double dx) {
                final t = ((dx - thumb / 2) / span).clamp(0.0, 1.0);
                return _snap(min + t * (max - min));
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: enabled
                    ? (d) => widget.onChanged(valueAt(d.localPosition.dx))
                    : null,
                onTapUp: enabled && widget.onChangeEnd != null
                    ? (d) => widget.onChangeEnd!(valueAt(d.localPosition.dx))
                    : null,
                onHorizontalDragUpdate: enabled
                    ? (d) {
                        _dragged = valueAt(d.localPosition.dx);
                        widget.onChanged(_dragged!);
                      }
                    : null,
                // The last dragged value: the parent may not have rebuilt
                // with it yet (it updates asynchronously).
                onHorizontalDragEnd: enabled && widget.onChangeEnd != null
                    ? (_) {
                        widget.onChangeEnd!(_dragged ?? widget.value);
                        _dragged = null;
                      }
                    : null,
                child: SizedBox(
                  height: height,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Empty track.
                      Container(
                        height: _track,
                        decoration: ShapeDecoration(
                          color: Tokens.surface3,
                          shape: Tokens.shape(Tokens.rPill),
                        ),
                      ),
                      // Accent fill up to the thumb centre.
                      Container(
                        height: _track,
                        width: thumb / 2 + frac * span,
                        decoration: ShapeDecoration(
                          color: enabled ? Tokens.accent : Tokens.fgFaint,
                          shape: Tokens.shape(Tokens.rPill),
                        ),
                      ),
                      // Thumb, ringed in the accent while focused.
                      Positioned(
                        left: frac * span,
                        child: Container(
                          width: thumb,
                          height: thumb,
                          decoration: ShapeDecoration(
                            color: enabled ? Tokens.fg : Tokens.fgFaint,
                            shape: Tokens.shape(
                              thumb / 2,
                              side: _focused
                                  ? BorderSide(color: Tokens.accent, width: 2)
                                  : BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
