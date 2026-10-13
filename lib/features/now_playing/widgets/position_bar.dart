import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../studio/playback_issues.dart';
import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../util/duration_format.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';
import '../transport_actions.dart';
import 'transport_controls.dart';

/// The line under the waveform: the elapsed time, the A-B loop chip, what
/// the player waits on (loading, buffering, seeking) and the length.
class PositionBar extends StatelessWidget {
  const PositionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final player = PlaybackScope.of(context).player;
    return Row(
      children: [
        Live<Duration>(
          stream: player.stream.position,
          initial: player.state.position,
          builder: (context, p) => Text(
            formatDuration(p),
            key: const ValueKey('position-elapsed'),
            style: Tokens.numeric.copyWith(color: Tokens.fg),
          ),
        ),
        const SizedBox(width: Tokens.s8),
        PlaybackBusy(
          player: player,
          builder: (context, wait) => wait == null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      key: const ValueKey('position-busy'),
                      dimension: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Tokens.accent,
                      ),
                    ),
                    const SizedBox(width: Tokens.s4),
                    Text(wait.label, style: Tokens.caption),
                  ],
                ),
        ),
        const Expanded(child: Center(child: AbLoopChip())),
        Live<Duration>(
          stream: player.stream.duration,
          initial: player.state.duration,
          builder: (context, d) => Text(
            d > Duration.zero ? formatDuration(d) : '-:--',
            style: Tokens.numeric,
          ),
        ),
      ],
    );
  }
}

/// The chapter line: previous chapter, the current chapter's title and
/// number, next chapter. Shows nothing for a track without chapters.
class ChapterBar extends StatelessWidget {
  const ChapterBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final player = scope.player;
    return Live<List<Chapter>>(
      stream: player.stream.chapters,
      initial: player.state.chapters,
      builder: (context, chapters) {
        if (chapters.isEmpty) return const SizedBox.shrink();
        return Live<int?>(
          stream: player.stream.currentChapter,
          initial: player.state.currentChapter,
          builder: (context, current) => Live<Map<String, String>>(
            stream: player.stream.chapterMetadata,
            initial: player.state.chapterMetadata,
            builder: (context, _) {
              final notify = feedbackFor(context);
              // Before the first chapter starts, mpv reports none.
              final index = current ?? -1;
              final title = index < 0
                  ? 'Before the first chapter'
                  : chapterTitle(player.state, index);
              final count = index < 0
                  ? '${chapters.length} chapters'
                  : 'Chapter ${index + 1} of ${chapters.length}';
              return Row(
                children: [
                  RoundIconButton(
                    icon: Icons.skip_previous_rounded,
                    size: 20,
                    tooltip: 'Previous chapter',
                    onTap: () =>
                        stepChapter(player, scope.guard, -1, notify: notify),
                  ),
                  Expanded(
                    child: Semantics(
                      label: count,
                      value: title,
                      excludeSemantics: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            key: const ValueKey('chapter-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: Tokens.label.copyWith(color: Tokens.fg),
                          ),
                          Text(
                            count,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Tokens.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.skip_next_rounded,
                    size: 20,
                    tooltip: 'Next chapter',
                    onTap: index < chapters.length - 1
                        ? () => stepChapter(
                            player,
                            scope.guard,
                            1,
                            notify: notify,
                          )
                        : null,
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

enum _LoopAction { setA, setB, clear, count }

/// The A-B loop at a glance, and its menu: "A-B loop" when off, the two
/// points when set, and a badge with the loops left when it repeats a set
/// number of times. Tap for the menu: set A or B at the playhead, clear,
/// and how many times to repeat (`setAbLoopCount`).
class AbLoopChip extends StatelessWidget {
  const AbLoopChip({super.key});

  static const _counts = <int?>[null, 1, 2, 3, 5, 10];

  static String _countLabel(int? n) => switch (n) {
    null => 'Repeat forever',
    1 => 'Repeat once',
    _ => 'Repeat $n times',
  };

  Future<void> _menu(
    BuildContext context,
    PlayerApi player,
    CallGuard guard,
  ) async {
    final s = player.state;
    final at = s.position;
    final time = formatDuration(at);
    final hasLoop = s.abLoopA != null || s.abLoopB != null;
    final box = context.findRenderObject() as RenderBox?;
    final position = box?.localToGlobal(box.size.bottomLeft(Offset.zero));
    final notify = feedbackFor(context);
    final picked = await showStudioMenu<(_LoopAction, int?)>(
      context,
      position: position,
      title: 'A-B loop',
      items: [
        StudioMenuItem(
          value: (_LoopAction.setA, null),
          label: 'Set A at $time',
          icon: Icons.flag_outlined,
        ),
        StudioMenuItem(
          value: (_LoopAction.setB, null),
          label: 'Set B at $time',
          icon: Icons.flag_rounded,
        ),
        if (hasLoop)
          const StudioMenuItem(
            value: (_LoopAction.clear, null),
            label: 'Clear A-B loop',
            icon: Icons.layers_clear_rounded,
            destructive: true,
          ),
        for (final n in _counts)
          StudioMenuItem(
            value: (_LoopAction.count, n),
            label: _countLabel(n),
            icon: n == s.abLoopCount
                ? Icons.check_rounded
                : Icons.repeat_rounded,
          ),
      ],
    );
    switch (picked) {
      case null:
        return;
      case (_LoopAction.setA, _):
        await setLoopA(player, guard, at, notify: notify);
      case (_LoopAction.setB, _):
        await setLoopB(player, guard, at, notify: notify);
      case (_LoopAction.clear, _):
        await clearLoop(player, guard, notify: notify);
      case (_LoopAction.count, final n):
        await guard(() => player.setAbLoopCount(n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final player = scope.player;
    return Live<Duration?>(
      stream: player.stream.abLoopA,
      initial: player.state.abLoopA,
      builder: (context, a) => Live<Duration?>(
        stream: player.stream.abLoopB,
        initial: player.state.abLoopB,
        builder: (context, b) => Live<int?>(
          stream: player.stream.remainingAbLoops,
          initial: player.state.remainingAbLoops,
          builder: (context, left) => Live<int?>(
            stream: player.stream.abLoopCount,
            initial: player.state.abLoopCount,
            builder: (context, count) {
              final on = a != null || b != null;
              final text = switch ((a, b)) {
                (null, null) => 'A-B loop',
                (final a?, null) => 'A ${formatDuration(a)}',
                (null, final b?) => 'B ${formatDuration(b)}',
                (final a?, final b?) =>
                  '${formatDuration(a)} to ${formatDuration(b)}',
              };
              // The loops left while a counted loop runs, else the count.
              final badge = !on
                  ? null
                  : left != null
                  ? '$left left'
                  : count != null
                  ? '${count}x'
                  : null;
              final semanticsValue = [
                if (on) text else 'off',
                ?badge,
              ].join(', ');
              final color = on ? Tokens.onAccentContainer : Tokens.fgDim;
              final tap = context.layout.minTap;
              return Semantics(
                button: true,
                label: 'A-B loop',
                value: semanticsValue,
                excludeSemantics: true,
                onTap: () => _menu(context, player, scope.guard),
                child: Tooltip(
                  message: 'A-B loop (L)',
                  // The pill is a control high; the hit area a full tap
                  // target around it.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _menu(context, player, scope.guard),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: tap),
                      child: Center(
                        widthFactor: 1,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 32,
                          decoration: ShapeDecoration(
                            color: on
                                ? Tokens.accentContainer
                                : Colors.transparent,
                            shape: Tokens.pill,
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: InkWell(
                              onTap: () => _menu(context, player, scope.guard),
                              customBorder: Tokens.pill,
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: Tokens.s12,
                                  right: badge == null ? Tokens.s12 : Tokens.s4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.repeat_on_rounded,
                                      size: 18,
                                      color: color,
                                    ),
                                    const SizedBox(width: Tokens.s8),
                                    Flexible(
                                      child: Text(
                                        text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Tokens.label.copyWith(
                                          color: color,
                                          fontWeight: on
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (badge != null) ...[
                                      const SizedBox(width: Tokens.s8),
                                      Container(
                                        key: const ValueKey('ab-badge'),
                                        height: 24,
                                        alignment: Alignment.center,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: Tokens.s8,
                                        ),
                                        decoration: ShapeDecoration(
                                          color: Tokens.onAccentContainer,
                                          shape: Tokens.pill,
                                        ),
                                        child: Text(
                                          badge,
                                          maxLines: 1,
                                          style: Tokens.caption.copyWith(
                                            color: Tokens.accentContainer,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
