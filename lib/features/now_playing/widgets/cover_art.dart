import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';

/// Square album art. Prefers embedded cover bytes from
/// `player.stream.coverArt`; when a track carries none (e.g. a transcoded
/// server stream) it falls back to the network artwork URL the queue item
/// stored in `extras['art']`, and finally to a flat placeholder.
class CoverArtView extends StatelessWidget {
  final double size;
  const CoverArtView({super.key, required this.size});

  static String? _artUrl(Playlist? pl) {
    if (pl == null ||
        pl.items.isEmpty ||
        pl.index < 0 ||
        pl.index >= pl.items.length) {
      return null;
    }
    final v = pl.items[pl.index].extras?['art'];
    return (v is String && v.isNotEmpty) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: StreamBuilder<Playlist>(
        stream: player.stream.playlist,
        initialData: player.state.playlist,
        builder: (context, plSnap) {
          final artUrl = _artUrl(plSnap.data);
          return StreamBuilder<CoverArt?>(
            stream: player.stream.coverArt,
            initialData: player.state.coverArt,
            builder: (context, snap) {
              final art = snap.data;
              final Widget child;
              if (art != null) {
                child = Image.memory(
                  art.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const _Placeholder(),
                );
              } else if (artUrl != null) {
                child = Image.network(
                  artUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, _, _) => const _Placeholder(),
                );
              } else {
                child = const _Placeholder();
              }
              return ClipPath(
                clipper:
                    ShapeBorderClipper(shape: Tokens.squircle(Tokens.rLg)),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Tokens.surface2,
      child: Center(
        child: Icon(Icons.music_note_rounded, size: 44, color: Tokens.fgFaint),
      ),
    );
  }
}
