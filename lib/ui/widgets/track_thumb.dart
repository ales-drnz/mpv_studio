import 'package:flutter/material.dart';

import '../tokens.dart';

/// A track's cover in a list row: a [size] square with the inner tile
/// corner, the same in the queue, the libraries and the lab. [image] is
/// the cover (fitted to cover the square); without one, a note on the
/// field tone.
class TrackThumb extends StatelessWidget {
  const TrackThumb({super.key, this.image, this.size = 40, this.badge});

  final Widget? image;
  final double size;

  /// A mark over the cover's corner (playing, failed); null for none.
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(Tokens.rSm),
      child: SizedBox.square(
        dimension: size,
        child: image ?? TrackThumbPlaceholder(size: size),
      ),
    );
    if (badge == null) return cover;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        cover,
        Positioned(right: -Tokens.s4, bottom: -Tokens.s4, child: badge!),
      ],
    );
  }
}

/// The note shown where a cover is missing or failed to load.
class TrackThumbPlaceholder extends StatelessWidget {
  const TrackThumbPlaceholder({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Tokens.surface3,
    child: Center(
      child: Icon(
        Icons.music_note_rounded,
        size: (size * 0.45).clamp(Tokens.iconSm, 32.0),
        color: Tokens.fgFaint,
      ),
    ),
  );
}
