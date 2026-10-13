import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// Paints a short monospace label onto a [Canvas] — the single text helper
/// shared by every chart and meter painter (response curve, knee plot,
/// goniometer, gauges, VU meter, …), replacing the per-painter copies.
///
/// [at] is the anchor: the top-left by default, the top-centre when
/// [center] is set (x only), the top-right when [end] is set, and the
/// dead-centre when [middle] is also set (x and y): the schematic diagrams
/// use the latter to place node labels.
void paintChartLabel(
  Canvas canvas,
  String text,
  Offset at,
  Color color, {
  double fontSize = 9,
  bool center = false,
  bool middle = false,
  bool end = false,
}) {
  final tp = _layout(text, color, fontSize);
  tp.paint(
    canvas,
    Offset(
      center
          ? at.dx - tp.width / 2
          : end
          ? at.dx - tp.width
          : at.dx,
      middle ? at.dy - tp.height / 2 : at.dy,
    ),
  );
}

/// The width [paintChartLabel] gives [text], to place labels side by side.
double chartLabelWidth(String text, {double fontSize = 9}) =>
    _layout(text, const Color(0xFF000000), fontSize).width;

TextPainter _layout(String text, Color color, double fontSize) => TextPainter(
  textDirection: TextDirection.ltr,
  text: TextSpan(
    text: text,
    style: TextStyle(
      fontFamily: Tokens.mono,
      fontSize: fontSize,
      color: color,
      height: 1.0,
    ),
  ),
)..layout();
