import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../layout/layout_scope.dart';
import '../../tokens.dart';

/// The height of a field-like control (dropdown, segmented picker, text
/// field) here: [Tokens.controlH] with a pointer, at least the touch
/// target (`context.layout.minTap`) on touch.
double controlHeightOf(BuildContext context) =>
    math.max(Tokens.controlH, context.layout.minTap);
