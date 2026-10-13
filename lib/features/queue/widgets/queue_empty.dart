import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: Tokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_rounded, size: 48, color: Tokens.fgFaint),
            const SizedBox(height: Tokens.s12),
            Semantics(
              header: true,
              child: Text(
                'The queue is empty',
                style: Tokens.heading,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: Tokens.s6),
            Text(hint, style: Tokens.caption, textAlign: TextAlign.center),
            const SizedBox(height: Tokens.s20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Tokens.s8,
              runSpacing: Tokens.s8,
              children: [
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
            ),
          ],
        ),
      ),
    );
  }

  static ButtonStyle _outlined(Size minimum) => OutlinedButton.styleFrom(
    minimumSize: minimum,
    foregroundColor: Tokens.fg,
    side: BorderSide(color: Tokens.line2),
  );
}
