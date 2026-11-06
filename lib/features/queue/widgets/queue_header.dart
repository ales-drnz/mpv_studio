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
    this.destructive = false,
    this.disabledReason,
  });

  final IconData icon;
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final bool primary;

  /// Whether it removes something (red in the menu).
  final bool destructive;

  /// Shown as the tooltip of a disabled button.
  final String? disabledReason;
}

/// The Queue header buttons. With a pointer and [available] page width
/// for the title and four pills ([labelledWidth]; the window's width when
/// not given) each is a labelled pill (the primary one filled); with less
/// room, or on touch, the
/// primary keeps its label and the rest fold into a menu, the removing
/// one in red, so no action is a bare icon beside another of equal weight.
List<Widget> queueHeaderButtons(
  BuildContext context,
  List<QueueHeaderAction> actions, {
  double? available,
}) {
  if (actions.isEmpty) return const [];
  final layout = context.layout;
  final room = available ?? MediaQuery.sizeOf(context).width;
  final labelled = layout.isPointer && room >= labelledWidth;
  Widget pill(QueueHeaderAction a) {
    final icon = Icon(a.icon);
    final Widget button = a.primary
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
    // A disabled pill says why.
    return a.onPressed == null
        ? Tooltip(message: a.disabledReason ?? a.label, child: button)
        : button;
  }

  if (labelled) {
    return [
      for (final a in actions)
        Padding(
          padding: const EdgeInsets.only(left: Tokens.s8),
          child: pill(a),
        ),
    ];
  }
  final primary = actions.where((a) => a.primary).toList();
  final rest = actions.where((a) => !a.primary).toList();
  return [
    for (final a in primary) pill(a),
    if (rest.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(left: Tokens.s4),
        child: Builder(
          builder: (context) => RoundIconButton(
            icon: Icons.more_vert_rounded,
            tooltip: 'More queue actions',
            onTap: () async {
              final box = context.findRenderObject() as RenderBox?;
              final picked = await showStudioMenu<QueueHeaderAction>(
                context,
                position: box?.localToGlobal(box.size.bottomLeft(Offset.zero)),
                title: 'Queue',
                items: [
                  for (final a in rest)
                    StudioMenuItem(
                      value: a,
                      label: a.label,
                      icon: a.icon,
                      enabled: a.onPressed != null,
                      destructive: a.destructive,
                    ),
                ],
              );
              picked?.onPressed?.call();
            },
          ),
        ),
      ),
  ];
}

/// The page width that fits the title beside the four labelled pills.
const double labelledWidth = 760;

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
                  child: LinearProgressIndicator(minHeight: Tokens.progressH),
                )
              : null,
        ),
        const SizedBox(height: Tokens.s8),
      ],
    );
  }
}
