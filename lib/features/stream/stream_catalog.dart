import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// One streamable reference URL.
class StreamItem {
  final String label;
  final String url;
  const StreamItem({required this.label, required this.url});
}

/// A named group of [StreamItem]s.
class StreamCategory {
  final String name;
  final List<StreamItem> items;
  const StreamCategory({required this.name, required this.items});
}

/// Reference network streams (codecs, lossless, HLS) for the Lab tab, to
/// exercise the engine's network and demuxer paths.
const labStreams = <StreamCategory>[
  StreamCategory(
    name: 'MP3 reference',
    items: [
      StreamItem(
        label: 'MP3 128k Stereo (standard)',
        url: 'https://streams.radiomast.io/ref-128k-mp3-stereo',
      ),
      StreamItem(
        label: 'MP3 128k Stereo (with preroll)',
        url: 'https://streams.radiomast.io/ref-128k-mp3-stereo-preroll',
      ),
      StreamItem(
        label: 'MP3 32k Mono (low-bandwidth)',
        url: 'https://streams.radiomast.io/ref-32k-mp3-mono',
      ),
    ],
  ),
  StreamCategory(
    name: 'AAC reference',
    items: [
      StreamItem(
        label: 'AAC-LC 128k Stereo',
        url: 'https://streams.radiomast.io/ref-128k-aaclc-stereo',
      ),
      StreamItem(
        label: 'HE-AAC v1 64k Stereo (SBR)',
        url: 'https://streams.radiomast.io/ref-64k-heaacv1-stereo',
      ),
      StreamItem(
        label: 'HE-AAC v2 64k Stereo (SBR+PS)',
        url: 'https://streams.radiomast.io/ref-64k-heaacv2-stereo',
      ),
      StreamItem(
        label: 'HE-AAC v1 24k Mono',
        url: 'https://streams.radiomast.io/ref-24k-heaacv1-mono',
      ),
    ],
  ),
  StreamCategory(
    name: 'Ogg and open formats',
    items: [
      StreamItem(
        label: 'Ogg Vorbis 64k Stereo',
        url: 'https://streams.radiomast.io/ref-64k-ogg-vorbis-stereo',
      ),
      StreamItem(
        label: 'Ogg Opus 64k Stereo',
        url: 'https://streams.radiomast.io/ref-64k-ogg-opus-stereo',
      ),
    ],
  ),
  StreamCategory(
    name: 'Lossless and hi-fi',
    items: [
      StreamItem(
        label: 'Ogg FLAC (16-bit lossless)',
        url: 'https://streams.radiomast.io/ref-lossless-ogg-flac-stereo',
      ),
      StreamItem(
        label: 'Radio Paradise (main mix FLAC)',
        url: 'http://stream.radioparadise.com/flacm',
      ),
    ],
  ),
  StreamCategory(
    name: 'HLS (HTTP Live Streaming)',
    items: [
      StreamItem(
        label: 'MP3 128k HLS adaptive',
        url: 'https://streams.radiomast.io/ref-128k-mp3-stereo/hls.m3u8',
      ),
      StreamItem(
        label: 'AAC-LC 128k HLS adaptive',
        url: 'https://streams.radiomast.io/ref-128k-aaclc-stereo/hls.m3u8',
      ),
      StreamItem(
        label: 'Apple BipBop (HLS audio)',
        url:
            'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear0/prog_index.m3u8',
      ),
    ],
  ),
];

/// Reference streams with embedded chapter markers in their container, for
/// the Chapters tab: they exercise the engine's `chapter-list` path and the
/// chapter scrubber. Stable, non-expiring, royalty-free or public domain.
const chapterStreams = <StreamCategory>[
  StreamCategory(
    name: 'Embedded chapters',
    items: [
      StreamItem(
        label: 'Auphonic demo · 8 chapters (MP4, m4a)',
        url: 'https://auphonic.com/media/blog/auphonic_chapters_demo.m4a',
      ),
      StreamItem(
        label: 'Auphonic demo · 8 chapters (MP3, ID3 CHAP)',
        url: 'https://auphonic.com/media/blog/auphonic_chapters_demo.mp3',
      ),
      StreamItem(
        label:
            'LibriVox · Saga of Grettir the Strong (long M4B, many chapters)',
        url:
            'https://ia800905.us.archive.org/17/items/sagaofgrettirthestrong_2507_librivox/SagaGrettir_LibriVox.m4b',
      ),
    ],
  ),
];

/// [item] as a queue entry. No artist: the stream's own tags fill it in
/// once it loads.
Media streamMedia(StreamItem item) =>
    Media(item.url, extras: {'title': item.label});
