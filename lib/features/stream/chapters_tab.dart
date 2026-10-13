import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/chapter_scrubber.dart';
import '../../ui/widgets/custom_url_bar.dart';
import '../../util/media_labels.dart';
import 'stream_actions.dart';
import 'stream_catalog.dart';
import 'widgets/reference_list.dart';

/// The Chapters tab: reference streams that carry embedded chapter markers
/// (Auphonic demos, a LibriVox M4B) to exercise the engine's `chapter-list`
/// path, with a now-playing [ChapterScrubber] above them whenever the
/// current track has chapters (chapters set with `setChapters` show too).
class ChaptersTab extends StatelessWidget {
  const ChaptersTab({super.key, required this.actions});

  final StreamActions actions;

  @override
  Widget build(BuildContext context) {
    return PlaylistBuilder(
      player: actions.player,
      builder: (context, pl) => StreamTabBody(
        children: [
          CustomUrlBar(
            onPlay: (url) => actions.play(Media(url)),
            onQueue: (url) => actions.enqueue([Media(url)]),
          ),
          NowPlayingChapters(actions: actions),
          const SizedBox(height: Tokens.s16),
          ...referenceRows(
            categories: chapterStreams,
            actions: actions,
            origin: playingOrigin(pl),
          ),
        ],
      ),
    );
  }
}

/// The now-playing chapters card: the current track's title over a
/// [ChapterScrubber] that follows playback. Shown only while the current
/// track has chapters; otherwise it takes no space.
class NowPlayingChapters extends StatefulWidget {
  const NowPlayingChapters({super.key, required this.actions});

  final StreamActions actions;

  @override
  State<NowPlayingChapters> createState() => _NowPlayingChaptersState();
}

class _NowPlayingChaptersState extends State<NowPlayingChapters> {
  final _subs = <StreamSubscription<Object?>>[];
  late String _title;
  late List<Chapter> _chapters;
  late Duration _position;
  late Duration _duration;

  PlayerApi get _player => widget.actions.player;

  @override
  void initState() {
    super.initState();
    final s = _player.state;
    _title = _titleOf(s.playlist);
    _chapters = s.chapters;
    _position = s.position;
    _duration = s.duration;
    final st = _player.stream;
    void on<T>(Stream<T> stream, void Function(T v) apply) => _subs.add(
      stream.listen((v) {
        if (mounted) setState(() => apply(v));
      }),
    );
    on(st.playlist, (pl) => _title = _titleOf(pl));
    on(st.chapters, (c) => _chapters = c);
    on(st.position, (p) => _position = p);
    on(st.duration, (d) => _duration = d);
  }

  static String _titleOf(Playlist pl) {
    final m = currentMedia(pl);
    return m == null ? '' : titleOf(m);
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
    if (_chapters.isEmpty || _duration <= Duration.zero) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(top: Tokens.s12),
      padding: const EdgeInsets.all(Tokens.s12),
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
            onSeekChapter: (i) =>
                widget.actions.guard(() => _player.setChapter(i)),
          ),
        ],
      ),
    );
  }
}
