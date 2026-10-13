import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../playback_scope.dart';
import '../track_identity.dart';

/// The title over the artist and album of the current track (see
/// [TrackIdentity] for where each comes from).
class TrackInfo extends StatelessWidget {
  const TrackInfo({super.key, this.centered = true, this.compact = false});

  /// Centre the text (stacked layouts) or start-align it (side panes).
  final bool centered;

  /// A smaller title, for short windows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final player = PlaybackScope.of(context).player;
    final align = centered ? TextAlign.center : TextAlign.start;
    return LiveTrackIdentity(
      player: player,
      builder: (context, id) {
        final sub = id.subtitle();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: centered
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(
                id.displayTitle,
                style: compact
                    ? Tokens.heading.copyWith(fontSize: 17)
                    : Tokens.title,
                textAlign: align,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: Tokens.s4),
              Text(
                sub,
                style: Tokens.label,
                textAlign: align,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }
}
