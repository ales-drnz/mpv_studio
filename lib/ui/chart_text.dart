import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// The text scale the labels painted inside charts follow: the reader's,
/// capped at [Tokens.chartLabelMaxScale], past which labels would crowd
/// the plot they label. Painters take it from the widget that builds
/// them.
TextScaler chartTextScaler(BuildContext context) => MediaQuery.textScalerOf(
  context,
).clamp(maxScaleFactor: Tokens.chartLabelMaxScale);

/// Paints a short monospace label onto a [Canvas]: the single text helper
/// shared by every chart and meter painter (response curve, knee plot,
/// goniometer, gauges, VU meter and the Engine charts).
///
/// [at] is the anchor: the top-left by default, the top-centre when
/// [center] is set (x only), the top-right when [end] is set, and the
/// dead-centre when [middle] is also set (x and y): the schematic diagrams
/// use the latter to place node labels. [scaler] grows the label with
/// the reader's text size (see [chartTextScaler]).
void paintChartLabel(
  Canvas canvas,
  String text,
  Offset at,
  Color color, {
  double fontSize = Tokens.chartLabelSize,
  TextScaler scaler = TextScaler.noScaling,
  bool center = false,
  bool middle = false,
  bool end = false,
}) {
  final tp = _layout(text, color, fontSize, scaler);
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
double chartLabelWidth(
  String text, {
  double fontSize = Tokens.chartLabelSize,
  TextScaler scaler = TextScaler.noScaling,
}) => _layout(text, const Color(0xFF000000), fontSize, scaler).width;

/// The height [paintChartLabel] gives a line, to reserve room for an
/// axis.
double chartLabelHeight({
  double fontSize = Tokens.chartLabelSize,
  TextScaler scaler = TextScaler.noScaling,
}) => scaler.scale(fontSize);

TextPainter _layout(
  String text,
  Color color,
  double fontSize,
  TextScaler scaler,
) => TextPainter(
  textDirection: TextDirection.ltr,
  textScaler: scaler,
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
