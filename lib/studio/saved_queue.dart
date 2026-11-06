import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// [playlist] in the form the settings keep: each entry's address, its
/// tags and its request headers, and the current entry. Left out: entries
/// with a password in the address (a Samba share: the login lives in the
/// system keychain, not here), live PCM sources and browser `blob:` files,
/// which end with the session.
Object? encodeQueue(Playlist playlist) {
  final current = playlist.index >= 0 && playlist.index < playlist.items.length
      ? playlist.items[playlist.index]
      : null;
  final kept = [
    for (final m in playlist.items)
      if (_keeps(m)) m,
  ];
  if (kept.isEmpty) return null;
  return {
    'index': current == null ? 0 : kept.indexOf(current).clamp(0, kept.length),
    'items': [for (final m in kept) _encode(m)],
  };
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
  if (uri.startsWith('mak-pcm://') || uri.startsWith('blob:')) return false;
  return Uri.tryParse(uri)?.userInfo.isEmpty ?? true;
}

Map<String, Object?> _encode(Media m) => {
  'uri': m.uri,
  if (m.extras case final extras? when extras.isNotEmpty)
    'extras': {
      for (final MapEntry(:key, :value) in extras.entries)
        if (value is String || value is num || value is bool) key: value,
    },
  if (m.httpHeaders case final headers? when headers.isNotEmpty)
    'headers': headers,
};

Media? _decode(Object? json) {
  if (json is! Map || json['uri'] is! String) return null;
  final extras = json['extras'];
  final headers = json['headers'];
  return Media(
    json['uri'] as String,
    extras: extras is Map ? extras.cast<String, Object?>() : null,
    httpHeaders: headers is Map ? headers.cast<String, String>() : null,
  );
}
