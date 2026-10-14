import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../util/duration_format.dart';
import '../../../util/media_labels.dart';
import '../../../util/reactive.dart';
import '../queue_details.dart';

/// The icon of each source.
extension MediaOriginIcon on MediaOrigin {
  IconData get icon => switch (this) {
    MediaOrigin.file => Icons.audio_file_outlined,
    MediaOrigin.http => Icons.public_rounded,
    MediaOrigin.smb => Icons.lan_outlined,
    MediaOrigin.jellyfin => Icons.dns_outlined,
    MediaOrigin.plex => Icons.storage_rounded,
  };
}

/// One queue row: position or state, cover, title, artist and source, the
/// outcome of its last play, the length, and the drag handle. A card tone
/// row; the selected one a field tone, the current one the secondary
/// selection fill with its content in [Tokens.onAccentContainer].
///
/// With a pointer the play, remove and more buttons show on hover and on
/// the selected row. On touch the whole row is the tap target and the
/// handle starts a reorder after a long press.
class QueueTile extends StatefulWidget {
  const QueueTile({
    super.key,
    required this.index,
    required this.row,
    required this.info,
    required this.outcome,
    required this.current,
    required this.selected,
    required this.player,
    required this.onTap,
    required this.onPlay,
    required this.onRemove,
    required this.onMore,
    this.gap = Tokens.s4,
  });

  /// The entry's position in the queue, shown on the row.
  final int index;

  /// The row's position in the list, which the drag handle reports; it
  /// differs from [index] while a swiped row is hidden.
  final int row;
  final QueueRowInfo info;

  /// How its last play ended, null while it plays or before it played.
  final EntryOutcome? outcome;
  final bool current;
  final bool selected;

  /// Read for the embedded cover of the current entry.
  final PlayerApi player;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  /// Opens the row's menu, at the global position when there is one.
  final void Function(Offset? position) onMore;

  /// The space under the row, before the next one; 0 for the last row,
  /// which ends at the page end.
  final double gap;

  @override
  State<QueueTile> createState() => _QueueTileState();
}

class _QueueTileState extends State<QueueTile> {
  bool _hovered = false;

  bool get _failed => widget.outcome?.end == EntryEnd.failed;

  String get _semanticLabel {
    final info = widget.info;
    final parts = [
      'Track ${widget.index + 1}',
      info.title,
      info.subtitle,
      if (info.duration != null) formatDuration(info.duration!),
      if (widget.current) 'now playing',
      if (widget.outcome != null)
        _failed ? 'failed: ${widget.outcome!.reason}' : widget.outcome!.reason,
    ];
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final touch = layout.isTouch;
    final info = widget.info;
    final current = widget.current;
    final showActions = !touch && (_hovered || widget.selected);

    // On the current row everything takes the container's content tone;
    // the semantic red would not read on the ring grey in dark.
    final on = current ? Tokens.onAccentContainer : null;
    final Widget lead;
    if (_failed) {
      lead = Icon(
        Icons.error_outline_rounded,
        size: 20,
        color: on ?? Tokens.red,
      );
    } else if (current) {
      lead = Icon(Icons.graphic_eq_rounded, size: 20, color: on);
    } else {
      lead = Text(
        '${widget.index + 1}',
        style: Tokens.numeric,
        maxLines: 1,
        textAlign: TextAlign.center,
      );
    }

    final titleColor = on ?? (_failed ? Tokens.fgDim : Tokens.fg);
    final Color background;
    if (current) {
      background = Tokens.accentContainer;
    } else if (widget.selected) {
      background = Tokens.surface3;
    } else {
      background = Tokens.surface;
    }

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          info.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Tokens.body.copyWith(
            color: titleColor,
            fontWeight: current ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const SizedBox(height: Tokens.s4),
        Row(
          children: [
            Icon(info.origin.icon, size: 14, color: on ?? Tokens.fgFaint),
            const SizedBox(width: Tokens.s4),
            if (widget.outcome != null) ...[
              OutcomeBadge(widget.outcome!, onContainer: current),
              const SizedBox(width: Tokens.s8),
            ],
            Flexible(
              child: Text(
                _failed ? widget.outcome!.reason : info.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.caption.copyWith(
                  color: on ?? (_failed ? Tokens.red : null),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.s8,
        Tokens.s8,
        Tokens.s4,
        Tokens.s8,
      ),
      child: Row(
        children: [
          SizedBox(width: 32, child: Center(child: lead)),
          const SizedBox(width: Tokens.s8),
          QueueThumb(
            artUrl: info.artUrl,
            current: current,
            player: widget.player,
          ),
          const SizedBox(width: Tokens.s12),
          Expanded(child: text),
          if (info.duration != null) ...[
            const SizedBox(width: Tokens.s8),
            Text(
              formatDuration(info.duration!),
              style: Tokens.numeric.copyWith(color: on),
            ),
          ],
          if (showActions) ...[
            const SizedBox(width: Tokens.s4),
            RoundIconButton(
              icon: Icons.play_arrow_rounded,
              size: 20,
              tooltip: 'Play',
              color: Tokens.fgDim,
              onContainer: current,
              onTap: widget.onPlay,
            ),
            RoundIconButton(
              icon: Icons.close_rounded,
              size: 20,
              tooltip: 'Remove',
              color: Tokens.fgDim,
              onContainer: current,
              onTap: widget.onRemove,
            ),
            Builder(
              builder: (context) => RoundIconButton(
                icon: Icons.more_vert_rounded,
                size: 20,
                tooltip: 'More',
                color: Tokens.fgDim,
                onContainer: current,
                onTap: () {
                  final box = context.findRenderObject() as RenderBox?;
                  widget.onMore(
                    box?.localToGlobal(box.size.bottomLeft(Offset.zero)),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );

    final handle = touch
        ? ReorderableDelayedDragStartListener(
            index: widget.row,
            child: _Handle(size: layout.minTap, color: on),
          )
        : ReorderableDragStartListener(
            index: widget.row,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Tooltip(
                message: 'Drag to reorder',
                child: _Handle(size: layout.minTap, color: on),
              ),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(bottom: widget.gap),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: ShapeDecoration(
              color: background,
              shape: Tokens.shape(Tokens.rMd),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: widget.selected,
                      label: _semanticLabel,
                      // The row's own actions, since the children (and
                      // their gestures) are hidden from the reader; the
                      // long press menu also holds the hover buttons.
                      onTap: widget.onTap,
                      onTapHint: touch ? 'play' : 'select',
                      onLongPress: () => widget.onMore(null),
                      onLongPressHint: 'show actions',
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTapUp: (d) =>
                            widget.onMore(d.globalPosition),
                        onLongPress: touch ? () => widget.onMore(null) : null,
                        child: InkWell(
                          onTap: widget.onTap,
                          customBorder: Tokens.shape(Tokens.rMd),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                  handle,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Icon(
      Icons.drag_indicator_rounded,
      size: 20,
      color: color ?? Tokens.fgFaint,
    ),
  );
}

/// How an entry's last play ended, as a small pill: red for a failure.
/// [onContainer] draws it for the current row's secondary selection fill.
class OutcomeBadge extends StatelessWidget {
  const OutcomeBadge(this.outcome, {super.key, this.onContainer = false});

  final EntryOutcome outcome;
  final bool onContainer;

  @override
  Widget build(BuildContext context) {
    final failed = outcome.end == EntryEnd.failed;
    final label = switch (outcome.end) {
      EntryEnd.ended => 'Played',
      EntryEnd.stopped => 'Skipped',
      EntryEnd.failed => 'Failed',
    };
    final color = onContainer
        ? Tokens.onAccentContainer
        : failed
        ? Tokens.red
        : Tokens.fgDim;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
      decoration: ShapeDecoration(
        color: onContainer
            ? Tokens.onAccentContainer.withValues(alpha: 0.14)
            : failed
            ? Tokens.red.withValues(alpha: 0.14)
            : Tokens.surface3,
        shape: Tokens.pill,
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Tokens.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
    return failed ? Tooltip(message: outcome.reason, child: badge) : badge;
  }
}

/// The entry's cover: the server artwork when it has one, the embedded
/// cover for the current track, else a placeholder.
class QueueThumb extends StatelessWidget {
  const QueueThumb({
    super.key,
    required this.artUrl,
    required this.current,
    required this.player,
    this.size = 40,
    this.radius = Tokens.rSm,
  });

  final String? artUrl;
  final bool current;
  final PlayerApi player;
  final double size;

  /// The corner radius of the cover.
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = artUrl;
    final cache = (size * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget image;
    if (url != null) {
      image = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cache,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _ThumbPlaceholder(size),
      );
    } else if (current) {
      image = Live<CoverArt?>(
        stream: player.stream.coverArt,
        initial: player.state.coverArt,
        builder: (context, art) => art == null
            ? _ThumbPlaceholder(size)
            : Image.memory(
                art.bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: cache,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _ThumbPlaceholder(size),
              ),
      );
    } else {
      image = _ThumbPlaceholder(size);
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: Tokens.shape(radius)),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder(this.size);

  final double size;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Tokens.surface3,
    child: Center(
      child: Icon(
        Icons.music_note_rounded,
        size: (size * 0.45).clamp(16.0, 32.0),
        color: Tokens.fgFaint,
      ),
    ),
  );
}
