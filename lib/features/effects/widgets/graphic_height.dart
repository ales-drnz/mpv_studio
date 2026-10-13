import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The height of a stage's graphic: [ratio] of the [width] it gets, kept
/// within [min] and [max], and never more than a quarter of the window
/// height, so on a low window the first controls under it stay on screen.
double graphicHeight(
  BuildContext context,
  double width, {
  double ratio = 0,
  required double min,
  required double max,
}) {
  final cap = math.max(80.0, MediaQuery.sizeOf(context).height * 0.25);
  return math.min((width * ratio).clamp(min, max), cap);
}
