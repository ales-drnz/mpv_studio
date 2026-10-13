import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show Chapter;

import '../tokens.dart';

/// A YouTube-style chapter strip for the currently-playing track: a thin bar
/// with a dot at each chapter boundary (the dots stand proud of the bar), a
/// coloured fill showing playback progress, and a per-dot tooltip with the
/// chapter name. The active chapter's name sits above it.
///
/// When [onSeekChapter] is provided the dots are **clickable** — tapping one
/// jumps straight to that chapter (the caller typically wires it to
/// `player.setChapter`). With [onSeekChapter] null the strip is purely visual.
class ChapterScrubber extends StatelessWidget {
  final List<Chapter> chapters;
  final Duration position;
  final Duration duration;

  /// Called with the 0-based chapter index when a dot is tapped. Null = the
  /// strip is read-only (no click, default cursor).
  final ValueChanged<int>? onSeekChapter;

  const ChapterScrubber({
    super.key,
    required this.chapters,
    required this.position,
    required this.duration,
    this.onSeekChapter,
  });

  static const double _barH = 6;
  static const double _laneH = 24;
  static const double _dot = 13; // > _barH so the dots stick out of the bar
  static const double _hit = 24; // tap/hover target around each dot

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }

  String _titleOf(int i) => (chapters[i].title?.trim().isNotEmpty ?? false)
      ? chapters[i].title!.trim()
      : 'Chapter ${i + 1}';

  /// Index of the chapter that contains [position] (the last one whose start
  /// is at or before the playhead).
  int get _activeIndex {
    var idx = 0;
    for (var i = 0; i < chapters.length; i++) {
      if (position >= chapters[i].time) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final progress = totalMs <= 0
        ? 0.0
        : (position.inMilliseconds / totalMs).clamp(0.0, 1.0);

    // No usable chapters: fall back to a plain progress bar so the surface
    // still reads as "now playing".
    if (chapters.isEmpty || totalMs <= 0) return _bar(progress);

    final active = _activeIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _titleOf(active),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Tokens.label.copyWith(color: Tokens.fg),
              ),
            ),
            const SizedBox(width: Tokens.s8),
            Text('${active + 1}/${chapters.length}', style: Tokens.numeric),
          ],
        ),
        const SizedBox(height: Tokens.s8),
        _bar(progress),
      ],
    );
  }

  Widget _bar(double progress) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final hasChapters = chapters.isNotEmpty && duration.inMilliseconds > 0;
        final interactive = onSeekChapter != null;

        double fracOf(Duration t) =>
            (t.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

        const barTop = (_laneH - _barH) / 2;
        final children = <Widget>[
          // Background track (full width).
          Positioned(
            left: 0,
            right: 0,
            top: barTop,
            height: _barH,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Tokens.surface3,
                borderRadius: BorderRadius.circular(_barH / 2),
              ),
            ),
          ),
          // Progress fill — left-anchored to the exact width.
          Positioned(
            left: 0,
            top: barTop,
            height: _barH,
            width: progress.clamp(0.0, 1.0) * w,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Tokens.accent,
                borderRadius: BorderRadius.circular(_barH / 2),
              ),
            ),
          ),
        ];

        if (hasChapters) {
          // One clickable dot per chapter, standing proud of the bar, with a
          // tooltip + (when interactive) a click cursor and a comfortable hit
          // target. Later dots paint on top, so dense chapters resolve to the
          // nearest-later one.
          for (var i = 0; i < chapters.length; i++) {
            // Dot centre, kept fully on the bar; the (wider) hit box around it
            // may overflow the edges harmlessly (Stack is Clip.none).
            final cx = (fracOf(chapters[i].time) * w).clamp(
              _dot / 2,
              w - _dot / 2,
            );
            final passed = position >= chapters[i].time;
            children.add(
              Positioned(
                left: cx - _hit / 2,
                top: 0,
                bottom: 0,
                width: _hit,
                child: Tooltip(
                  message: '${_titleOf(i)}  ·  ${_fmt(chapters[i].time)}',
                  preferBelow: false,
                  child: MouseRegion(
                    cursor: interactive
                        ? SystemMouseCursors.click
                        : MouseCursor.defer,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: interactive ? () => onSeekChapter!(i) : null,
                      child: Center(
                        child: Container(
                          width: _dot,
                          height: _dot,
                          decoration: BoxDecoration(
                            color: passed ? Tokens.accent : Tokens.fgFaint,
                            shape: BoxShape.circle,
                            border: Border.all(color: Tokens.bg, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return SizedBox(
          height: _laneH,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}
