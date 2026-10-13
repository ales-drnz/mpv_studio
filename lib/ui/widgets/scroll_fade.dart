import 'package:flutter/material.dart';

import '../tokens.dart';

/// Fades the edges of a scrolling [child] (a row of chips, a rail) over
/// [extent] wherever more content waits beyond them, the cue that the
/// strip scrolls. Edges with nothing hidden stay sharp. It reads the
/// child's own scroll notifications, so the child needs no controller
/// from here; it follows scrolls, resizes and content changes.
class ScrollFade extends StatefulWidget {
  const ScrollFade({
    super.key,
    required this.child,
    this.axis = Axis.horizontal,
    this.extent = Tokens.s24,
  });

  /// The scrollable to fade.
  final Widget child;

  /// The direction [child] scrolls in.
  final Axis axis;

  /// How far in from an edge the fade runs.
  final double extent;

  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<ScrollFade> {
  bool _less = false;
  bool _more = false;

  bool _update(ScrollMetrics m, int depth) {
    if (depth != 0 || m.axis != widget.axis || !mounted) return false;
    final less = m.pixels > m.minScrollExtent + 1;
    final more = m.pixels < m.maxScrollExtent - 1;
    if (less != _less || more != _more) {
      setState(() {
        _less = less;
        _more = more;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = widget.axis == Axis.horizontal;
    // The ShaderMask stays in the tree with no fade to show, so the
    // scrollable under it never remounts and keeps its offset.
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _update(n.metrics, n.depth),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => _update(n.metrics, n.depth),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) {
            final length = horizontal ? rect.width : rect.height;
            final f = length <= 0
                ? 0.0
                : (widget.extent / length).clamp(0.0, 0.5).toDouble();
            return LinearGradient(
              begin: horizontal ? Alignment.centerLeft : Alignment.topCenter,
              end: horizontal ? Alignment.centerRight : Alignment.bottomCenter,
              colors: [
                _less ? Colors.transparent : Colors.black,
                Colors.black,
                Colors.black,
                _more ? Colors.transparent : Colors.black,
              ],
              stops: [0, f, 1 - f, 1],
            ).createShader(rect);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
