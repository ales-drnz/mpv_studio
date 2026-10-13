import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/custom_url_bar.dart';
import 'stream_actions.dart';
import 'stream_catalog.dart';
import 'widgets/reference_list.dart';

/// The Lab tab: a URL entry over the curated reference streams. No chunking by default: these are fast, trusted
/// servers where one open-ended request buffers fastest.
class LabTab extends StatelessWidget {
  const LabTab({super.key, required this.actions});

  final StreamActions actions;

  @override
  Widget build(BuildContext context) {
    return PlaylistBuilder(
      player: actions.player,
      builder: (context, pl) => StreamTabBody(
        children: [
          CustomUrlBar(
            onPlay: (url) => actions.play(Media(url)),
            onQueue: (url) => actions.enqueue([Media(url)]),
          ),
          const SizedBox(height: Tokens.s16),
          ...referenceRows(
            categories: labStreams,
            actions: actions,
            origin: playingOrigin(pl),
          ),
        ],
      ),
    );
  }
}
