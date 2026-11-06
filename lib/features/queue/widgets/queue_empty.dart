import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/widgets/empty_state.dart';
import 'queue_header.dart';

/// The empty queue: what it is and the ways to fill it.
class QueueEmpty extends StatelessWidget {
  const QueueEmpty({
    super.key,
    required this.onAddFiles,
    required this.onAddFolder,
    required this.onLoadPlaylist,
    this.onBrowseStreams,
  });

  final VoidCallback onAddFiles;
  final VoidCallback onAddFolder;
  final VoidCallback onLoadPlaylist;

  /// Opens the Stream page, when there is one to open.
  final VoidCallback? onBrowseStreams;

  @override
  Widget build(BuildContext context) {
    final layout = context.layout;
    final hint = layout.isPointer
        ? 'Add files, a folder or a playlist, or drop them here.'
        : 'Add files, a folder or a playlist to start listening.';
    final buttonSize = Size(0, layout.minTap);
    // The app's one empty state, as on Playback: no card of its own.
    return EmptyState(
      icon: Icons.queue_music_rounded,
      title: 'The queue is empty',
      message: hint,
      // Centred, so as far from the top as from the page end.
      padding: PageEnd.centred(context),
      actions: [
        FilledButton.icon(
          onPressed: onAddFiles,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add files'),
          style: FilledButton.styleFrom(minimumSize: buttonSize),
        ),
        if (canPickFolder)
          OutlinedButton.icon(
            onPressed: onAddFolder,
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('Add folder'),
            style: _outlined(buttonSize),
          ),
        OutlinedButton.icon(
          onPressed: onLoadPlaylist,
          icon: const Icon(Icons.playlist_play_rounded, size: 18),
          label: const Text('Load playlist'),
          style: _outlined(buttonSize),
        ),
        if (onBrowseStreams != null)
          OutlinedButton.icon(
            onPressed: onBrowseStreams,
            icon: const Icon(Icons.podcasts_rounded, size: 18),
            label: const Text('Browse streams'),
            style: _outlined(buttonSize),
          ),
      ],
    );
  }

  static ButtonStyle _outlined(Size minimum) =>
      OutlinedButton.styleFrom(minimumSize: minimum);
}
