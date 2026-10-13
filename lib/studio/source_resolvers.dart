import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'app_settings.dart';
import 'studio_log.dart';

/// Several [SourceResolver]s behind the player's single resolver slot.
///
/// The player accepts ONE resolver (`setSourceResolver`), while the app has
/// several sources that rewrite URLs (Plex markers, the Resolver tab's
/// signed links). The chain asks each in order and plays the first URL one
/// returns; a resolver returns null for entries that are not its own, so
/// order only matters if two claim the same entry. A resolver that throws
/// is logged in the Console (the URL without its query, which can carry a
/// token) and skipped, so one broken source never blocks the others.
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
      } on Object catch (e) {
        StudioLog.write(
          'source resolver failed for ${redactUri(request.uri)}: $e',
          level: LogLevel.warn,
        );
      }
    }
    return null;
  }

  /// Installs the chain on [player]. Returns what the player refused, or
  /// null, so a failure joins the launch's notice instead of aborting it.
  Future<SettingFailure?> installOn(PlayerApi player) async {
    try {
      await player.setSourceResolver(call);
      return null;
    } on Object catch (e) {
      return SettingFailure('Source resolvers', e);
    }
  }
}
