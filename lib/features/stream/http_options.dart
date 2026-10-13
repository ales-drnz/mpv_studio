import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// One request header of [HttpOptions].
@immutable
class HttpHeader {
  const HttpHeader(this.name, this.value);

  final String name;
  final String value;

  @override
  bool operator ==(Object other) =>
      other is HttpHeader && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// Per-media HTTP options of the Lab URL entry: extra request headers, a
/// user agent (sent as the `User-Agent` header) and a range request chunk
/// size, carried by the [Media] itself ([Media.httpHeaders] and
/// [Media.httpChunkSize]) so they apply to that entry only.
@immutable
class HttpOptions {
  const HttpOptions({
    this.headers = const [],
    this.userAgent = '',
    this.chunkSize,
  });

  /// The headers in the order entered; rows with an empty name are ignored.
  final List<HttpHeader> headers;

  /// Empty for mpv's default user agent.
  final String userAgent;

  /// The largest HTTP range request in bytes; null for one open-ended
  /// request.
  final int? chunkSize;

  /// The chunk sizes offered, in bytes.
  static const chunkSizes = [1 << 20, 4 << 20, 8 << 20, 16 << 20];

  /// The values last played this session, to prefill the entry.
  static HttpOptions lastUsed = const HttpOptions();

  /// The headers as [Media.httpHeaders]: the named rows, then the user
  /// agent, which wins over a `User-Agent` row. Null when there are none.
  Map<String, String>? get httpHeaders {
    final out = <String, String>{};
    for (final h in headers) {
      final name = h.name.trim();
      if (name.isEmpty) continue;
      if (userAgent.trim().isNotEmpty && _isUserAgent(name)) continue;
      out[name] = h.value.trim();
    }
    final ua = userAgent.trim();
    if (ua.isNotEmpty) out['User-Agent'] = ua;
    return out.isEmpty ? null : out;
  }

  /// How many options are set, for the collapsed section's badge.
  int get count => (httpHeaders?.length ?? 0) + (chunkSize == null ? 0 : 1);

  /// The first problem that would make the player refuse these options, or
  /// null when they are fine.
  String? get problem {
    for (final h in headers) {
      final name = h.name.trim();
      if (name.isEmpty) {
        if (h.value.trim().isNotEmpty) return 'A header needs a name.';
        continue;
      }
      final n = headerNameProblem(name) ?? headerValueProblem(h.value);
      if (n != null) return '$name: $n';
    }
    final ua = headerValueProblem(userAgent);
    if (ua == null) return null;
    // A browser user agent has commas ("KHTML, like Gecko"); the global one
    // is set as a raw property, which takes them.
    return 'User agent: $ua A user agent with commas goes in Settings, '
        'Network.';
  }

  /// [url] as a [Media] with these options and [extras].
  Media media(String url, {Map<String, Object?>? extras}) => Media(
    url,
    extras: extras,
    httpHeaders: httpHeaders,
    httpChunkSize: chunkSize,
  );

  HttpOptions copyWith({
    List<HttpHeader>? headers,
    String? userAgent,
    int? Function()? chunkSize,
  }) => HttpOptions(
    headers: headers ?? this.headers,
    userAgent: userAgent ?? this.userAgent,
    chunkSize: chunkSize == null ? this.chunkSize : chunkSize(),
  );

  static bool _isUserAgent(String name) => name.toLowerCase() == 'user-agent';

  @override
  bool operator ==(Object other) =>
      other is HttpOptions &&
      listEquals(other.headers, headers) &&
      other.userAgent == userAgent &&
      other.chunkSize == chunkSize;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(headers), userAgent, chunkSize);
}

final _token = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");

/// Why [name] cannot be an HTTP header name, or null when it can.
String? headerNameProblem(String name) => _token.hasMatch(name.trim())
    ? null
    : 'use letters, digits and dashes only.';

/// Why [value] cannot be a header value for mpv, or null when it can. mpv
/// separates headers with commas, so a value cannot hold one.
String? headerValueProblem(String value) {
  if (value.contains(',')) return 'commas are not allowed.';
  if (value.contains(RegExp(r'[\r\n\x00]'))) {
    return 'line breaks are not allowed.';
  }
  return null;
}

/// [bytes] as a short size, e.g. `8 MiB`.
String formatChunkSize(int bytes) => bytes >= 1 << 20 && bytes % (1 << 20) == 0
    ? '${bytes >> 20} MiB'
    : '${bytes >> 10} KiB';
