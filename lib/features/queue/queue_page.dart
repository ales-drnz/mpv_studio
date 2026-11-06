import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../shell/sections.dart';
import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/studio_snack.dart';
import '../../util/media_import.dart';
import '../../util/media_labels.dart';
import '../../util/reactive.dart';
import 'queue_controller.dart';
import 'queue_snapshot.dart';
import 'queue_details.dart';
import 'widgets/playlist_banner.dart';
import 'widgets/queue_empty.dart';
import 'widgets/queue_entry_info.dart';
import 'widgets/queue_header.dart';
import 'widgets/queue_list.dart';
import 'widgets/queue_now_playing.dart';

/// The live playback queue, a view onto `player.stream.playlist`, for the
/// app's player.
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) => QueueView(
    player: PlayerScope.of(context),
    guard: PlayerScope.issuesOf(context).guard,
    details: PlayerScope.queueDetailsOf(context),
  );
}

/// The queue page on [player]: add tracks with the header buttons or by
/// dropping files and folders, play, reorder and remove them, and see how
/// each one played. On wide windows the selected entry's details sit
/// beside the list.
class QueueView extends StatefulWidget {
  const QueueView({
    super.key,
    required this.player,
    required this.guard,
    required this.details,
    this.pickFiles = pickAudioFiles,
    this.pickFolder = pickFolderPath,
    this.scanFolder = scanAudioFolder,
    this.pickPlaylist = pickPlaylistFile,
  });

  final PlayerApi player;

  /// Runs every player call, turning failures into toasts.
  final CallGuard guard;
  final QueueDetails details;
  final PathPicker pickFiles;
  final FolderPicker pickFolder;
  final FolderScanner scanFolder;
  final PlaylistPicker pickPlaylist;

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  late QueueController _queue = _controller();

  /// The selected entry (pointer layouts), shown in the detail pane. Kept
  /// by identity, so it follows the entry through moves, removals above
  /// it and changes made elsewhere (the Console, a shuffle).
  EntryRef? _selected;

  void _select(List<Media> items, int? index) => setState(
    () => _selected = index == null ? null : EntryRef(items[index], index),
  );

  /// Width of the list beside the details.
  static const _listWidth = 600.0;
  static const _detailWidth = 340.0;

  QueueController _controller() => QueueController(
    player: widget.player,
    guard: widget.guard,
    pickFiles: widget.pickFiles,
    pickFolder: widget.pickFolder,
    scanFolder: widget.scanFolder,
    pickPlaylist: widget.pickPlaylist,
    notify: (message) => showStudioSnack(context, message),
  );

  @override
  void didUpdateWidget(QueueView old) {
    super.didUpdateWidget(old);
    if (old.player != widget.player) {
      _queue.dispose();
      _queue = _controller();
    }
  }

  @override
  void dispose() {
    _queue.dispose();
    super.dispose();
  }

  /// Empties the queue at once, with an undo instead of a question.
  Future<void> _clear() async {
    final before = await _queue.clear();
    if (!mounted) return;
    setState(() => _selected = null);
    if (before != null) _offerUndo('Queue cleared', before);
  }

  Future<void> _loadPlaylist() async {
    final before = await _queue.loadPlaylist();
    if (mounted && before != null) _offerUndo('Queue replaced', before);
  }

  void _offerUndo(String message, QueueSnapshot before) {
    showStudioSnack(
      context,
      message,
      actionLabel: undoLabel,
      onAction: () async {
        if (!await _queue.putBack(before) && mounted) {
          showStudioSnack(context, QueueSnapshot.changedMessage);
        }
      },
    );
  }

  void _toast(String message) {
    showStudioSnack(context, message, duration: const Duration(seconds: 3));
  }

  Future<void> _copy(Media media) async {
    await Clipboard.setData(ClipboardData(text: shareableLocation(media)));
    _toast('Location copied');
  }

  Future<void> _showInfo(int index, {required bool split}) async {
    final items = widget.player.state.playlist.items;
    if (index >= items.length) return;
    if (split) {
      _select(items, index);
      return;
    }
    // The sheet follows the entry while the queue changes under it.
    var ref = EntryRef(items[index], index);
    await showStudioSheet<void>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s16),
        child: Live<Playlist>(
          stream: widget.player.stream.playlist,
          initial: widget.player.state.playlist,
          builder: (context, pl) {
            final at = ref.resolve(pl.items);
            if (at == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Tokens.s24),
                child: Text(
                  'This track is no longer in the queue.',
                  style: Tokens.body,
                  textAlign: TextAlign.center,
                ),
              );
            }
            ref = EntryRef(ref.media, at);
            return _info(pl, at, close: () => Navigator.pop(context));
          },
        ),
      ),
    );
  }

  Future<void> _onAction(
    QueueAction action,
    int index, {
    required bool split,
  }) async {
    final items = widget.player.state.playlist.items;
    if (index < 0 || index >= items.length) return;
    switch (action) {
      case QueueAction.play:
        await _queue.play(index);
      case QueueAction.playNext:
        await _queue.playNext(index);
      case QueueAction.moveToTop:
        await _queue.moveToTop(index);
      case QueueAction.moveToBottom:
        await _queue.moveToBottom(index);
      case QueueAction.info:
        await _showInfo(index, split: split);
      case QueueAction.copyUrl:
        await _copy(items[index]);
      case QueueAction.replace:
        await _queue.replace(index);
      case QueueAction.remove:
        await _removeAt(index);
    }
  }

  /// Bumped by each removal toast, so only the latest one forgets the
  /// removals when it goes.
  int _undoToast = 0;

  /// Removes the entry at [index] with an undo that also brings back the
  /// ones removed just before. Returns whether it went.
  Future<bool> _removeAt(int index) {
    // One at a time: each removal reads the queue the last one left.
    final done = _removing.then((_) => _removeNow(index));
    _removing = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<void> _removing = Future.value();

  Future<bool> _removeNow(int index) async {
    final items = widget.player.state.playlist.items;
    if (index < 0 || index >= items.length) return false;
    final title = QueueRowInfo.of(
      items[index],
      widget.details.details.value[items[index]],
    ).title;
    // Removing the selected entry hands the selection to the entry after
    // it, else the one before.
    final selectedAt = _selected?.resolve(items);
    final neighbour = index + 1 < items.length ? index + 1 : index - 1;
    final count = await _queue.removeForUndo(index);
    if (count == null) return false;
    if (!mounted) return true;
    if (selectedAt == index) {
      setState(
        () => _selected = neighbour < 0
            ? null
            : EntryRef(items[neighbour], neighbour),
      );
    }
    final toast = ++_undoToast;
    final shown = ScaffoldMessenger.maybeOf(context)?.showStudioSnack(
      count == 1 ? 'Removed "$title"' : 'Removed $count tracks',
      actionLabel: undoLabel,
      onAction: _queue.undoRemovals,
    );
    shown?.closed.then((reason) {
      if (toast == _undoToast && reason != SnackBarClosedReason.action) {
        _queue.forgetRemovals();
      }
    });
    return true;
  }

  Widget _info(Playlist pl, int index, {VoidCallback? close}) {
    final media = pl.items[index];
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.details.details,
        widget.details.outcomes,
      ]),
      builder: (context, _) => QueueEntryInfo(
        index: index,
        count: pl.items.length,
        media: media,
        info: QueueRowInfo.of(media, widget.details.details.value[media]),
        outcome: widget.details.outcomes.value[media],
        current: index == pl.index,
        player: widget.player,
        onPlay: () {
          close?.call();
          _queue.play(index);
        },
        onCopy: () => _copy(media),
        onRemove: () {
          close?.call();
          _onAction(QueueAction.remove, index, split: close == null);
        },
      ),
    );
  }

  /// The header's actions; none while the queue is empty, where the empty
  /// state offers the same ways in.
  List<QueueHeaderAction> _headerActions(bool empty) => empty
      ? const []
      : [
          QueueHeaderAction(
            icon: Icons.add_rounded,
            label: 'Add files',
            onPressed: _queue.addFiles,
            primary: true,
          ),
          QueueHeaderAction(
            icon: Icons.folder_open_rounded,
            label: 'Add folder',
            onPressed: canPickFolder ? _queue.addFolder : null,
            disabledReason: 'Folders cannot be picked on this device',
          ),
          QueueHeaderAction(
            icon: Icons.playlist_play_rounded,
            label: 'Load playlist',
            onPressed: _loadPlaylist,
          ),
          QueueHeaderAction(
            icon: Icons.clear_all_rounded,
            label: 'Clear queue',
            onPressed: _clear,
            destructive: true,
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final router = GoRouter.maybeOf(context);
    // Drops land anywhere on the window: the shell's FileDropHost.
    return Live<Playlist>(
      stream: player.stream.playlist,
      initial: player.state.playlist,
      builder: (context, playlist) {
        final items = playlist.items;
        final selected = _selected?.resolve(items);
        // Remember where the entry is now, for the next change.
        if (selected != null) {
          _selected = EntryRef(items[selected], selected);
        }
        // The detail pane follows the selection, else the current entry.
        final shown = selected ?? (playlist.index >= 0 ? playlist.index : null);
        return LayoutBuilder(
          builder: (context, constraints) {
            final gutter = context.layout.gutter;
            final available = constraints.maxWidth - 2 * gutter;
            // With room for three columns, what plays and what comes
            // next stand beside the list and the details.
            // The width follows the window, the column the queue: the
            // header stays put when the first file comes in.
            final three =
                context.layout.isPointer &&
                available >= Breakpoints.threeColumns;
            final content = math.min(
              available,
              three ? Breakpoints.full : Breakpoints.wide,
            );
            // The width follows the window, not whether there is a
            // detail yet: the header stays put when the first file
            // comes in.
            final roomy =
                context.layout.isPointer &&
                TwoPane.splitsAt(
                  content,
                  listWidth: _listWidth,
                  minDetailWidth: _detailWidth,
                );
            final split = items.isNotEmpty && roomy;
            return PageFrame(
              title: 'Queue',
              scrollable: false,
              maxWidth: three
                  ? Breakpoints.full
                  : roomy
                  ? Breakpoints.wide
                  : Breakpoints.readable,
              actions: queueHeaderButtons(
                context,
                _headerActions(items.isEmpty),
                available: content,
              ),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summary(playlist),
                  Live<String>(
                    stream: player.stream.playlistPath,
                    initial: player.state.playlistPath,
                    builder: (context, path) => path.isEmpty
                        ? const SizedBox.shrink()
                        : PlaylistBanner(
                            path: path,
                            onPrevious: _queue.previousPlaylist,
                            onNext: _queue.nextPlaylist,
                          ),
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? QueueEmpty(
                            onAddFiles: _queue.addFiles,
                            onAddFolder: _queue.addFolder,
                            onLoadPlaylist: _loadPlaylist,
                            onBrowseStreams: router == null
                                ? null
                                : () => router.go(Section.stream.path),
                          )
                        : split
                        ? _withNowPlaying(
                            three && items.isNotEmpty,
                            playlist,
                            TwoPane(
                              listWidth: _listWidth,
                              minDetailWidth: _detailWidth,
                              list: _list(playlist, selected, split),
                              // A card at its content's height, scrolling
                              // when it does not fit.
                              detail: shown == null
                                  ? null
                                  : SingleChildScrollView(
                                      padding: PageEnd.padding(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          Tokens.s16,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: Tokens.surface,
                                          shape: Tokens.shape(Tokens.rLg),
                                        ),
                                        child: _info(playlist, shown),
                                      ),
                                    ),
                              placeholder: const _DetailPlaceholder(),
                            ),
                          )
                        : _list(playlist, selected, split),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// [panes] with the Now playing column, when [three].
  Widget _withNowPlaying(bool three, Playlist playlist, Widget panes) {
    if (!three) return panes;
    final gap = context.layout.gap;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: panes),
        SizedBox(width: gap),
        SizedBox(
          width: _nowPlayingWidth,
          child: SingleChildScrollView(
            padding: PageEnd.padding(context),
            child: QueueNowPlaying(
              player: widget.player,
              details: widget.details,
              playlist: playlist,
              onJump: _queue.play,
            ),
          ),
        ),
      ],
    );
  }

  /// The Now playing column's width.
  static const double _nowPlayingWidth = 320;

  Widget _summary(Playlist playlist) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.details.details,
      _queue.adding,
      _queue.looking,
    ]),
    builder: (context, _) {
      if (playlist.items.isEmpty &&
          _queue.adding.value == 0 &&
          !_queue.looking.value) {
        return const SizedBox.shrink();
      }
      var known = Duration.zero;
      var unknown = 0;
      for (final m in playlist.items) {
        final d = QueueRowInfo.of(m, widget.details.details.value[m]).duration;
        if (d == null) {
          unknown++;
        } else {
          known += d;
        }
      }
      return QueueSummary(
        count: playlist.items.length,
        known: known,
        unknown: unknown,
        adding: _queue.adding.value,
        looking: _queue.looking.value,
      );
    },
  );

  Widget _list(Playlist playlist, int? selected, bool split) =>
      ListenableBuilder(
        listenable: Listenable.merge([
          widget.details.details,
          widget.details.outcomes,
        ]),
        builder: (context, _) => QueueList(
          playlist: playlist,
          details: widget.details.details.value,
          outcomes: widget.details.outcomes.value,
          controller: _queue,
          selected: selected,
          onSelect: (i) => _select(playlist.items, i),
          onAction: (action, i) => _onAction(action, i, split: split),
          onRemove: _removeAt,
        ),
      );
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Tokens.s24),
      child: Text(
        'Select a track to see its details.',
        style: Tokens.caption,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// A queue entry known by identity, with the index it was last seen at to
/// tell duplicates apart.
@immutable
class EntryRef {
  const EntryRef(this.media, this.index);

  final Media media;
  final int index;

  /// Where the entry is in [items] now: at [index] when it is still there,
  /// else its occurrence nearest to [index]; null once it left the queue.
  int? resolve(List<Media> items) {
    if (index < items.length && items[index] == media) return index;
    int? best;
    for (var i = 0; i < items.length; i++) {
      if (items[i] != media) continue;
      if (best == null || (i - index).abs() < (best - index).abs()) best = i;
    }
    return best;
  }
}
