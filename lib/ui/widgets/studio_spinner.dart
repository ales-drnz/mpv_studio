import 'package:flutter/material.dart';

import '../tokens.dart';

/// The one circular progress of the app: [Tokens.strokeProgress] wide,
/// round ends, the accent on the theme's track. [value] makes it
/// determinate; [onAccent] draws it inside a solid accent fill (the play
/// circle, a primary button), with no track.
class StudioSpinner extends StatelessWidget {
  const StudioSpinner({
    super.key,
    this.size = 18,
    this.value,
    this.onAccent = false,
  });

  /// The diameter.
  final double size;

  /// The fraction done, or null while it only waits.
  final double? value;

  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CircularProgressIndicator(
        value: value,
        strokeWidth: Tokens.strokeProgress,
        strokeCap: StrokeCap.round,
        color: onAccent ? Tokens.onAccent : Tokens.accent,
        backgroundColor: onAccent ? Colors.transparent : Tokens.surface4,
      ),
    );
  }
}
