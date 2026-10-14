import 'package:flutter/material.dart';

import '../tokens.dart';

/// The look of an item while a reorderable list drags it: the item
/// itself, with its own [shape] lifted by the token shadow, and no
/// Material background (the default proxy is a rectangle of the canvas
/// colour with an elevation, which shows as a dark box around a rounded
/// row). [inset] is the room the item keeps around its shape, such as
/// the gap a row leaves under itself, so the shadow hugs the shape.
///
/// Use it as `proxyDecorator: reorderProxy(shape: ...)`.
Widget Function(Widget, int, Animation<double>) reorderProxy({
  required ShapeBorder shape,
  EdgeInsets inset = EdgeInsets.zero,
}) {
  return (child, index, animation) => AnimatedBuilder(
    animation: animation,
    child: Material(type: MaterialType.transparency, child: child),
    builder: (context, child) {
      final t = Curves.easeOut.transform(animation.value);
      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: inset,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: shape,
                  shadows: Tokens.lift(t),
                ),
              ),
            ),
          ),
          child!,
        ],
      );
    },
  );
}

/// Adapts [onMove], which takes the index the item ends up at, to a
/// reorderable list's `onReorder`, whose new index counts the moved item
/// still in its old place (one past the final index when the item moves
/// down). Flutter 3.41 added `onReorderItem`, which passes the final
/// index, and deprecated `onReorder`; the app keeps `onReorder` while it
/// supports Flutter 3.38.
///
/// Use it as `onReorder: reorderTo(move)`.
ReorderCallback reorderTo(void Function(int from, int to) onMove) =>
    (from, to) => onMove(from, to > from ? to - 1 : to);
