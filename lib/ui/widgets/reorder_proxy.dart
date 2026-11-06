import 'package:flutter/material.dart';

import '../tokens.dart';

/// The look of an item while a reorderable list drags it: the item
/// itself, with its own [shape] lifted by the token shadow and a tonal
/// step (the hover wash), and no
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
          // A tonal step over the item as it rises: in dark the shadow
          // alone hardly shows on the stage, and the rows it passes
          // read through.
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: inset,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    shape: shape,
                    color: Tokens.accentWash.withValues(
                      alpha: Tokens.accentWash.a * t,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
