import 'package:flutter/material.dart';

import '../tokens.dart';

/// The keyboard focus indicator of every custom control: a 2 px ring in
/// [Tokens.accent], 2 px outside the control, in the control's own
/// [shape]. It shows while the control (or anything inside it) has focus
/// and the focus highlight is in keyboard mode: a touch hides it (Flutter
/// counts a mouse as a keyboard-mode device, so a control that takes
/// focus on click shows it).
///
/// It takes no focus itself: wrap a control that is already focusable
/// (an InkWell, a Focus) and the ring follows it. The ring paints outside
/// [child]'s bounds, so leave room for it or let it overlap the
/// neighbours; [inside] draws it just within them instead, for a row in
/// a card that clips its edges.
class FocusRing extends StatefulWidget {
  const FocusRing({
    super.key,
    required this.child,
    this.shape = const StadiumBorder(),
    this.inside = false,
  });

  final Widget child;

  /// The control's outline; the ring follows it, grown by its gap.
  final ShapeBorder shape;

  /// Whether the ring sits within the control's bounds.
  final bool inside;

  /// The ring's width and its gap from the control.
  static const double width = 2;
  static const double gap = 2;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;

  bool get _keyboard =>
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onMode);
    super.dispose();
  }

  void _onMode(FocusHighlightMode mode) {
    if (_focused && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: (f) => setState(() => _focused = f),
      child: CustomPaint(
        foregroundPainter: _focused && _keyboard
            ? FocusRingPainter(
                widget.shape,
                Tokens.accent,
                inside: widget.inside,
              )
            : null,
        child: widget.child,
      ),
    );
  }
}

/// Paints the ring; public so tests can tell it from other painters.
@visibleForTesting
class FocusRingPainter extends CustomPainter {
  FocusRingPainter(this.shape, this.color, {this.inside = false});

  final ShapeBorder shape;
  final Color color;
  final bool inside;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = inside
        ? (Offset.zero & size).deflate(FocusRing.width / 2)
        : (Offset.zero & size).inflate(FocusRing.gap + FocusRing.width / 2);
    canvas.drawPath(
      shape.getOuterPath(rect),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = FocusRing.width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(FocusRingPainter old) =>
      old.shape != shape || old.color != color || old.inside != inside;
}
