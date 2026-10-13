import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';

/// Cover art of a server album or track, clipped to a circular-arc
/// rectangle of [radius] (a circle from [Tokens.rPill]), with a glyph on a
/// tonal fill while it loads or when there is none.
class ServerCover extends StatelessWidget {
  const ServerCover({
    super.key,
    required this.url,
    this.size,
    this.radius = Tokens.rLg,
    this.placeholderIcon = Icons.album_rounded,
  });

  final String? url;

  /// A fixed side; null fills the parent.
  final double? size;

  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Tokens.surface3,
      child: LayoutBuilder(
        builder: (context, c) {
          // A row glyph on a thumbnail, a quiet mark on a large cover.
          final side = c.biggest.shortestSide;
          final small = side < 64;
          return Center(
            child: Icon(
              placeholderIcon,
              size: small ? 20 : (side * 0.32).clamp(20, 40),
              color: small ? Tokens.fgDim : Tokens.fgFaint,
            ),
          );
        },
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
    final shape = radius >= Tokens.rPill
        ? const CircleBorder()
        : Tokens.shape(radius);
    return ExcludeSemantics(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: SizedBox(
          width: size,
          height: size,
          child: AspectRatio(aspectRatio: 1, child: image),
        ),
      ),
    );
  }
}
