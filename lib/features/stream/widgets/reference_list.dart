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
    initialData: player.state.playlist,
    builder: (context, snap) =>
        builder(context, snap.data ?? player.state.playlist),
  );
}

/// A tab body: a scrolling column at the page's gutter, the last item clear
/// of the bottom edge.
class StreamTabBody extends StatelessWidget {
  const StreamTabBody({super.key, required this.children, this.controller});

  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    return ListView(
      controller: controller,
      padding: EdgeInsets.only(
        top: Tokens.s8,
        bottom: layout.isShort ? Tokens.s16 : Tokens.s32,
      ),
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
  return [
    for (final cat in categories) ...[
      SectionHeader(cat.name),
      for (final item in cat.items)
        _ReferenceRow(
          item: item,
          media: toMedia(item),
          actions: actions,
          icon: icon,
          current: toMedia(item).uri == origin,
        ),
      const SizedBox(height: Tokens.s16),
    ],
  ];
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
