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
  final SliderScale scale;
  final double? step;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String Function(double value)? format;
  final double? resetTo;
  final bool enabled;

  /// A short word before the value ("live", "rebuild"), with [tagTooltip]
  /// on hover; null for none.
  final String? tag;
  final String? tagTooltip;

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
    this.scale = SliderScale.linear,
    this.step,
    this.format,
    this.resetTo,
    this.enabled = true,
    this.tag,
    this.tagTooltip,
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
      scale: scale,
      step: step,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag case final tag?) ...[
            Tooltip(
              message: tagTooltip ?? '',
              child: Text(tag, style: Tokens.caption),
            ),
            const SizedBox(width: Tokens.s8),
          ],
          ExcludeSemantics(
            child: ValueBadge(
              _fmt(clamped),
              color: enabled ? Tokens.accent : Tokens.fgFaint,
            ),
          ),
        ],
      ),
      below: slider,
    );
  }
}

/// A flat custom slider in the Material 3 Expressive form: a thick pill
/// track split by a slim upright handle, with a gap either side of the
/// handle and a stop dot at the end of the inactive part.
/// Tap or drag to set; reports continuously through [onChanged] and once
/// through [onChangeEnd]. Snaps to [divisions] when given.
///
/// It is focusable: the arrow keys step it (a division, the [step], or a
/// round hundredth of the range; Shift for a tenth of that), Page Up and
/// Page Down move ten steps, Home and End jump to the ends. Screen readers see a slider
/// named [semanticLabel] with the value [semanticValue] prints. On touch
/// the hit area is a full tap target tall and the track and handle grow to
/// fit a finger; with a pointer the slider stays dense.
/// Where a value sits along a slider's track.
enum SliderScale {
  /// Even steps of value: gain in dB, a percentage, a mix.
  linear,

  /// Even ratios: frequencies, times, ratios, speeds. The middle of the
  /// track is the geometric mean of the range, so 1x sits in the middle
  /// of 0.25x to 4x. Needs a range above zero.
  log,
}

class AppSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;

  /// Where values sit along the track.
  final SliderScale scale;

  /// The value an arrow key moves; null for a round hundredth of the
  /// range (on a [SliderScale.log] track, a hundredth of the track).
  final double? step;
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
    this.scale = SliderScale.linear,
    this.step,
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

  static const double _pointerHeight = 32;
  static const double _gap = 4;

  bool _focused = false;

  bool get _log =>
      widget.scale == SliderScale.log && widget.min > 0 && widget.max > 0;

  /// Where [v] sits along the track, from 0 to 1.
  double _toT(double v) {
    final min = widget.min, max = widget.max;
    if (max <= min) return 0;
    final t = _log
        ? math.log(v / min) / math.log(max / min)
        : (v - min) / (max - min);
    return t.isFinite ? t.clamp(0.0, 1.0) : 0.0;
  }

  /// The value at [t] along the track.
  double _fromT(double t) {
    final min = widget.min, max = widget.max;
    final c = t.clamp(0.0, 1.0);
    return _log
        ? min * math.pow(max / min, c).toDouble()
        : min + c * (max - min);
  }

  /// [v] on the nearest of the [AppSlider.divisions], which are even
  /// along the track (even ratios on a log track).
  double _snap(double v) {
    final min = widget.min, max = widget.max;
    final c = v.clamp(min, max).toDouble();
    final d = widget.divisions;
    if (d == null || max <= min) return c;
    if (_log) return _fromT((_toT(c) * d).round() / d);
    final step = (max - min) / d;
    return (min + ((c - min) / step).round() * step).clamp(min, max).toDouble();
  }

  /// The value an arrow key moves on a linear track: a division, the
  /// given step, or a round hundredth of the range (1, 2 or 5 times a
  /// power of ten).
  double get _linearStep {
    final span = widget.max - widget.min;
    if (span <= 0) return 0;
    final d = widget.divisions;
    if (d != null && d > 0) return span / d;
    if (widget.step case final step?) return step;
    final raw = span / 100;
    final unit = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final f = raw / unit;
    return (f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10))) * unit;
  }

  /// [v] on the grid of [step] that starts at the minimum, without the
  /// float noise of the sum (0.30000000000000004).
  double _onGrid(double v, double step) {
    if (step <= 0) return v;
    final origin = widget.min;
    final r = origin + ((v - origin) / step).round() * step;
    final decimals = math.max(_decimals(step), _decimals(origin));
    return double.parse(r.toStringAsFixed(decimals));
  }

  /// The decimals [x] is written with, at most 12.
  static int _decimals(double x) {
    final text = x.toString();
    if (text.contains('e')) return 12;
    final dot = text.indexOf('.');
    if (dot < 0) return 0;
    final fraction = text.substring(dot + 1);
    return fraction == '0' ? 0 : math.min(fraction.length, 12);
  }

  /// [v] to three significant figures, or more when fewer would not move
  /// it from [from] the way [v] moves (rounding can undo a fine step).
  static double _round(double v, double from) {
    for (final figures in [3, 4, 6, 9]) {
      final r = double.parse(v.toStringAsPrecision(figures));
      if (r != from && (r - from).sign == (v - from).sign) return r;
    }
    return v;
  }

  /// The value [times] steps from [from]: on a log track a hundredth of
  /// the track per step, else [_linearStep]. [fine] steps a tenth.
  double _stepped(double from, double times, {bool fine = false}) {
    final divided = (widget.divisions ?? 0) > 0;
    final k = fine && !divided ? times / 10 : times;
    if (_log && widget.step == null && !divided) {
      final next = _fromT(_toT(from) + k / 100);
      return _round(next, from).clamp(widget.min, widget.max).toDouble();
    }
    final step = _linearStep;
    final next = from + k * step;
    final grid = divided ? next : _onGrid(next, fine ? step / 10 : step);
    return _snap(grid);
  }

  String _describe(double v) =>
      widget.semanticValue?.call(v) ?? v.toStringAsFixed(1);

  void _nudge(double times, {bool fine = false}) {
    final next = _stepped(widget.value, times, fine: fine);
    if (next == widget.value) return;
    widget.onChanged(next);
    widget.onChangeEnd?.call(next);
  }

  void _jump(double to) {
    if (to == widget.value) return;
    widget.onChanged(to);
    widget.onChangeEnd?.call(to);
  }

  /// Arrows step (Shift for a tenth of a step), Page Up and Page Down
  /// move ten steps, Home and End jump to the ends.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final fine = HardwareKeyboard.instance.isShiftPressed;
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.arrowUp) {
      _nudge(1, fine: fine);
    } else if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowDown) {
      _nudge(-1, fine: fine);
    } else if (key == LogicalKeyboardKey.pageUp) {
      _nudge(10);
    } else if (key == LogicalKeyboardKey.pageDown) {
      _nudge(-10);
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
    final value = widget.value;
    final enabled = widget.enabled;
    // On touch the track, the handle and the grab band grow to fit a
    // finger.
    final touch = context.layout.isTouch;
    final track = touch ? 12.0 : 8.0;
    final thumb = touch ? 6.0 : 4.0;
    final handleH = touch ? 40.0 : 28.0;
    final height = math.max(_pointerHeight, context.layout.minTap);
    final up = _stepped(value, 1), down = _stepped(value, -1);
    return Semantics(
      slider: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: _describe(value),
      increasedValue: _describe(up),
      decreasedValue: _describe(down),
      onIncrease: enabled && up != value ? () => _nudge(1) : null,
      onDecrease: enabled && down != value ? () => _nudge(-1) : null,
      child: Focus(
        canRequestFocus: enabled,
        onKeyEvent: _onKey,
        onFocusChange: (f) => setState(() => _focused = f),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: LayoutBuilder(
            builder: (context, c) {
              final span = (c.maxWidth - thumb).clamp(1.0, double.infinity);
              final frac = _toT(value);

              double valueAt(double dx) {
                final t = ((dx - thumb / 2) / span).clamp(0.0, 1.0);
                return _snap(_fromT(t));
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
                      // Inactive track, after the handle and its gap.
                      Positioned(
                        left: (frac * span + thumb + _gap).clamp(
                          0.0,
                          c.maxWidth,
                        ),
                        right: 0,
                        child: Container(
                          height: track,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: track / 2 - 2),
                          decoration: ShapeDecoration(
                            color: enabled ? Tokens.trackOff : Tokens.surface4,
                            shape: Tokens.pill,
                          ),
                          // The stop dot marks the end of the range.
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: ShapeDecoration(
                              color: enabled ? Tokens.accent : Tokens.fgFaint,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ),
                      ),
                      // Active track, up to the handle and its gap.
                      Container(
                        height: track,
                        width: math.max(0, frac * span - _gap),
                        decoration: ShapeDecoration(
                          color: enabled ? Tokens.accent : Tokens.fgFaint,
                          shape: Tokens.pill,
                        ),
                      ),
                      // The upright handle, ringed while focused.
                      Positioned(
                        left: frac * span,
                        child: Container(
                          width: thumb,
                          height: handleH,
                          decoration: ShapeDecoration(
                            color: enabled ? Tokens.accent : Tokens.fgFaint,
                            shape: StadiumBorder(
                              side: _focused
                                  ? BorderSide(color: Tokens.fg, width: 1)
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
