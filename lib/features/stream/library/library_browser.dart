import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../favorites_controller.dart';
import '../media_server.dart';
import '../stream_actions.dart';
import '../widgets/reference_list.dart';
import '../widgets/stream_row.dart';
import '../widgets/stream_states.dart';
import '../widgets/stream_tab_scope.dart';
import 'album_views.dart';
import 'server_playback.dart';
import 'stream_options_dialog.dart';
import 'track_rows.dart';

/// What the connected library shows.
enum LibraryView {
  songs('Songs'),
  albums('Albums');

  final String label;
  const LibraryView(this.label);
}

/// A connected Jellyfin or Plex library: a search field, the playback
/// options and sign out on top; under them the paged song list, or the
/// album grid with the open album's tracks beside it (or over it, when the
/// window is narrow).
///
/// A fetch that fails on an expired session calls [onSessionExpired].
class LibraryBrowser extends StatefulWidget {
  const LibraryBrowser({
    super.key,
    required this.server,
    required this.actions,
    required this.favorites,
    required this.onSignOut,
    required this.onSessionExpired,
  });

  final MediaServer server;
  final StreamActions actions;
  final FavoritesController favorites;
  final VoidCallback onSignOut;
  final VoidCallback onSessionExpired;

  @override
  State<LibraryBrowser> createState() => _LibraryBrowserState();
}

/// Rethrows [error] as an [Exception] so the pager keeps it as its state
/// (it rethrows plain errors).
class _FetchFailure implements Exception {
  const _FetchFailure(this.cause);
  final Object cause;
  @override
  String toString() => cause.toString();
}

class _LibraryBrowserState extends State<LibraryBrowser> {
  static const _pageSize = 50;

  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  LibraryView _view = LibraryView.songs;
  late StreamOptions _options = StreamOptions(
    protocol: widget.server.protocols.first,
  );

  int? _songTotal;
  int? _albumTotal;
  late final _songs = PagingController<int, ServerTrack>(
    getNextPageKey: (s) =>
        _nextKey(s.items?.length, s.lastPageIsEmpty, _songTotal),
    fetchPage: (start) => _guarded(() async {
      final page = await _server.fetchTracks(
        startIndex: start,
        pageSize: _pageSize,
        query: _query,
      );
      _songTotal = page.total;
      return page.items;
    }),
  );
  late final _albums = PagingController<int, ServerAlbum>(
    getNextPageKey: (s) =>
        _nextKey(s.items?.length, s.lastPageIsEmpty, _albumTotal),
    fetchPage: (start) => _guarded(() async {
      final page = await _server.fetchAlbums(
        startIndex: start,
        pageSize: _pageSize,
        query: _query,
      );
      _albumTotal = page.total;
      return page.items;
    }),
  );

  ServerAlbum? _openAlbum;
  final _albumTracks = <String, Future<List<ServerTrack>>>{};

  MediaServer get _server => widget.server;

  ServerPlayback get _playback => ServerPlayback(
    server: _server,
    actions: widget.actions,
    favorites: widget.favorites,
    options: _options,
    onFailure: _onPlaybackFailure,
  );

  /// A queue entry the server could not build: an expired session goes
  /// back to the sign-in form, anything else is said in a snackbar.
  void _onPlaybackFailure(Object error) {
    if (!mounted) return;
    final kind = _server.classify(error);
    if (kind == FailureKind.auth) {
      widget.onSessionExpired();
      return;
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(describeFailure(kind, error))));
  }

  /// The page key is the start offset, the count of items already loaded;
  /// null once the server's total is reached.
  static int? _nextKey(int? loaded, bool lastEmpty, int? total) {
    final n = loaded ?? 0;
    if (lastEmpty || (total != null && n >= total)) return null;
    return n;
  }

  Future<T> _guarded<T>(Future<T> Function() fetch) async {
    try {
      return await fetch();
    } catch (e) {
      if (_server.classify(e) == FailureKind.auth) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSessionExpired();
        });
      }
      if (e is Exception) rethrow;
      throw _FetchFailure(e);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _songs.dispose();
    _albums.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final next = q.trim();
      if (next == _query) return;
      _query = next;
      _refresh();
    });
  }

  void _refresh() {
    _songTotal = null;
    _albumTotal = null;
    _songs.refresh();
    _albums.refresh();
    setState(() => _openAlbum = null);
  }

  Future<List<ServerTrack>> _tracksOf(ServerAlbum album) =>
      _albumTracks.putIfAbsent(album.id, () async {
        try {
          return await _guarded(() => _server.fetchAlbumTracks(album));
        } catch (_) {
          // A failed load is not cached, so a retry asks the server again.
          _albumTracks.remove(album.id);
          rethrow;
        }
      });

  Future<void> _albumAction(ServerAlbum album, RowAction action) async {
    try {
      final tracks = await _tracksOf(album);
      if (!mounted) return;
      if (action == RowAction.playNow) {
        await _playback.playFrom(tracks, 0);
      } else {
        await _playback.run(context, action, tracks);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(describeFailure(_server.classify(e), _unwrap(e))),
        ),
      );
    }
  }

  static Object _unwrap(Object e) => e is _FetchFailure ? e.cause : e;

  /// The view for a failed load: sign in again, or a retry.
  Widget _errorView(Object error, VoidCallback retry) {
    final cause = _unwrap(error);
    final kind = _server.classify(cause);
    return StreamMessage(
      icon: kind == FailureKind.network
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      error: true,
      title: kind == FailureKind.network
          ? '${_server.name} is not reachable'
          : 'Could not load the library',
      message: describeFailure(kind, cause),
      actionLabel: kind == FailureKind.auth ? 'Sign in again' : 'Retry',
      onAction: kind == FailureKind.auth ? widget.onSessionExpired : retry,
    );
  }

  String get _emptyHint => _query.isEmpty
      ? 'The ${_server.name} library has no music yet.'
      : 'Nothing matches "$_query".';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context),
        const SizedBox(height: Tokens.s8),
        Expanded(
          child: switch (_view) {
            LibraryView.songs => _songList(),
            LibraryView.albums => _albumPanes(context),
          },
        ),
      ],
    );
  }

  Widget _toolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Tokens.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _search,
                  onChanged: _onSearch,
                  textInputAction: TextInputAction.search,
                  semanticLabel: _view == LibraryView.songs
                      ? 'Search songs'
                      : 'Search albums',
                  hint: _view == LibraryView.songs
                      ? 'Search songs'
                      : 'Search albums',
                  leading: Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Tokens.fgDim,
                  ),
                ),
              ),
              const SizedBox(width: Tokens.s8),
              RowButton(
                icon: Icons.logout_rounded,
                tooltip: 'Sign out of ${_server.name}',
                onPressed: widget.onSignOut,
              ),
            ],
          ),
          const SizedBox(height: Tokens.s12),
          Wrap(
            spacing: Tokens.s8,
            runSpacing: Tokens.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedControl<LibraryView>(
                expand: false,
                options: [
                  for (final v in LibraryView.values) SegmentOption(v, v.label),
                ],
                selected: _view,
                onSelect: (v) => setState(() => _view = v),
              ),
              OutlinedButton.icon(
                onPressed: () => showStreamOptions(
                  context,
                  server: _server,
                  options: _options,
                  onChanged: (o) => setState(() => _options = o),
                ),
                icon: const Icon(Icons.tune_rounded, size: 20),
                label: Text(describeStreamOptions(_options)),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, controlHeightOf(context)),
                  padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _songList() {
    return PlaylistBuilder(
      player: widget.actions.player,
      builder: (context, pl) {
        final (id, server) = currentServerTrack(pl);
        return PagingListener<int, ServerTrack>(
          controller: _songs,
          builder: (context, state, fetchNextPage) =>
              PagedListView<int, ServerTrack>(
                state: state,
                fetchNextPage: fetchNextPage,
                padding: const EdgeInsets.only(bottom: Tokens.s24),
                builderDelegate: PagedChildBuilderDelegate<ServerTrack>(
                  itemBuilder: (context, track, index) => ServerTrackRow(
                    track: track,
                    kind: _server.kind,
                    favorites: widget.favorites,
                    current: server == _server.kind.name && id == track.id,
                    onTap: () =>
                        _playback.playFrom(state.items ?? const [], index),
                    onAction: (a) => _playback.run(context, a, [track]),
                  ),
                  firstPageProgressIndicatorBuilder: (_) =>
                      const StreamLoading(label: 'Loading songs'),
                  newPageProgressIndicatorBuilder: (_) => const StreamLoading(),
                  firstPageErrorIndicatorBuilder: (_) =>
                      _errorView(state.error!, _songs.refresh),
                  newPageErrorIndicatorBuilder: (_) => Center(
                    child: TextButton.icon(
                      onPressed: fetchNextPage,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Could not load more. Retry'),
                    ),
                  ),
                  noItemsFoundIndicatorBuilder: (_) => StreamMessage(
                    icon: Icons.library_music_outlined,
                    title: 'No songs',
                    message: _emptyHint,
                  ),
                ),
              ),
        );
      },
    );
  }

  Widget _albumPanes(BuildContext context) {
    final active = StreamTabScope.isActive(context);
    final album = active ? _openAlbum : null;
    return LayoutBuilder(
      builder: (context, c) {
        final split = TwoPane.splitsAt(c.maxWidth);
        void close() => setState(() => _openAlbum = null);
        return TwoPane(
          list: AlbumGrid(
            paging: _albums,
            selected: split ? album : null,
            onOpen: (a) => setState(() => _openAlbum = a),
            onAction: _albumAction,
            emptyMessage: _emptyHint,
            errorView: (e) => _errorView(e, _albums.refresh),
          ),
          detail: album == null
              ? null
              : Padding(
                  padding: EdgeInsets.only(
                    left: split ? context.layout.gap : 0,
                  ),
                  child: AlbumDetail(
                    key: ValueKey(album.id),
                    album: album,
                    load: _tracksOf,
                    playback: _playback,
                    errorView: _errorView,
                    onBack: split ? null : close,
                  ),
                ),
          onCloseDetail: close,
          placeholder: const StreamMessage(
            icon: Icons.album_outlined,
            title: 'Pick an album',
            message: 'Its tracks show here.',
          ),
        );
      },
    );
  }
}
