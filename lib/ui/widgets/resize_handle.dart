import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// A draggable separator for resizing adjacent panes. The seam is a constant
/// faint hairline; the affordance is a short **pill grip** centred on it
/// that brightens on hover and lights up [Tokens.accent] while grabbed.
///
/// Only the **grip** is interactive (plus a small margin around it): the rest
/// of the seam ignores pointers, so it never steals drags from a control that
/// shares the same strip (e.g. the waveform's scrollbar that the meter's
/// bottom resize line overlaps).
///
/// [axis] is the orientation of the seam: [Axis.horizontal] separates a
/// top and bottom split (drag vertically), [Axis.vertical] separates a left
/// and right split (drag horizontally). [onDelta] reports the drag delta
/// along the resize direction each update.
///
/// Screen readers get an adjustable [label] whose increase and decrease
/// actions move the seam by [step] (towards the bottom or the right on
/// increase); with the keyboard, the focused grip moves by [step] on the
/// arrow keys.
class ResizeHandle extends StatefulWidget {
  final Axis axis;
  final ValueChanged<double> onDelta;

  /// Width (vertical) or height (horizontal) of the invisible grab area
  /// around the seam, so it is easy to catch. On touch, give at least the
  /// touch target (48): it may overlap the panes on either side (see
  /// [ResizeHandle.overlay]).
  final double hitThickness;

  /// What the seam resizes, for screen readers.
  final String label;

  /// How far one increase, decrease or arrow key moves the seam.
  final double step;

  const ResizeHandle({
    super.key,
    required this.axis,
    required this.onDelta,
    this.hitThickness = 9,
    this.label = 'Resize',
    this.step = 16,
  });

  /// Lays a horizontal handle [hit] tall centred on a seam [offset] from
  /// the top of a Stack, over the panes around it, so a touch target
  /// taller than the gap between the panes still catches. Only the grip
  /// takes pointers; the rest of the strip lets them through.
  static Widget overlay({
    required double offset,
    required double hit,
    required ResizeHandle handle,
  }) => Positioned(
    left: 0,
    right: 0,
    top: offset - hit / 2,
    height: hit,
    child: handle,
  );

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;
  bool _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final horizontal = widget.axis == Axis.horizontal;
    final key = event.logicalKey;
    final forward = horizontal
        ? LogicalKeyboardKey.arrowDown
        : LogicalKeyboardKey.arrowRight;
    final back = horizontal
        ? LogicalKeyboardKey.arrowUp
        : LogicalKeyboardKey.arrowLeft;
    if (key == forward) {
      widget.onDelta(widget.step);
    } else if (key == back) {
      widget.onDelta(-widget.step);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static const double _gripLong = 44; // length along the seam
  static const double _gripShort = 6; // thickness across the seam

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final gripColor = _dragging || _focused
        ? Tokens.accent
        : (_hovering ? Tokens.fgDim : Tokens.fgFaint);

    final grip = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      width: horizontal ? _gripLong : _gripShort,
      height: horizontal ? _gripShort : _gripLong,
      decoration: ShapeDecoration(
        color: gripColor,
        shape: Tokens.shape(Tokens.rSm),
      ),
    );

    // Full-length seam behind the grip: purely visual. IgnorePointer so it
    // never captures: pointers anywhere but the grip fall through to whatever
    // shares this strip (the waveform scrollbar, the panel body).
    final seam = IgnorePointer(
      child: Container(
        width: horizontal ? double.infinity : 1,
        height: horizontal ? 1 : double.infinity,
        color: Tokens.line,
      ),
    );

    void setDragging(bool v) => setState(() => _dragging = v);

    // The grab target is the grip alone (padded a little for comfort), never
    // the whole divider line.
    final gripHit = MouseRegion(
      cursor: horizontal
          ? SystemMouseCursors.resizeRow
          : SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: horizontal ? (_) => setDragging(true) : null,
        onVerticalDragEnd: horizontal ? (_) => setDragging(false) : null,
        onVerticalDragCancel: horizontal ? () => setDragging(false) : null,
        onVerticalDragUpdate: horizontal
            ? (d) => widget.onDelta(d.delta.dy)
            : null,
        onHorizontalDragStart: horizontal ? null : (_) => setDragging(true),
        onHorizontalDragEnd: horizontal ? null : (_) => setDragging(false),
        onHorizontalDragCancel: horizontal ? null : () => setDragging(false),
        onHorizontalDragUpdate: horizontal
            ? null
            : (d) => widget.onDelta(d.delta.dx),
        child: SizedBox(
          // Localized grab box around the grip: generous enough to catch, but
          // far short of the full seam so the strip stays free elsewhere.
          width: horizontal ? _gripLong + 24 : widget.hitThickness,
          height: horizontal ? widget.hitThickness : _gripLong + 24,
          child: Center(child: grip),
        ),
      ),
    );

    return SizedBox(
      width: horizontal ? double.infinity : widget.hitThickness,
      height: horizontal ? widget.hitThickness : double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          seam,
          Semantics(
            label: widget.label,
            onIncrease: () => widget.onDelta(widget.step),
            onDecrease: () => widget.onDelta(-widget.step),
            child: Focus(
              onKeyEvent: _onKey,
              onFocusChange: (f) => setState(() => _focused = f),
              child: gripHit,
            ),
          ),
        ],
      ),
    );
  }
}
