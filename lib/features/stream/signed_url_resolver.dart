import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// What the [SignedUrlResolver] did with one request.
enum ResolveOutcome {
  /// Handed mpv a freshly signed, working URL.
  signed,

  /// Handed mpv an already expired URL (the "simulate expiry" switch), so
  /// the open fails and the player asks again with `isRetry`.
  expired,

  /// The URL mpv is about to open is still validly signed: kept as is.
  kept,
}

/// One call of the [SignedUrlResolver], for the Resolver tab's log.
@immutable
class ResolveLogEntry {
  const ResolveLogEntry({
    required this.at,
    required this.uri,
    required this.isRetry,
    required this.outcome,
    required this.elapsed,
    this.returned,
  });

  /// When the call came in.
  final DateTime at;

  /// The URL mpv was about to open ([SourceResolveRequest.uri]).
  final String uri;

  final bool isRetry;
  final ResolveOutcome outcome;

  /// What the resolver handed back; null when it kept [uri].
  final String? returned;

  /// How long the resolver took.
  final Duration elapsed;
}

/// A demo source resolver for links that expire, running entirely in the
/// app.
///
/// An entry whose URI is `studio-signed://<real http url>` (see [wrap]) is
/// played through a signed URL: the real URL plus `exp` (a Unix time) and
/// `sig` query parameters, renewed whenever the player asks again after a
/// failed open (`isRetry`). That is the shape of a CDN or token URL a real
/// service hands out; any such resolver, a YouTube one included, plugs into
/// `Player.setSourceResolver` the same way.
///
/// Test servers ignore the query string, so a merely expired signature would
/// still play. With [simulateExpiry] on, the first resolution instead
/// returns an expired link to a path that does not exist, standing in for a
/// CDN that rejects it: the open fails, the player retries, and the retry
/// gets a fresh, working link. [log] records every call.
///
/// The signature is a keyed FNV-1a checksum: it shows the shape of a signed
/// URL and lets the resolver tell its own fresh links apart, but it is not a
/// security primitive.
class SignedUrlResolver extends ChangeNotifier {
  SignedUrlResolver({
    this.lifetime = const Duration(minutes: 10),
    DateTime Function()? clock,
    Duration Function(void Function() work)? timer,
    String key = 'mpv-studio-demo',
  }) : _clock = clock ?? DateTime.now,
       _timer = timer ?? _measure,
       _key = key;

  /// How long [work] takes, on a stopwatch.
  static Duration _measure(void Function() work) {
    final watch = Stopwatch()..start();
    work();
    return watch.elapsed;
  }

  /// The resolver the app installs at launch, shared with the Resolver tab.
  static final shared = SignedUrlResolver();

  /// The URI scheme of the entries this resolver handles.
  static const scheme = 'studio-signed://';

  /// The path segment the simulated expired link points at.
  static const expiredPath = 'expired-link';

  /// How long a fresh link stays valid.
  final Duration lifetime;

  final DateTime Function() _clock;

  /// Times one resolution for the log (a fixed duration in tests, so the
  /// log reads the same on every run).
  final Duration Function(void Function() work) _timer;
  final String _key;

  static const _maxLog = 50;
  final _log = Queue<ResolveLogEntry>();

  /// The calls so far, newest first, capped at the last 50.
  List<ResolveLogEntry> get log => List.unmodifiable(_log);

  /// Whether the first resolution of an entry hands out an expired link.
  bool get simulateExpiry => _simulateExpiry;
  bool _simulateExpiry = true;
  set simulateExpiry(bool value) {
    if (value == _simulateExpiry) return;
    _simulateExpiry = value;
    notifyListeners();
  }

  /// Empties [log].
  void clearLog() {
    if (_log.isEmpty) return;
    _log.clear();
    notifyListeners();
  }

  /// [url] as an entry this resolver signs.
  static String wrap(String url) => '$scheme$url';

  /// The real URL inside a [wrap]ped [uri], or null when [uri] is not one.
  static String? unwrap(String uri) {
    if (!uri.startsWith(scheme)) return null;
    final target = uri.substring(scheme.length);
    final parsed = Uri.tryParse(target);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    return target;
  }

  /// The [SourceResolver]: signs `studio-signed://` entries and leaves
  /// every other entry alone.
  FutureOr<String?> resolve(SourceResolveRequest request) {
    // The original entry, not request.uri: on a retry that is the link that
    // just failed.
    final target = unwrap(request.media.uri);
    if (target == null) return null;
    final now = _clock();
    late final ResolveOutcome outcome;
    late final String? returned;
    final elapsed = _timer(() {
      if (!request.isRetry && isValid(request.uri)) {
        // mpv runs the pre-open pass again after a retry rewrite, with the
        // fresh link already in place: keep it.
        outcome = ResolveOutcome.kept;
        returned = null;
      } else if (!request.isRetry && _simulateExpiry) {
        outcome = ResolveOutcome.expired;
        returned = sign(_brokenVariant(target), now.subtract(lifetime));
      } else {
        outcome = ResolveOutcome.signed;
        returned = sign(target, now.add(lifetime));
      }
    });
    _record(
      ResolveLogEntry(
        at: now,
        uri: request.uri,
        isRetry: request.isRetry,
        outcome: outcome,
        returned: returned,
        elapsed: elapsed,
      ),
    );
    return returned;
  }

  /// [url] with `exp` set to [expires] and a matching `sig`.
  String sign(String url, DateTime expires) {
    final exp = expires.millisecondsSinceEpoch ~/ 1000;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}exp=$exp&sig=${_signature(url, exp)}';
  }

  /// Whether [url] carries this resolver's signature and has not expired.
  bool isValid(String url) {
    final i = url.lastIndexOf(RegExp(r'[?&]exp='));
    if (i < 0) return false;
    final base = url.substring(0, i);
    final params = Uri.splitQueryString(url.substring(i + 1));
    final exp = int.tryParse(params['exp'] ?? '');
    if (exp == null || params['sig'] != _signature(base, exp)) return false;
    return exp * 1000 > _clock().millisecondsSinceEpoch;
  }

  String _signature(String url, int exp) {
    // FNV-1a, 32 bit, over the key, the URL and the expiry.
    var h = 0x811c9dc5;
    for (final b in utf8.encode('$_key|$url|$exp')) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16).padLeft(8, '0');
  }

  /// [url] on a path that does not exist, so the open fails.
  static String _brokenVariant(String url) {
    final u = Uri.parse(url);
    return u.replace(pathSegments: [expiredPath, ...u.pathSegments]).toString();
  }

  void _record(ResolveLogEntry entry) {
    _log.addFirst(entry);
    while (_log.length > _maxLog) {
      _log.removeLast();
    }
    notifyListeners();
  }
}
