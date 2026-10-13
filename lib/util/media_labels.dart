import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import 'media_import.dart';

/// Where a queue entry comes from, shown with its [label] on its row.
enum MediaOrigin {
  file('Local file'),
  http('Web stream'),
  smb('Samba share'),
  jellyfin('Jellyfin'),
  plex('Plex');

  const MediaOrigin(this.label);

  /// The source as the app names it everywhere.
  final String label;
}

/// The [MediaOrigin] of [media]: the `server` extra for Jellyfin and Plex
/// entries, otherwise the URI scheme.
MediaOrigin originOf(Media media) {
  switch (media.extras?['server']) {
    case 'jellyfin':
      return MediaOrigin.jellyfin;
    case 'plex':
      return MediaOrigin.plex;
  }
  final uri = media.uri;
  final colon = uri.indexOf('://');
  // A bare path, or a Windows drive letter, is a local file.
  if (colon <= 1) return MediaOrigin.file;
  final scheme = uri.substring(0, colon).toLowerCase();
  if (scheme == 'plex-transcode') return MediaOrigin.plex;
  if (scheme == 'file') return MediaOrigin.file;
  if (scheme.startsWith('smb')) return MediaOrigin.smb;
  return MediaOrigin.http;
}

/// A non-empty string extra of [media], or null.
String? stringExtra(Media media, String key) {
  final v = media.extras?[key];
  return v is String && v.trim().isNotEmpty ? v.trim() : null;
}

/// The title to show for [media] before its tags are known: the `title`
/// extra, else a name taken from the URI (see [nameFromUri]).
String titleOf(Media media) =>
    stringExtra(media, 'title') ?? nameFromUri(media.uri);

/// A readable name for [uri]: the file name without extension for a local
/// path, the last decoded path segment for a URL, the host when the URL has
/// no path. Never includes credentials or the query string.
String nameFromUri(String uri) {
  final colon = uri.indexOf('://');
  if (colon <= 1) return baseNameNoExt(uri);
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return uri.substring(uri.lastIndexOf('/') + 1);
  // pathSegments are already percent-decoded.
  final segments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
  if (parsed.scheme == 'file') {
    return segments.isEmpty ? uri : baseNameNoExt(segments.last);
  }
  if (segments.isEmpty) return parsed.host.isEmpty ? uri : parsed.host;
  return segments.last;
}
