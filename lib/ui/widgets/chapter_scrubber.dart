import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart' show Chapter;

import '../../util/duration_format.dart';
import '../layout/layout.dart';
import '../tokens.dart';

/// A chapter strip for the current track: a thin bar with the playback
/// progress and a dot at each chapter start that stands proud of it, each
/// with a tooltip naming the chapter. The active chapter's title and
/// number sit above. Without chapters it is a plain progress bar.
///
/// With [onSeekChapter] the dots are buttons that jump to their chapter
/// (wire it to `player.setChapter`); with [onSeek] a tap or drag on the
/// bar seeks there. Both null makes the strip read only. [activeTitle]
/// overrides the active chapter's title, for the chapter's own tags
/// (`chapterMetadata`).
class ChapterScrubber extends StatelessWidget {
  final List<Chapter> chapters;
  final Duration position;
  final Duration duration;

  /// Called with the 0-based chapter index when a dot is tapped.
  final ValueChanged<int>? onSeekChapter;

  /// Called with the time under a tap or drag on the bar.
  final ValueChanged<Duration>? onSeek;

  /// The title to show for the active chapter, when known.
  final String? activeTitle;

  const ChapterScrubber({
    super.key,
    required this.chapters,
    required this.position,
    required this.duration,
    this.onSeekChapter,
    this.onSeek,
    this.activeTitle,
  });

  static const double _barH = 6;
  static const double _dot = 13; // > _barH so the dots stick out of the bar

  String _titleOf(int i) {
    if (i == _activeIndex && (activeTitle?.trim().isNotEmpty ?? false)) {
      return activeTitle!.trim();
    }
    final t = chapters[i].title?.trim();
    return t == null || t.isEmpty ? 'Chapter ${i + 1}' : t;
  }

  /// The chapter that holds [position]: the last one starting at or
  /// before it.
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

    if (chapters.isEmpty || totalMs <= 0) return _bar(context, progress);

    final active = _activeIndex;
    final title = _titleOf(active);
    final count = 'Chapter ${active + 1} of ${chapters.length}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: count,
          value: title,
          excludeSemantics: true,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Tokens.label.copyWith(color: Tokens.fg),
                ),
              ),
              const SizedBox(width: Tokens.s8),
              Text(
                '${active + 1} of ${chapters.length}',
                style: Tokens.numeric,
              ),
            ],
          ),
        ),
        const SizedBox(height: Tokens.s8),
        _bar(context, progress),
      ],
    );
  }

  Widget _bar(BuildContext context, double progress) {
    final layout = context.layout;
    // The lane is the tap target: a full one on touch.
    final lane = layout.isTouch ? layout.minTap : 24.0;
    final hit = layout.isTouch ? 32.0 : 24.0;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final hasChapters = chapters.isNotEmpty && duration.inMilliseconds > 0;
        final seek = onSeek;

        double fracOf(Duration t) =>
            (t.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

        void seekAt(double dx) {
          if (seek == null || w <= 0 || duration <= Duration.zero) return;
          seek(duration * (dx / w).clamp(0.0, 1.0));
        }

        final barTop = (lane - _barH) / 2;
        final children = <Widget>[
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
          final jump = onSeekChapter;
          // Later dots paint on top, so dense chapters resolve to the
          // nearest later one. The dot stays on the bar; its wider hit box
          // may stick out of the edges (the Stack does not clip).
          for (var i = 0; i < chapters.length; i++) {
            // On the bar, or in its middle when it is narrower than a dot.
            final cx = w < _dot
                ? w / 2
                : (fracOf(chapters[i].time) * w).clamp(_dot / 2, w - _dot / 2);
            final passed = position >= chapters[i].time;
            final name = '${_titleOf(i)}, ${formatDuration(chapters[i].time)}';
            children.add(
              Positioned(
                left: cx - hit / 2,
                top: 0,
                bottom: 0,
                width: hit,
                child: Semantics(
                  button: jump != null,
                  label: name,
                  excludeSemantics: true,
                  onTap: jump == null ? null : () => jump(i),
                  child: Tooltip(
                    message: name,
                    preferBelow: false,
                    child: MouseRegion(
                      cursor: jump != null
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: jump == null ? null : () => jump(i),
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
              ),
            );
          }
        }

        return MouseRegion(
          cursor: seek != null ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: seek == null ? null : (d) => seekAt(d.localPosition.dx),
            onHorizontalDragUpdate: seek == null
                ? null
                : (d) => seekAt(d.localPosition.dx),
            child: SizedBox(
              height: lane,
              child: Stack(clipBehavior: Clip.none, children: children),
            ),
          ),
        );
      },
    );
  }
}
