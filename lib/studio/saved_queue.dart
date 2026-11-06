import 'dart:convert';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// [playlist] in the form the settings keep: each entry with its tags and
/// its playback options, and the current entry. Left out, as nothing in
/// the plain settings file may hold a secret or a session that is gone:
/// - server tracks (Jellyfin, Plex): their address or tags carry the
///   session's token, and Plex's a transcode session of this run;
/// - an address with a password in it (a Samba share: the login lives in
///   the system keychain);
/// - live PCM sources and browser `blob:` files, which end with the run;
/// - request headers that carry credentials (Authorization, Cookie, the
///   servers' token headers).
Object? encodeQueue(Playlist playlist) {
  final kept = <Map<String, Object?>>[];
  var index = 0;
  for (final (i, m) in playlist.items.indexed) {
    if (!_keeps(m)) continue;
    if (i == playlist.index) index = kept.length;
    kept.add(_encode(m));
  }
  if (kept.isEmpty) return null;
  return {'index': index, 'items': kept};
}

/// The queue [blob] holds, or null when it holds none.
Playlist? decodeQueue(Object? blob) {
  if (blob is! Map || blob['items'] is! List) return null;
  final items = [for (final e in blob['items'] as List) ?_decode(e)];
  if (items.isEmpty) return null;
  final index = blob['index'];
  return Playlist(
    items,
    index: index is int ? index.clamp(0, items.length - 1) : 0,
  );
}

bool _keeps(Media m) {
  final uri = m.uri;
  if (uri.startsWith('mak-pcm://') ||
      uri.startsWith('blob:') ||
      uri.startsWith('plex-transcode://')) {
    return false;
  }
  final extras = m.extras;
  if (extras != null &&
      (extras['server'] != null || extras['plexSession'] != null)) {
    return false;
  }
  return Uri.tryParse(uri)?.userInfo.isEmpty ?? true;
}

/// Headers that carry a credential, by lower-case name.
const _secretHeaders = {
  'authorization',
  'cookie',
  'proxy-authorization',
  'x-plex-token',
  'x-emby-token',
  'x-emby-authorization',
  'x-mediabrowser-token',
};

Map<String, Object?> _encode(Media m) {
  final headers = {
    for (final MapEntry(:key, :value) in (m.httpHeaders ?? const {}).entries)
      if (!_secretHeaders.contains(key.toLowerCase())) key: value,
  };
  return {
    'uri': m.uri,
    if (_jsonSafe(m.extras) case final extras? when extras.isNotEmpty)
      'extras': extras,
    if (headers.isNotEmpty) 'headers': headers,
    if (m.streamLavfOptions case final o? when o.isNotEmpty) 'streamLavf': o,
    if (m.demuxerLavfOptions case final o? when o.isNotEmpty) 'demuxerLavf': o,
    'chunk': ?m.httpChunkSize,
    if (m.start case final start?) 'startMs': start.inMilliseconds,
    if (m.end case final end?) 'endMs': end.inMilliseconds,
    if (m.waveformDurationHint case final hint?)
      'lengthMs': hint.inMilliseconds,
  };
}

/// The [extras] the settings file can hold: those that go through JSON.
Map<String, Object?>? _jsonSafe(Map<String, Object?>? extras) {
  if (extras == null) return null;
  return {
    for (final MapEntry(:key, :value) in extras.entries)
      if (_encodes(value)) key: value,
  };
}

bool _encodes(Object? value) {
  try {
    jsonEncode(value);
    return true;
  } on Object {
    return false;
  }
}

Media? _decode(Object? json) {
  if (json is! Map || json['uri'] is! String) return null;
  Map<String, String>? strings(Object? v) =>
      v is Map ? v.map((k, v) => MapEntry('$k', '$v')) : null;
  Duration? ms(Object? v) => v is int ? Duration(milliseconds: v) : null;
  final extras = json['extras'];
  final chunk = json['chunk'];
  return Media(
    json['uri'] as String,
    extras: extras is Map ? extras.cast<String, Object?>() : null,
    httpHeaders: strings(json['headers']),
    streamLavfOptions: strings(json['streamLavf']),
    demuxerLavfOptions: strings(json['demuxerLavf']),
    httpChunkSize: chunk is int ? chunk : null,
    start: ms(json['startMs']),
    end: ms(json['endMs']),
    waveformDurationHint: ms(json['lengthMs']),
  );
}
