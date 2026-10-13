import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../shell/sections.dart';
import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import '../../ui/tokens.dart';
import '../../util/media_import.dart';
import '../../util/media_labels.dart';
import '../../util/reactive.dart';
import 'queue_controller.dart';
import 'queue_details.dart';
import 'widgets/playlist_banner.dart';
import 'widgets/queue_empty.dart';
import 'widgets/queue_entry_info.dart';
import 'widgets/queue_header.dart';
import 'widgets/queue_list.dart';

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
    this.pickFolder = pickAudioFolder,
    this.pickPlaylist = pickPlaylistFile,
  });

  final PlayerApi player;

  /// Runs every player call, turning failures into toasts.
  final CallGuard guard;
  final QueueDetails details;
  final PathPicker pickFiles;
  final PathPicker pickFolder;
  final PlaylistPicker pickPlaylist;

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  late QueueController _queue = _controller();
  bool _dragging = false;

  /// The selected entry (pointer layouts), shown in the detail pane.
  int? _selected;

  /// Width of the list beside the details.
  static const _listWidth = 600.0;
  static const _detailWidth = 340.0;

  QueueController _controller() => QueueController(
    player: widget.player,
    guard: widget.guard,
    pickFiles: widget.pickFiles,
    pickFolder: widget.pickFolder,
    pickPlaylist: widget.pickPlaylist,
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

  Future<void> _clear() async {
    final count = widget.player.state.playlist.items.length;
    final ok = await showStudioDialog<bool>(
      context,
      title: 'Clear the queue?',
      builder: (context) => Text(
        count == 1
            ? 'The track is removed from the queue and playback stops.'
            : 'All $count tracks are removed from the queue and playback '
                  'stops.',
        style: Tokens.body,
      ),
      actions: (context) => [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Tokens.red),
          child: const Text('Clear'),
        ),
      ],
    );
    if (ok == true) {
      await _queue.clear();
      if (mounted) setState(() => _selected = null);
    }
  }

  void _toast(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: TextStyle(color: Tokens.fg)),
          backgroundColor: Tokens.surface3,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _copy(Media media) async {
    await Clipboard.setData(ClipboardData(text: shareableLocation(media)));
    _toast('Location copied');
  }

  Future<void> _showInfo(int index, {required bool split}) async {
    if (split) {
      setState(() => _selected = index);
      return;
    }
    final pl = widget.player.state.playlist;
    if (index >= pl.items.length) return;
    await showStudioSheet<void>(
      context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Tokens.s8),
        child: _info(pl, index, close: () => Navigator.pop(context)),
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
        final removed = await _queue.remove(index);
        if (removed != null && mounted) {
          setState(() {
            final s = _selected;
            if (s != null && s >= items.length - 1) {
              _selected = items.length > 1 ? items.length - 2 : null;
            }
          });
        }
    }
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

  List<QueueHeaderAction> _headerActions(bool empty) => [
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
      onPressed: _queue.loadPlaylist,
    ),
    QueueHeaderAction(
      icon: Icons.clear_all_rounded,
      label: 'Clear queue',
      onPressed: empty ? null : _clear,
      disabledReason: 'The queue is empty',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final router = GoRouter.maybeOf(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (detail) {
        setState(() => _dragging = false);
        _queue.enqueue(resolveDroppedPaths(detail.files.map((f) => f.path)));
      },
      child: ColoredBox(
        // A drag-over wash signals the drop target.
        color: _dragging ? Tokens.accentWash : Colors.transparent,
        child: Live<Playlist>(
          stream: player.stream.playlist,
          initial: player.state.playlist,
          builder: (context, playlist) {
            final items = playlist.items;
            final selected = _selected != null && _selected! < items.length
                ? _selected
                : null;
            // The detail pane follows the selection, else the current entry.
            final shown =
                selected ?? (playlist.index >= 0 ? playlist.index : null);
            return LayoutBuilder(
              builder: (context, constraints) {
                final gutter = context.layout.gutter;
                final content = math.min(
                  constraints.maxWidth - 2 * gutter,
                  Breakpoints.wide,
                );
                final split =
                    items.isNotEmpty &&
                    context.layout.isPointer &&
                    TwoPane.splitsAt(
                      content,
                      listWidth: _listWidth,
                      minDetailWidth: _detailWidth,
                    );
                return PageFrame(
                  title: 'Queue',
                  scrollable: false,
                  maxWidth: split ? Breakpoints.wide : Breakpoints.readable,
                  actions: queueHeaderButtons(
                    context,
                    _headerActions(items.isEmpty),
                  ),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (items.isNotEmpty || _queue.adding.value > 0)
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
                                onLoadPlaylist: _queue.loadPlaylist,
                                onBrowseStreams: router == null
                                    ? null
                                    : () => router.go(Section.stream.path),
                              )
                            : split
                            ? TwoPane(
                                listWidth: _listWidth,
                                minDetailWidth: _detailWidth,
                                list: Padding(
                                  padding: const EdgeInsets.only(
                                    right: Tokens.s12,
                                  ),
                                  child: _list(playlist, selected, split),
                                ),
                                detail: shown == null
                                    ? null
                                    : SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(
                                          Tokens.s20,
                                          0,
                                          0,
                                          Tokens.s16,
                                        ),
                                        child: _info(playlist, shown),
                                      ),
                                placeholder: const _DetailPlaceholder(),
                              )
                            : _list(playlist, selected, split),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _summary(Playlist playlist) => ListenableBuilder(
    listenable: Listenable.merge([widget.details.details, _queue.adding]),
    builder: (context, _) {
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
          onSelect: (i) => setState(() => _selected = i),
          onAction: (action, i) => _onAction(action, i, split: split),
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
