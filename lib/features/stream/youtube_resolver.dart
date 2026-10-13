import 'package:mpv_audio_kit/mpv_audio_kit.dart' show Chapter;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// A YouTube video resolved to a directly-playable audio stream plus its
/// chapter markers.
class ResolvedYoutube {
  /// A `googlevideo` audio-only URL mpv can open directly. **Expires** (a few
  /// hours, IP-bound) — resolve at play time, don't cache. Throttled by the
  /// CDN, so play it with `Media.httpChunkSize` (8 MiB).
  final String streamUrl;

  /// The `User-Agent` to send when fetching [streamUrl]. googlevideo rejects
  /// ffmpeg's default `Lavf/…` UA with **403**, so this MUST ride along as an
  /// HTTP header (`Media.httpHeaders`). It's the UA of the client that
  /// produced the stream.
  final String userAgent;

  final String title;
  final String author;
  final Duration? duration;

  /// Chapters parsed from the video description (YouTube keeps chapters in the
  /// description, not in the audio container), to be injected via
  /// `player.setChapters` once the stream is loaded. Empty when the video has
  /// no valid chapter list.
  final List<Chapter> chapters;

  const ResolvedYoutube({
    required this.streamUrl,
    required this.userAgent,
    required this.title,
    required this.author,
    required this.duration,
    required this.chapters,
  });
}

/// Resolves YouTube watch URLs/IDs to a playable audio stream + chapters,
/// entirely in Dart (no yt-dlp binary, no mpv scripting) so it works on every
/// platform the app ships on. This is the *product*-side YouTube integration:
/// it lives in the app, not in `mpv_audio_kit`, exactly like the Jellyfin/Plex
/// clients — the engine stays source-agnostic and only receives a resolved URL
/// + chapters through its stable API.
class YoutubeResolver {
  final YoutubeExplode _yt = YoutubeExplode();

  // Resolution clients, in priority order. **ANDROID_VR is the one that
  // matters**: it needs no PoToken, so googlevideo serves the FULL stream
  // (verified: HTTP 206 at byte offsets 0, 2 MiB, 5 MiB, and for 8 MiB
  // chunks). The plain `android` / `androidSdkless` clients are PoToken-GATED —
  // googlevideo returns only a ~1 MiB preview from offset 0 then 403s every
  // later byte, so the file "opens" then dies after ~1 MiB. They are therefore
  // deliberately NOT used (a gated preview is worse than a clean failure).
  // `ios` is a secondary full-access fallback for videos VR can't resolve.
  static final List<YoutubeApiClient> _clients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.ios,
  ];

  /// Resolves [urlOrId] (a `youtube.com/watch?v=…`, `youtu.be/…`, or a bare
  /// video id) to its best audio-only stream + matching User-Agent + parsed
  /// chapters. Throws if no client could produce an audio stream.
  Future<ResolvedYoutube> resolve(String urlOrId) async {
    final video = await _yt.videos.get(urlOrId);
    Object? lastError;
    for (final client in _clients) {
      try {
        final manifest = await _yt.videos.streamsClient.getManifest(
          urlOrId,
          ytClients: [client],
        );
        final audio = manifest.audioOnly.withHighestBitrate();
        return ResolvedYoutube(
          streamUrl: audio.url.toString(),
          userAgent: _userAgentOf(client),
          title: video.title,
          author: video.author,
          duration: video.duration,
          chapters: parseChapters(video.description, video.duration),
        );
      } catch (e) {
        lastError = e; // try the next client
      }
    }
    throw Exception('No playable audio stream: $lastError');
  }

  // The User-Agent string baked into a client's request payload
  // (`context.client.userAgent`), needed to replay its googlevideo stream.
  static String _userAgentOf(YoutubeApiClient client) {
    final c = (client.payload['context'] as Map?)?['client'] as Map?;
    return (c?['userAgent'] as String?) ?? '';
  }

  void dispose() => _yt.close();
}

// A timestamp anywhere in a line: `h:mm:ss` or `m:ss` (hours optional).
final RegExp _timestamp = RegExp(r'(?:(\d{1,2}):)?(\d{1,2}):(\d{2})');
// Leading/trailing separators around a chapter title once the timestamp is cut.
final RegExp _leadSep = RegExp(r'^[\s\-–—•·:|)\].]+');
final RegExp _trailSep = RegExp(r'[\s\-–—•·:|(\[]+$');

/// Parses YouTube-style chapters from a video [description], mirroring
/// YouTube's own rules so the result matches what the site would show: the
/// list counts only when the **first timestamp is 0:00**, there are **at least
/// 3** of them, and they are **strictly increasing**. Each line may put the
/// timestamp before or after the title. Returns an empty list when the
/// description doesn't describe valid chapters.
///
/// Exposed (not private) so it's unit-testable without a network round-trip.
List<Chapter> parseChapters(String description, Duration? duration) {
  final found = <({Duration time, String title})>[];
  for (final raw in description.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final m = _timestamp.firstMatch(line);
    if (m == null) continue;
    final h = int.tryParse(m.group(1) ?? '0') ?? 0;
    final time = Duration(
      hours: h,
      minutes: int.parse(m.group(2)!),
      seconds: int.parse(m.group(3)!),
    );
    // Title = the line with the timestamp token and its bracketing
    // separators stripped from whichever side it sat on.
    final title = (line.substring(0, m.start) + line.substring(m.end))
        .replaceFirst(_leadSep, '')
        .replaceFirst(_trailSep, '')
        .trim();
    found.add((time: time, title: title));
  }

  if (found.length < 3 || found.first.time != Duration.zero) return const [];
  for (var i = 1; i < found.length; i++) {
    if (found[i].time <= found[i - 1].time) return const [];
  }
  if (duration != null && found.last.time >= duration) return const [];

  return [
    for (var i = 0; i < found.length; i++)
      Chapter(
        time: found[i].time,
        title: found[i].title.isEmpty ? 'Chapter ${i + 1}' : found[i].title,
      ),
  ];
}
