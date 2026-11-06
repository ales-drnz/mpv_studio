import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../layout/layout_scope.dart';
import '../../tokens.dart';

/// The height of a field-like control (dropdown, segmented picker, text
/// field) here: [Tokens.controlH] with a pointer, the touch target on
/// touch (`context.layout.minTap`, the same as every button), and taller
/// when the text scale would bring its body line close to the edges.
double controlHeightOf(BuildContext context) => math.max(
  math.max(Tokens.controlH, context.layout.minTap),
  MediaQuery.textScalerOf(context).scale(20) + Tokens.s12,
);
