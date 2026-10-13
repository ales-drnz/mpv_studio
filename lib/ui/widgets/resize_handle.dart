import 'package:flutter/material.dart';

import '../tokens.dart';

/// A draggable separator for resizing adjacent panes. The seam is a constant
/// faint hairline; the affordance is a short **rounded grip** centred on it
/// that brightens on hover and lights up [Tokens.accent] while grabbed.
///
/// Only the **grip** is interactive (plus a small margin around it) — the rest
/// of the seam ignores pointers, so it never steals drags from a control that
/// shares the same strip (e.g. the waveform's scrollbar that the meter's
/// bottom resize line overlaps).
///
/// [axis] is the orientation of the seam: [Axis.horizontal] separates a
/// top/bottom split (drag vertically), [Axis.vertical] separates a left/right
/// split (drag horizontally). [onDelta] reports the drag delta along the
/// resize direction each update.
class ResizeHandle extends StatefulWidget {
  final Axis axis;
  final ValueChanged<double> onDelta;

  /// Width (vertical) / height (horizontal) of the invisible grab area around
  /// the seam, so it's easy to catch with the pointer.
  final double hitThickness;

  const ResizeHandle({
    super.key,
    required this.axis,
    required this.onDelta,
    this.hitThickness = 9,
  });

  @override
  State<ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<ResizeHandle> {
  bool _hovering = false;
  bool _dragging = false;

  static const double _gripLong = 44; // length along the seam
  static const double _gripShort = 6; // thickness across the seam

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    final gripColor = _dragging
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

    // Full-length seam behind the grip — purely visual. IgnorePointer so it
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
          // Localized grab box around the grip — generous enough to catch, but
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
      child: Stack(alignment: Alignment.center, children: [seam, gripHit]),
    );
  }
}
