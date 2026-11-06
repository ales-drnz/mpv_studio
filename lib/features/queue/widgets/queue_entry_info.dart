import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../util/duration_format.dart';
import '../../../util/media_labels.dart';
import '../queue_details.dart';
import 'queue_tile.dart';

/// Everything known about one queue entry, with its main actions. The
/// detail side of the Queue on wide windows, and a sheet elsewhere.
class QueueEntryInfo extends StatelessWidget {
  const QueueEntryInfo({
    super.key,
    required this.index,
    required this.count,
    required this.media,
    required this.info,
    required this.outcome,
    required this.current,
    required this.player,
    required this.onPlay,
    required this.onCopy,
    required this.onRemove,
  });

  final int index;
  final int count;
  final Media media;
  final QueueRowInfo info;
  final EntryOutcome? outcome;
  final bool current;
  final PlayerApi player;
  final VoidCallback onPlay;
  final VoidCallback onCopy;
  final VoidCallback onRemove;

  String get _status {
    final o = outcome;
    // A current entry with an outcome failed to open: it is not playing.
    if (o?.end == EntryEnd.failed) return 'Failed: ${o!.reason}';
    if (current) return 'Now playing';
    if (o == null) return 'Not played yet';
    return switch (o.end) {
      EntryEnd.ended => 'Played to the end',
      EntryEnd.stopped => 'Skipped',
      EntryEnd.failed => 'Failed: ${o.reason}',
      EntryEnd.cut => o.reason,
    };
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final failed = outcome?.end == EntryEnd.failed;
    final rows = <(String, String)>[
      if (info.artist != null) ('Artist', info.artist!),
      if (info.album != null) ('Album', info.album!),
      ('Source', info.origin.label),
      (
        'Length',
        info.duration == null ? 'Unknown' : formatDuration(info.duration!),
      ),
      ('Position', '${index + 1} of $count'),
      ('Status', _status),
      if (failed && outcome!.code != 0) ('Error code', '${outcome!.code}'),
    ];
    final buttonSize = Size(0, layout.minTap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The title centred on the cover; it takes only the lines it
        // needs (up to three).
        Row(
          children: [
            QueueThumb(
              artUrl: info.artUrl,
              current: current,
              player: player,
              size: 72,
              radius: Tokens.rLg,
            ),
            const SizedBox(width: Tokens.s16),
            Expanded(
              child: SelectableText(
                info.title,
                style: Tokens.heading,
                minLines: 1,
                maxLines: 3,
              ),
            ),
          ],
        ),
        const SizedBox(height: Tokens.s16),
        // The labels take the width of the longest at the reader's text
        // size, and sit on the values' first baseline.
        Padding(
          padding: const EdgeInsets.only(bottom: Tokens.s8),
          child: Table(
            columnWidths: const {
              0: IntrinsicColumnWidth(),
              1: FlexColumnWidth(),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              for (final (label, value) in [
                ...rows,
                ('Location', shareableLocation(media)),
              ])
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                        right: Tokens.s16,
                        bottom: Tokens.s8,
                      ),
                      child: Text(label, style: Tokens.caption),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: Tokens.s8),
                      child: SelectableText(
                        value,
                        style: Tokens.body.copyWith(
                          color: label == 'Status' && failed
                              ? Tokens.red
                              : Tokens.fg,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        Wrap(
          spacing: Tokens.s8,
          runSpacing: Tokens.s8,
          children: [
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(current ? 'Restart' : 'Play'),
              style: FilledButton.styleFrom(minimumSize: buttonSize),
            ),
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.link_rounded),
              label: const Text('Copy location'),
              style: OutlinedButton.styleFrom(minimumSize: buttonSize),
            ),
            OutlinedButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Remove'),
              // Red on the tonal fill is too faint for text: the icon
              // carries the warning, the label stays in the tonal ink.
              style: OutlinedButton.styleFrom(
                minimumSize: buttonSize,
                iconColor: Tokens.red,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
