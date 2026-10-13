import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../util/duration_format.dart';

/// Whether folders can be picked here: file_selector has no folder picker
/// on iOS (or the web).
bool get canPickFolder =>
    !kIsWeb && defaultTargetPlatform != TargetPlatform.iOS;

/// One button of the Queue header.
class QueueHeaderAction {
  const QueueHeaderAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.primary = false,
    this.disabledReason,
  });

  final IconData icon;
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool primary;

  /// Shown as the tooltip of a disabled button.
  final String? disabledReason;
}

/// The Queue header buttons: labelled pills on wide pointer windows (the
/// primary one filled), bare round icons with tooltips elsewhere.
List<Widget> queueHeaderButtons(
  BuildContext context,
  List<QueueHeaderAction> actions,
) {
  final layout = context.layout;
  final labelled = layout.isPointer && layout.width.atLeast(WidthClass.large);
  Widget button(QueueHeaderAction a) {
    if (!labelled) {
      // A disabled button says why; an enabled one names itself.
      return RoundIconButton(
        icon: a.icon,
        tooltip: a.onPressed == null ? a.disabledReason ?? a.label : a.label,
        label: a.label,
        onTap: a.onPressed,
      );
    }
    final icon = Icon(a.icon, size: 18);
    return a.primary
        ? FilledButton.icon(
            onPressed: a.onPressed,
            icon: icon,
            label: Text(a.label),
          )
        : TextButton.icon(
            onPressed: a.onPressed,
            icon: icon,
            label: Text(a.label),
            style: TextButton.styleFrom(foregroundColor: Tokens.fg),
          );
  }

  return [
    for (final a in actions)
      Padding(
        padding: EdgeInsets.only(left: labelled ? Tokens.s8 : Tokens.s4),
        // A disabled pill says why.
        child: labelled && a.onPressed == null
            ? Tooltip(message: a.disabledReason ?? a.label, child: button(a))
            : button(a),
      ),
  ];
}

/// The line under the title: how many entries the queue holds and how long
/// it plays, and a progress bar while picked files are being added.
class QueueSummary extends StatelessWidget {
  const QueueSummary({
    super.key,
    required this.count,
    required this.known,
    required this.unknown,
    required this.adding,
  });

  final int count;

  /// The total length of the entries whose length is known.
  final Duration known;

  /// How many entries have no known length yet.
  final int unknown;

  /// Files still being added.
  final int adding;

  /// The summary text, e.g. "12 tracks, 47:13".
  static String describe(int count, Duration known, int unknown) {
    final tracks = count == 1 ? '1 track' : '$count tracks';
    if (count == 0) return tracks;
    if (unknown == count) return tracks;
    final length = formatDuration(known);
    return unknown == 0 ? '$tracks, $length' : '$tracks, at least $length';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            adding > 0
                ? 'Adding ${adding == 1 ? '1 file' : '$adding files'}'
                : describe(count, known, unknown),
            style: Tokens.caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: Tokens.s4),
        SizedBox(
          height: 4,
          child: adding > 0
              ? ClipPath(
                  clipper: const ShapeBorderClipper(shape: StadiumBorder()),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    color: Tokens.accent,
                    backgroundColor: Tokens.surface4,
                  ),
                )
              : null,
        ),
        const SizedBox(height: Tokens.s8),
      ],
    );
  }
}
