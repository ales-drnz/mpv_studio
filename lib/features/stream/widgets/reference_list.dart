import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/section_header.dart';
import '../stream_actions.dart';
import '../stream_catalog.dart';
import 'stream_row.dart';

/// The current queue entry of [player], or null when nothing is loaded.
Media? currentMedia(Playlist pl) =>
    pl.index >= 0 && pl.index < pl.items.length ? pl.items[pl.index] : null;

/// The key that lights up the row that started the current track: the
/// `origin` extra when set, else the media URI. Empty when nothing plays.
String playingOrigin(Playlist pl) {
  final m = currentMedia(pl);
  if (m == null) return '';
  return (m.extras?['origin'] as String?) ?? m.uri;
}

/// Rebuilds with the queue of [player].
class PlaylistBuilder extends StatelessWidget {
  const PlaylistBuilder({
    super.key,
    required this.player,
    required this.builder,
  });

  final PlayerApi player;
  final Widget Function(BuildContext context, Playlist playlist) builder;

  @override
  Widget build(BuildContext context) => StreamBuilder<Playlist>(
    stream: player.stream.playlist,
    initialData: player.state.playback.playlist,
    builder: (context, snap) =>
        builder(context, snap.data ?? player.state.playback.playlist),
  );
}

/// A tab body: a scrolling column at the page's gutter, the last item at
/// the page end ([PageEnd]).
class StreamTabBody extends StatelessWidget {
  const StreamTabBody({super.key, required this.children, this.controller});

  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: PageEnd.padding(context, top: Tokens.s8),
      children: children,
    );
  }
}

/// The rows of [categories], each under its header, with the row that
/// started the current track lit up. [mediaFor] turns an item into the
/// entry to play (defaults to [streamMedia]); [icon] is the rows' glyph.
List<Widget> referenceRows({
  required List<StreamCategory> categories,
  required StreamActions actions,
  required String origin,
  Media Function(StreamItem item)? mediaFor,
  IconData icon = Icons.podcasts_rounded,
}) {
  final toMedia = mediaFor ?? streamMedia;
  // Gaps between the categories and the rows only: the last row ends at
  // the page end.
  return [
    for (final (c, cat) in categories.indexed) ...[
      if (c > 0) const SizedBox(height: Tokens.s16),
      SectionHeader(cat.name),
      for (final (i, item) in cat.items.indexed) ...[
        if (i > 0) const SizedBox(height: StreamRow.gap),
        _ReferenceRow(
          item: item,
          media: toMedia(item),
          actions: actions,
          icon: icon,
          current: toMedia(item).uri == origin,
        ),
      ],
    ],
  ];
}

/// The rows of [categories] as [referenceRows] lays them, in two columns
/// when the tab has room for two of a card's readable width: the
/// categories fill the first column, then the second, in order, the two
/// about as long.
class ReferenceColumns extends StatelessWidget {
  const ReferenceColumns({
    super.key,
    required this.categories,
    required this.actions,
    required this.origin,
    this.mediaFor,
    this.icon = Icons.podcasts_rounded,
  });

  final List<StreamCategory> categories;
  final StreamActions actions;
  final String origin;
  final Media Function(StreamItem item)? mediaFor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    List<Widget> rows(List<StreamCategory> cats) => referenceRows(
      categories: cats,
      actions: actions,
      origin: origin,
      mediaFor: mediaFor,
      icon: icon,
    );
    return LayoutBuilder(
      builder: (context, c) {
        final gap = context.layout.gap;
        if (categories.length < 2 ||
            c.maxWidth < 2 * Breakpoints.cardColumn + gap) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rows(categories),
          );
        }
        // The split that leaves the two columns closest in rows.
        final total = categories.fold(0, (n, c) => n + c.items.length + 1);
        var split = 1, best = total;
        var acc = 0;
        for (var i = 0; i < categories.length - 1; i++) {
          acc += categories[i].items.length + 1;
          final diff = (total - 2 * acc).abs();
          if (diff < best) {
            best = diff;
            split = i + 1;
          }
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, part) in [
              categories.sublist(0, split),
              categories.sublist(split),
            ].indexed) ...[
              if (i > 0) SizedBox(width: gap),
              // A traversal group per column: Tab reads down the first.
              Expanded(
                child: FocusTraversalGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: rows(part),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  const _ReferenceRow({
    required this.item,
    required this.media,
    required this.actions,
    required this.icon,
    required this.current,
  });

  final StreamItem item;
  final Media media;
  final StreamActions actions;
  final IconData icon;
  final bool current;

  @override
  Widget build(BuildContext context) {
    return StreamRow(
      title: item.label,
      subtitle: item.url,
      monoSubtitle: true,
      icon: icon,
      current: current,
      onTap: () => actions.play(media),
      menu: () => [for (final a in RowAction.queueActions) a.item],
      onMenu: (a) => actions.run(a, [media]),
      trailing: [
        RowButton(
          icon: Icons.playlist_add_rounded,
          tooltip: 'Add to queue',
          onPressed: () => actions.enqueue([media]),
        ),
        // A tap on the row plays; a phone keeps its width for the title.
        if (!context.layout.isCompact)
          RowButton(
            icon: Icons.play_arrow_rounded,
            tooltip: 'Play',
            onPressed: () => actions.play(media),
          ),
      ],
    );
  }
}
