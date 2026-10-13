import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';
import '../track_identity.dart';

/// Square album art of the current track: the embedded cover from
/// `stream.coverArt`, else the artwork URL the queue entry carries in
/// `extras['art']` (server tracks), else a flat placeholder. Shared by the
/// Playback page and the mini-player.
class CoverArtView extends StatelessWidget {
  const CoverArtView({
    super.key,
    required this.player,
    required this.size,
    this.radius = Tokens.rLg,
  });

  final PlayerApi player;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Tokens.surface2,
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: (size * 0.45).clamp(20.0, 48.0),
          color: Tokens.fgFaint,
        ),
      ),
    );
    return SizedBox.square(
      dimension: size,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: Tokens.shape(radius)),
        child: Live<Playlist>(
          stream: player.stream.playlist,
          initial: player.state.playlist,
          builder: (context, pl) => Live<CoverArt?>(
            stream: player.stream.coverArt,
            initial: player.state.coverArt,
            builder: (context, art) {
              final hasArt = art != null || currentExtra(pl, 'art') != null;
              final Widget image;
              if (art != null) {
                image = Image.memory(
                  art.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => placeholder,
                );
              } else if (currentExtra(pl, 'art') case final url?) {
                image = Image.network(
                  url,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => placeholder,
                );
              } else {
                image = placeholder;
              }
              return Semantics(
                image: true,
                label: hasArt ? 'Cover art' : 'No cover art',
                excludeSemantics: true,
                child: image,
              );
            },
          ),
        ),
      ),
    );
  }
}
