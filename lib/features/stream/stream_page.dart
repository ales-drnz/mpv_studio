import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/chapter_scrubber.dart';
import '../../ui/widgets/custom_url_bar.dart';
import '../../ui/widgets/section_body.dart';
import '../../ui/widgets/section_header.dart';
import '../../util/media_labels.dart';
import 'media_server.dart';
import 'samba_browser_tab.dart';
import 'server_library_tab.dart';

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

/// Reference network streams (codecs, lossless, HLS) to exercise the
/// engine's network + demuxer paths. Tap to play, or queue with the
/// add button.
const _streamCategories = <StreamCategory>[
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
    name: 'Lossless & hi-fi',
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

/// Reference streams with **embedded chapter markers** in their container, for
/// the Chapters tab — they exercise the engine's `chapter-list` → [Chapter]
/// path (and the [ChapterScrubber]) without needing a network resolver. Stable,
/// non-expiring, royalty-free / public-domain.
const _chapterCategories = <StreamCategory>[
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

/// The Stream surface: five windowed tabs — **Lab** (reference network
/// streams), **Chapters** (chapter-bearing reference
/// streams + a now-playing [ChapterScrubber]), **Jellyfin** and **Plex**
/// (connect to a server and browse the paginated music library), and **Samba**
/// (an SMB2/3 share, browsed as a folder tree — see [SambaBrowserTab]). The two
/// media-server clients are created once and kept alive for the lifetime of
/// the page.
class StreamPage extends StatefulWidget {
  const StreamPage({super.key});

  @override
  State<StreamPage> createState() => _StreamPageState();
}

class _StreamPageState extends State<StreamPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    // Servers live app-level (see PlayerScope) so their sessions and the
    // playback reporting persist across navigating away from this page.
    final jellyfin = PlayerScope.serverOf(context, ServerKind.jellyfin);
    final plex = PlayerScope.serverOf(context, ServerKind.plex);
    return Column(
      // Fill the width so the tab strip and tab bodies sit flush-left instead
      // of the Column's default centre alignment.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChromeTabBar(
          selected: _tab,
          tabs: const ['Lab', 'Chapters', 'Jellyfin', 'Plex', 'Samba'],
          onSelect: (i) => setState(() => _tab = i),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            sizing: StackFit.expand,
            children: [
              const _LabTab(),
              const _ChaptersTab(),
              ServerLibraryTab(server: jellyfin),
              ServerLibraryTab(server: plex),
              const SambaBrowserTab(),
            ],
          ),
        ),
      ],
    );
  }
}

/// A Chrome/VS-Code-style tab strip: a raised [Tokens.surface] bar with
/// rounded-top tabs. The active tab is filled with the content colour
/// ([Tokens.bg]) so it visually merges into the page below, topped by an
/// accent line; inactive tabs are transparent and dim.
class _ChromeTabBar extends StatelessWidget {
  final int selected;
  final List<String> tabs;
  final ValueChanged<int> onSelect;

  const _ChromeTabBar({
    required this.selected,
    required this.tabs,
    required this.onSelect,
  });

  static const _radius = BorderRadius.vertical(top: Radius.circular(12));
  static const _shape = ContinuousRectangleBorder(borderRadius: _radius);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Tokens.surface,
      padding: const EdgeInsets.only(
        top: Tokens.s6,
        left: Tokens.s8,
        right: Tokens.s8,
      ),
      // Left-aligned tab strip; scrolls horizontally if the tabs ever exceed
      // the width (e.g. on a phone).
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [for (var i = 0; i < tabs.length; i++) _tab(i)],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final active = i == selected;
    return Padding(
      padding: const EdgeInsets.only(right: Tokens.s4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => onSelect(i),
          customBorder: _shape,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: active ? Tokens.bg : Colors.transparent,
              shape: _shape,
            ),
            // IntrinsicWidth bounds the column to the label width inside the
            // unconstrained Row, so the stretched accent bar isn't asked for
            // an infinite width.
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 2,
                    color: active ? Tokens.accent : Colors.transparent,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Tokens.s16,
                      Tokens.s6,
                      Tokens.s16,
                      Tokens.s12,
                    ),
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                        color: active ? Tokens.fg : Tokens.fgDim,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Reference-stream browser (the original Stream content): a custom-URL bar
/// over the curated reference-stream list. No chunking — these are fast,
/// trusted test servers where one open-ended request buffers fastest.
class _LabTab extends StatelessWidget {
  const _LabTab();

  @override
  Widget build(BuildContext context) =>
      const _ReferenceTab(categories: _streamCategories);
}

/// The Chapters tab: reference streams that carry embedded chapter markers
/// (Auphonic demos, a LibriVox M4B) to exercise the engine's `chapter-list`
/// path, with a now-playing [ChapterScrubber] shown above whenever the current
/// track actually has chapters (chapters injected via `setChapters` show
/// here too).
class _ChaptersTab extends StatelessWidget {
  const _ChaptersTab();

  @override
  Widget build(BuildContext context) => const _ReferenceTab(
    categories: _chapterCategories,
    nowPlayingChapters: true,
  );
}

/// The now-playing chapters card: the current track's title over a
/// [ChapterScrubber]. Subscribes to the engine's playlist / chapters /
/// position / duration so the bar tracks playback. **Shown only while the
/// current track actually has chapters** — otherwise it collapses away.
class _NowPlayingChapters extends StatefulWidget {
  final Player player;
  const _NowPlayingChapters({required this.player});

  @override
  State<_NowPlayingChapters> createState() => _NowPlayingChaptersState();
}

class _NowPlayingChaptersState extends State<_NowPlayingChapters> {
  final _subs = <StreamSubscription<dynamic>>[];
  late String _title;
  late List<Chapter> _chapters;
  late Duration _position;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    final s = widget.player.state;
    _title = _titleOf(s.playlist);
    _chapters = s.chapters;
    _position = s.position;
    _duration = s.duration;
    final st = widget.player.stream;
    _subs.add(
      st.playlist.listen((pl) {
        final t = _titleOf(pl);
        if (mounted && t != _title) setState(() => _title = t);
      }),
    );
    _subs.add(
      st.chapters.listen((c) {
        if (mounted) setState(() => _chapters = c);
      }),
    );
    _subs.add(
      st.position.listen((p) {
        if (mounted) setState(() => _position = p);
      }),
    );
    _subs.add(
      st.duration.listen((d) {
        if (mounted) setState(() => _duration = d);
      }),
    );
  }

  static String _titleOf(Playlist pl) {
    if (pl.items.isEmpty || pl.index < 0 || pl.index >= pl.items.length) {
      return '';
    }
    return titleOf(pl.items[pl.index]);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only surfaces for a track that genuinely carries chapters.
    if (_chapters.isEmpty || _duration <= Duration.zero) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: Tokens.s12),
      padding: const EdgeInsets.fromLTRB(
        Tokens.s16,
        Tokens.s12,
        Tokens.s16,
        Tokens.s12,
      ),
      decoration: ShapeDecoration(
        color: Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.music_note_rounded, size: 16, color: Tokens.accent),
              const SizedBox(width: Tokens.s8),
              Expanded(
                child: Text(
                  _title.isEmpty ? 'Now playing' : _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: Tokens.s12),
          ChapterScrubber(
            chapters: _chapters,
            position: _position,
            duration: _duration,
            // Tap a dot → jump to that chapter (native chapter navigation).
            onSeekChapter: widget.player.setChapter,
          ),
        ],
      ),
    );
  }
}

/// The "origin" of the currently-playing track — the key that lights up the
/// row that started it. It's the `origin` extra when set, or else the media URI (Lab/Chapters play a tile's URL directly).
/// Empty when nothing is playing.
String _playingOrigin(Playlist pl) {
  if (pl.items.isEmpty || pl.index < 0 || pl.index >= pl.items.length) {
    return '';
  }
  final m = pl.items[pl.index];
  return (m.extras?['origin'] as String?) ?? m.uri;
}

/// Shared layout for the direct-play reference tabs (Lab, Chapters): the shared
/// [CustomUrlBar] over a list of [StreamCategory] groups, with the row that
/// started the current track lit up (like the Jellyfin/Plex lists).
/// [nowPlayingChapters] inserts the [_NowPlayingChapters] card (Chapters tab).
class _ReferenceTab extends StatelessWidget {
  final List<StreamCategory> categories;
  final bool nowPlayingChapters;

  const _ReferenceTab({
    required this.categories,
    this.nowPlayingChapters = false,
  });

  // No title: the queue names a bare URL after its last path segment, and
  // the tags replace that once the stream loads.
  static Media _media(String url) => Media(url, extras: {'artist': 'Stream'});

  @override
  Widget build(BuildContext context) {
    final player = PlayerScope.of(context);
    final issues = PlayerScope.issuesOf(context);
    Future<void> play(String url) =>
        issues.guard(() => player.open(_media(url), play: true));

    return StreamBuilder<Playlist>(
      stream: player.stream.playlist,
      initialData: player.state.playlist,
      builder: (context, snap) {
        final origin = _playingOrigin(snap.data ?? player.state.playlist);
        return SectionBody(
          // s16 horizontal matches the Jellyfin/Plex/Samba tabs so the content
          // edge doesn't shift when switching stream tabs.
          padding: const EdgeInsets.fromLTRB(
            Tokens.s16,
            Tokens.s8,
            Tokens.s16,
            Tokens.s32,
          ),
          children: [
            CustomUrlBar(onPlay: play),
            if (nowPlayingChapters) _NowPlayingChapters(player: player),
            const SizedBox(height: Tokens.s16),
            for (final cat in categories) ...[
              SectionHeader(cat.name),
              for (final item in cat.items)
                _StreamTile(
                  player: player,
                  item: item,
                  current: item.url == origin,
                ),
              const SizedBox(height: Tokens.s12),
            ],
          ],
        );
      },
    );
  }
}

class _StreamTile extends StatelessWidget {
  final Player player;
  final StreamItem item;

  /// Whether this tile started the currently-playing track — gets the accent
  /// wash + speaker glyph, like the Jellyfin/Plex rows.
  final bool current;

  const _StreamTile({
    required this.player,
    required this.item,
    this.current = false,
  });

  Media get _media =>
      Media(item.url, extras: {'title': item.label, 'artist': 'Stream'});

  Future<void> _play(BuildContext context) => PlayerScope.issuesOf(
    context,
  ).guard(() => player.open(_media, play: true));

  Future<void> _enqueue(BuildContext context) =>
      PlayerScope.issuesOf(context).guard(() {
        if (player.state.playlist.items.isEmpty) {
          return player.open(_media, play: true);
        }
        return player.add(_media);
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: Tokens.s8),
      decoration: ShapeDecoration(
        color: current ? Tokens.accentWash : Tokens.surface,
        shape: Tokens.squircle(Tokens.rMd),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () => _play(context),
          customBorder: Tokens.squircle(Tokens.rMd),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Tokens.s16,
              Tokens.s12,
              Tokens.s8,
              Tokens.s12,
            ),
            child: Row(
              children: [
                if (current) ...[
                  Icon(Icons.volume_up_rounded, size: 16, color: Tokens.accent),
                  const SizedBox(width: Tokens.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: Tokens.body.copyWith(
                          color: current ? Tokens.accent : Tokens.fg,
                          fontWeight: current
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.url,
                        style: Tokens.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _enqueue(context),
                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                  color: Tokens.fgDim,
                  splashRadius: 18,
                  tooltip: 'Add to queue',
                ),
                IconButton(
                  onPressed: () => _play(context),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  color: Tokens.accent,
                  splashRadius: 18,
                  tooltip: 'Play',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
