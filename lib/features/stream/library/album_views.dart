import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../media_server.dart';
import '../stream_actions.dart';
import '../widgets/reference_list.dart';
import '../widgets/stream_row.dart';
import '../widgets/stream_states.dart';
import 'server_playback.dart';
import 'track_rows.dart';

/// Cover art of a server album or track, with a glyph while it loads or
/// when there is none.
class CoverArt extends StatelessWidget {
  const CoverArt({super.key, required this.url, this.size});

  final String? url;

  /// A fixed side; null fills the parent.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Tokens.surface2,
      child: Center(
        child: Icon(Icons.album_rounded, size: 32, color: Tokens.fgFaint),
      ),
    );
    final url = this.url;
    final Widget image = url == null
        ? placeholder
        : Image.network(
            url,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => placeholder,
            frameBuilder: (_, child, frame, sync) =>
                frame == null && !sync ? placeholder : child,
          );
    return ExcludeSemantics(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: Tokens.shape(Tokens.rSm)),
        child: SizedBox(
          width: size,
          height: size,
          child: AspectRatio(aspectRatio: 1, child: image),
        ),
      ),
    );
  }
}

/// The paged album grid: a [ResponsiveGrid] of covers that loads the next
/// page as its end comes near, with loading, empty and error states.
class AlbumGrid extends StatelessWidget {
  const AlbumGrid({
    super.key,
    required this.paging,
    required this.selected,
    required this.onOpen,
    required this.onAction,
    required this.emptyMessage,
    required this.errorView,
  });

  final PagingController<int, ServerAlbum> paging;
  final ServerAlbum? selected;
  final ValueChanged<ServerAlbum> onOpen;
  final void Function(ServerAlbum album, RowAction action) onAction;
  final String emptyMessage;

  /// The view for a failed first page.
  final Widget Function(Object error) errorView;

  @override
  Widget build(BuildContext context) {
    return PagingListener<int, ServerAlbum>(
      controller: paging,
      builder: (context, state, fetchNextPage) {
        switch (state.status) {
          case PagingStatus.loadingFirstPage:
            return _LoadMore(
              loading: state.isLoading,
              onVisible: fetchNextPage,
              label: 'Loading albums',
            );
          case PagingStatus.firstPageError:
            return errorView(state.error!);
          case PagingStatus.noItemsFound:
            return StreamMessage(
              icon: Icons.album_outlined,
              title: 'No albums',
              message: emptyMessage,
            );
          default:
        }
        final albums = state.items ?? const <ServerAlbum>[];
        return NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            if (n.metrics.extentAfter < _nearEnd &&
                state.hasNextPage &&
                !state.isLoading &&
                state.error == null) {
              fetchNextPage();
            }
            return false;
          },
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: Tokens.s4, bottom: Tokens.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveGrid(
                  minTileWidth: 132,
                  children: [
                    for (final a in albums)
                      AlbumCard(
                        album: a,
                        selected: a.id == selected?.id,
                        onTap: () => onOpen(a),
                        onAction: (action) => onAction(a, action),
                      ),
                  ],
                ),
                if (state.status == PagingStatus.subsequentPageError)
                  Padding(
                    padding: const EdgeInsets.only(top: Tokens.s12),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: fetchNextPage,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Could not load more. Retry'),
                      ),
                    ),
                  )
                else if (state.hasNextPage)
                  _LoadMore(loading: state.isLoading, onVisible: fetchNextPage),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A spinner that asks for the next page once it is built: the first page
/// when the grid opens, and the next as the end of the loaded albums comes
/// into view.
class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.loading, required this.onVisible, this.label});

  final bool loading;
  final VoidCallback onVisible;
  final String? label;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  void initState() {
    super.initState();
    _askIfNear();
  }

  @override
  void didUpdateWidget(_LoadMore old) {
    super.didUpdateWidget(old);
    if (old.loading && !widget.loading) _askIfNear();
  }

  /// Asks for the next page after this frame when the spinner is within
  /// [_nearEnd] of the viewport (or there is nothing to scroll); scrolling
  /// closer asks through the grid's scroll listener.
  void _askIfNear() {
    if (widget.loading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final position = Scrollable.maybeOf(context)?.position;
      if (position == null || position.extentAfter < _nearEnd) {
        widget.onVisible();
      }
    });
  }

  @override
  Widget build(BuildContext context) => StreamLoading(label: widget.label);
}

/// How close to the end of the grid the next page loads, in pixels.
const _nearEnd = 600.0;

/// An album tile: the cover over the title and artist, lit when its tracks
/// are open, with the queue actions as its context menu.
class AlbumCard extends StatelessWidget {
  const AlbumCard({
    super.key,
    required this.album,
    required this.selected,
    required this.onTap,
    required this.onAction,
  });

  final ServerAlbum album;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<RowAction> onAction;

  @override
  Widget build(BuildContext context) {
    final shape = Tokens.shape(Tokens.rMd);
    final sub = [
      album.artist,
      if (album.year != null) '${album.year}',
    ].where((e) => e.isNotEmpty).join(', ');
    return StudioMenuRegion<RowAction>(
      title: album.title,
      items: () => [for (final a in RowAction.queueActions) a.item],
      onSelected: onAction,
      child: Semantics(
        button: true,
        selected: selected,
        label: sub.isEmpty ? album.title : '${album.title}, $sub',
        excludeSemantics: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: Ink(
              padding: const EdgeInsets.all(Tokens.s8),
              decoration: ShapeDecoration(
                color: selected ? Tokens.accentWash : Tokens.surface,
                shape: shape,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CoverArt(url: album.artUrl),
                  const SizedBox(height: Tokens.s8),
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.body.copyWith(
                      color: selected ? Tokens.accent : Tokens.fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sub.isEmpty ? ' ' : sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Tokens.caption.copyWith(color: Tokens.fgDim),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An album's tracks: a header with the cover, title and the album's play
/// buttons over the track rows. Loads them with [load] (cached by the
/// browser), with loading, empty and error states.
class AlbumDetail extends StatefulWidget {
  const AlbumDetail({
    super.key,
    required this.album,
    required this.load,
    required this.playback,
    required this.errorView,
    this.onBack,
  });

  final ServerAlbum album;
  final Future<List<ServerTrack>> Function(ServerAlbum album) load;
  final ServerPlayback playback;
  final Widget Function(Object error, VoidCallback retry) errorView;

  /// Shows a back button (the detail covers the album grid).
  final VoidCallback? onBack;

  @override
  State<AlbumDetail> createState() => _AlbumDetailState();
}

class _AlbumDetailState extends State<AlbumDetail> {
  late Future<List<ServerTrack>> _tracks = widget.load(widget.album);

  @override
  void didUpdateWidget(AlbumDetail old) {
    super.didUpdateWidget(old);
    if (old.album.id != widget.album.id) _tracks = widget.load(widget.album);
  }

  void _retry() => setState(() => _tracks = widget.load(widget.album));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ServerTrack>>(
      future: _tracks,
      builder: (context, snap) {
        final Widget body;
        if (snap.hasError) {
          body = widget.errorView(snap.error!, _retry);
        } else if (!snap.hasData) {
          body = const StreamLoading(label: 'Loading tracks');
        } else if (snap.data!.isEmpty) {
          body = const StreamMessage(
            icon: Icons.music_off_outlined,
            title: 'No tracks',
            message: 'The server lists no tracks in this album.',
          );
        } else {
          return _list(context, snap.data!);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(context, null),
            Expanded(child: body),
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context, List<ServerTrack> tracks) {
    final p = widget.playback;
    return PlaylistBuilder(
      player: p.actions.player,
      builder: (context, pl) {
        final (id, server) = currentServerTrack(pl);
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: Tokens.s24),
          itemCount: tracks.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) return _header(context, tracks);
            final t = tracks[i - 1];
            return ServerTrackRow(
              track: t,
              kind: p.server.kind,
              favorites: p.favorites,
              showAlbum: false,
              current: server == p.server.kind.name && id == t.id,
              onTap: () => p.playFrom(tracks, i - 1),
              onAction: (a) => p.run(context, a, [t]),
            );
          },
        );
      },
    );
  }

  Widget _header(BuildContext context, List<ServerTrack>? tracks) {
    final a = widget.album;
    final p = widget.playback;
    final sub = [
      a.artist,
      if (a.year != null) '${a.year}',
      if (tracks != null)
        tracks.length == 1 ? '1 track' : '${tracks.length} tracks',
    ].where((e) => e.isNotEmpty).join(', ');
    final ready = tracks != null && tracks.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.onBack != null)
            RowButton(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Back to albums',
              onPressed: widget.onBack,
            ),
          CoverArt(url: a.artUrl, size: context.layout.isCompact ? 72 : 96),
          const SizedBox(width: Tokens.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    a.title,
                    style: Tokens.heading,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: Tokens.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: Tokens.s8),
                Wrap(
                  spacing: Tokens.s4,
                  runSpacing: Tokens.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StreamButton(
                      label: 'Play',
                      icon: Icons.play_arrow_rounded,
                      onPressed: ready ? () => p.playFrom(tracks, 0) : null,
                    ),
                    RowButton(
                      icon: Icons.queue_play_next_rounded,
                      tooltip: 'Play next',
                      onPressed: ready
                          ? () => p.run(context, RowAction.playNext, tracks)
                          : null,
                    ),
                    RowButton(
                      icon: Icons.playlist_add_rounded,
                      tooltip: 'Add to queue',
                      onPressed: ready
                          ? () => p.run(context, RowAction.addToQueue, tracks)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
