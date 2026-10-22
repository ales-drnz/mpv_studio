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
