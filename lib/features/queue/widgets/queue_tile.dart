import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
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
/// outcome of its last play, the length, and the drag handle.
///
/// With a pointer the play, remove and more buttons show on hover and on
/// the selected row. On touch the whole row is the tap target and the
/// handle starts a reorder after a long press.
class QueueTile extends StatefulWidget {
  const QueueTile({
    super.key,
    required this.index,
    required this.info,
    required this.outcome,
    required this.current,
    required this.selected,
    required this.player,
    required this.onTap,
    required this.onPlay,
    required this.onRemove,
    required this.onMore,
  });

  final int index;
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

    final Widget lead;
    if (_failed) {
      lead = Icon(Icons.error_outline_rounded, size: 18, color: Tokens.red);
    } else if (current) {
      lead = Icon(Icons.volume_up_rounded, size: 18, color: Tokens.accent);
    } else {
      lead = Text(
        '${widget.index + 1}',
        style: Tokens.numeric,
        maxLines: 1,
        textAlign: TextAlign.center,
      );
    }

    final titleColor = _failed
        ? Tokens.fgDim
        : (current ? Tokens.accent : Tokens.fg);
    final Color background;
    if (current) {
      background = Tokens.accentWash;
    } else if (widget.selected) {
      background = Tokens.surface2;
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
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(info.origin.icon, size: 12, color: Tokens.fgFaint),
            const SizedBox(width: Tokens.s4),
            if (widget.outcome != null) ...[
              OutcomeBadge(widget.outcome!),
              const SizedBox(width: Tokens.s6),
            ],
            Flexible(
              child: Text(
                _failed ? widget.outcome!.reason : info.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _failed
                    ? Tokens.caption.copyWith(color: Tokens.red)
                    : Tokens.caption,
              ),
            ),
          ],
        ),
      ],
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(
        Tokens.s8,
        Tokens.s6,
        Tokens.s4,
        Tokens.s6,
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Center(child: lead)),
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
            Text(formatDuration(info.duration!), style: Tokens.numeric),
          ],
          if (showActions) ...[
            const SizedBox(width: Tokens.s4),
            _RowButton(
              icon: Icons.play_arrow_rounded,
              tooltip: 'Play',
              onPressed: widget.onPlay,
            ),
            _RowButton(
              icon: Icons.close_rounded,
              tooltip: 'Remove',
              onPressed: widget.onRemove,
            ),
            Builder(
              builder: (context) => _RowButton(
                icon: Icons.more_vert_rounded,
                tooltip: 'More',
                onPressed: () {
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
            index: widget.index,
            child: _Handle(size: layout.minTap),
          )
        : ReorderableDragStartListener(
            index: widget.index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Tooltip(
                message: 'Drag to reorder',
                child: _Handle(size: layout.minTap),
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: ShapeDecoration(
              color: background,
              shape: Tokens.squircle(
                Tokens.rSm,
                side: widget.selected && !current
                    ? BorderSide(color: Tokens.line2)
                    : BorderSide.none,
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: touch ? 56 : 48),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: widget.selected,
                      label: _semanticLabel,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onSecondaryTapUp: (d) =>
                            widget.onMore(d.globalPosition),
                        onLongPress: touch ? () => widget.onMore(null) : null,
                        child: InkWell(
                          onTap: widget.onTap,
                          customBorder: Tokens.squircle(Tokens.rSm),
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
  const _Handle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Icon(Icons.drag_indicator_rounded, size: 20, color: Tokens.fgFaint),
  );
}

class _RowButton extends StatelessWidget {
  const _RowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    tooltip: tooltip,
    icon: Icon(icon, size: 18),
    color: Tokens.fgDim,
    constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    padding: EdgeInsets.zero,
  );
}

/// How an entry's last play ended, as a small pill: red for a failure.
class OutcomeBadge extends StatelessWidget {
  const OutcomeBadge(this.outcome, {super.key});

  final EntryOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final failed = outcome.end == EntryEnd.failed;
    final label = switch (outcome.end) {
      EntryEnd.ended => 'Played',
      EntryEnd.stopped => 'Skipped',
      EntryEnd.failed => 'Failed',
    };
    final color = failed ? Tokens.red : Tokens.fgDim;
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s6, vertical: 1),
      decoration: ShapeDecoration(
        color: failed ? Tokens.red.withValues(alpha: 0.14) : Tokens.surface3,
        shape: Tokens.squircle(Tokens.rPill),
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
  });

  final String? artUrl;
  final bool current;
  final PlayerApi player;
  final double size;

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
        errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
      );
    } else if (current) {
      image = Live<CoverArt?>(
        stream: player.stream.coverArt,
        initial: player.state.coverArt,
        builder: (context, art) => art == null
            ? const _ThumbPlaceholder()
            : Image.memory(
                art.bytes,
                width: size,
                height: size,
                fit: BoxFit.cover,
                cacheWidth: cache,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const _ThumbPlaceholder(),
              ),
      );
    } else {
      image = const _ThumbPlaceholder();
    }
    return ClipPath(
      clipper: ShapeBorderClipper(shape: Tokens.squircle(6)),
      child: SizedBox(width: size, height: size, child: image),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Tokens.surface2,
    child: Center(
      child: Icon(Icons.music_note_rounded, size: 16, color: Tokens.fgFaint),
    ),
  );
}
