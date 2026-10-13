import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../../studio/playback_issues.dart';
import '../../../../ui/layout/layout.dart';
import '../../../../util/duration_format.dart';
import '../../transport_actions.dart';

enum _MeterAction { seek, setA, setB, clearLoop, previousChapter, nextChapter }

/// The waveform's context menu for the point at media time [at]: seek
/// there, set loop A or B there, clear the loop, and step chapters. A
/// popup at [position] with a pointer, a bottom sheet on touch.
Future<void> showWaveformMenu(
  BuildContext context, {
  required PlayerApi player,
  required CallGuard guard,
  required Duration at,
  Offset? position,
}) async {
  final state = player.state;
  final time = formatDuration(at);
  final hasLoop = state.abLoopA != null || state.abLoopB != null;
  final chapters = state.chapters;
  final current = state.currentChapter ?? -1;
  final notify = feedbackFor(context);
  final picked = await showStudioMenu<_MeterAction>(
    context,
    position: position,
    title: 'At $time',
    items: [
      StudioMenuItem(
        value: _MeterAction.seek,
        label: 'Play from $time',
        icon: Icons.play_arrow_rounded,
      ),
      StudioMenuItem(
        value: _MeterAction.setA,
        label: 'Set loop A at $time',
        icon: Icons.flag_outlined,
      ),
      StudioMenuItem(
        value: _MeterAction.setB,
        label: 'Set loop B at $time',
        icon: Icons.flag_rounded,
      ),
      if (hasLoop)
        const StudioMenuItem(
          value: _MeterAction.clearLoop,
          label: 'Clear A-B loop',
          icon: Icons.layers_clear_rounded,
          destructive: true,
        ),
      if (chapters.isNotEmpty) ...[
        const StudioMenuItem(
          value: _MeterAction.previousChapter,
          label: 'Previous chapter',
          icon: Icons.skip_previous_rounded,
        ),
        StudioMenuItem(
          value: _MeterAction.nextChapter,
          label: 'Next chapter',
          icon: Icons.skip_next_rounded,
          enabled: current < chapters.length - 1,
        ),
      ],
    ],
  );
  switch (picked) {
    case null:
      return;
    case _MeterAction.seek:
      await guard(() => player.seek(at, exact: true));
    case _MeterAction.setA:
      await setLoopA(player, guard, at, notify: notify);
    case _MeterAction.setB:
      await setLoopB(player, guard, at, notify: notify);
    case _MeterAction.clearLoop:
      await clearLoop(player, guard, notify: notify);
    case _MeterAction.previousChapter:
      await stepChapter(player, guard, -1, notify: notify);
    case _MeterAction.nextChapter:
      await stepChapter(player, guard, 1, notify: notify);
  }
}
