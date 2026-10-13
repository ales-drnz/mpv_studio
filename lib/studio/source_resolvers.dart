import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Several [SourceResolver]s behind the player's single resolver slot.
///
/// The player accepts ONE resolver (`setSourceResolver`), while the app has
/// several sources that rewrite URLs (Plex markers, the Resolver tab's
/// signed links). The chain asks each in order and plays the first URL one
/// returns; a resolver returns null for entries that are not its own, so
/// order only matters if two claim the same entry. A resolver that throws
/// is logged and skipped, so one broken source never blocks the others.
class SourceResolverChain {
  SourceResolverChain(List<SourceResolver> resolvers)
    : resolvers = List.unmodifiable(resolvers);

  final List<SourceResolver> resolvers;

  /// The URL to open for [request], or null to keep it as is.
  Future<String?> call(SourceResolveRequest request) async {
    for (final resolve in resolvers) {
      try {
        final url = await resolve(request);
        if (url != null && url.isNotEmpty) return url;
      } catch (e) {
        debugPrint('Source resolver failed for ${request.uri}: $e');
      }
    }
    return null;
  }

  /// Installs the chain on [player]. Returns false (after logging) when the
  /// player refused it, so a failure never aborts the app's launch.
  Future<bool> installOn(PlayerApi player) async {
    try {
      await player.setSourceResolver(call);
      return true;
    } catch (e) {
      debugPrint('Could not install the source resolvers: $e');
      return false;
    }
  }
}
