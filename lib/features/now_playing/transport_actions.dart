import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/playback_issues.dart';
import '../../studio/player_scope.dart';
import '../../ui/widgets/studio_snack.dart';
import '../../util/duration_format.dart';

/// The playback actions shared by the Playback page, the mini-player and
/// the keyboard shortcuts. Each runs its player calls through a
/// [CallGuard] and reports what the user should know (the end of the
/// queue, a new speed) through [notify].
typedef Notify = void Function(String message);

/// Shows [message] as a short toast on the nearest messenger, for a
/// control hosted without the app around it (the widget tests). In the app
/// [feedbackFor] goes through [PlaybackIssues.notify] instead. Does nothing
/// once [context] is gone.
void showPlaybackFeedback(BuildContext context, String message) {
  showStudioSnack(context, message, duration: const Duration(seconds: 2));
}

/// A [Notify] for feedback on an action that worked or had nothing to do:
/// the app's informational notice ([PlaybackIssues.notify]), or a toast
/// above [context] when there is no app around it.
Notify feedbackFor(BuildContext context) {
  final issues = context
      .getInheritedWidgetOfExactType<PlayerScope>()
      ?.studio
      .issues;
  if (issues != null) return issues.notify;
  return (message) => showPlaybackFeedback(context, message);
}

/// Goes to the next ([forward]) or previous queue entry. When there is
/// none, says "End of queue" or "Start of queue". With [force], going past
/// either end stops playback instead.
Future<void> skipTrack(
  PlayerApi player,
  CallGuard guard, {
  required bool forward,
  bool force = false,
  Notify? notify,
}) async {
  final moved = await guard<bool>(
    () => forward ? player.next(force: force) : player.previous(force: force),
  );
  if (moved == false) notify?.call(forward ? 'End of queue' : 'Start of queue');
}

/// Plays when paused and pauses when playing, on the play intent.
Future<void> togglePlay(PlayerApi player, CallGuard guard) =>
    guard(player.state.playWhenReady ? player.pause : player.play);

/// The step the A-B loop takes next: set A, then B, then clear.
enum AbLoopStep { setA, setB, clear }

/// The [AbLoopStep] after the loop points of [state].
AbLoopStep nextAbLoopStep(PlayerState state) {
  if (state.abLoopA == null) return AbLoopStep.setA;
  if (state.abLoopB == null) return AbLoopStep.setB;
  return AbLoopStep.clear;
}

/// Sets loop point A at [at].
Future<void> setLoopA(
  PlayerApi player,
  CallGuard guard,
  Duration at, {
  Notify? notify,
}) async {
  final b = player.state.abLoopB;
  final done = await guard(() async {
    // A point after B would make an empty loop: B moves out of the way.
    if (b != null && at >= b) await player.setAbLoopB(null);
    await player.setAbLoopA(at);
    return true;
  });
  if (done == true) notify?.call('Loop A at ${formatDuration(at)}');
}

/// Sets loop point B at [at]. When [at] comes before A, the two swap, so
/// the loop always runs forwards. Like mpv's own `ab-loop` command, a
/// playhead outside the new loop goes back to its start: mpv only loops on
/// reaching B, so a B set at or behind the playhead would otherwise never
/// take effect.
Future<void> setLoopB(
  PlayerApi player,
  CallGuard guard,
  Duration at, {
  Notify? notify,
}) async {
  final a = player.state.abLoopA;
  final done = await guard(() async {
    final Duration start;
    final Duration end;
    if (a != null && at < a) {
      (start, end) = (at, a);
      await player.setAbLoopA(start);
      await player.setAbLoopB(end);
    } else {
      (start, end) = (a ?? Duration.zero, at);
      await player.setAbLoopB(end);
    }
    final pos = player.state.position;
    if (pos < start || pos >= end) await player.seek(start);
    return true;
  });
  if (done == true) notify?.call('Loop B at ${formatDuration(at)}');
}

/// Removes both loop points.
Future<void> clearLoop(PlayerApi player, CallGuard guard, {Notify? notify}) {
  return guard(() async {
    await player.setAbLoopA(null);
    await player.setAbLoopB(null);
    notify?.call('A-B loop cleared');
  });
}

/// Takes the next [AbLoopStep] at the playhead: the L shortcut.
Future<void> cycleAbLoop(PlayerApi player, CallGuard guard, {Notify? notify}) {
  final at = player.state.position;
  return switch (nextAbLoopStep(player.state)) {
    AbLoopStep.setA => setLoopA(player, guard, at, notify: notify),
    AbLoopStep.setB => setLoopB(player, guard, at, notify: notify),
    AbLoopStep.clear => clearLoop(player, guard, notify: notify),
  };
}

/// The title of chapter [index] of [state]: the active chapter's own tags
/// first (`chapterMetadata`), then the chapter list, then its number.
String chapterTitle(PlayerState state, int index) {
  if (index == state.currentChapter) {
    for (final e in state.chapterMetadata.entries) {
      if (e.key.toLowerCase() == 'title' && e.value.trim().isNotEmpty) {
        return e.value.trim();
      }
    }
  }
  final listed = index >= 0 && index < state.chapters.length
      ? state.chapters[index].title?.trim()
      : null;
  return listed == null || listed.isEmpty ? 'Chapter ${index + 1}' : listed;
}

/// Moves [delta] chapters from the active one. Before the first chapter
/// goes back to its start; past the last says so.
Future<void> stepChapter(
  PlayerApi player,
  CallGuard guard,
  int delta, {
  Notify? notify,
}) async {
  final count = player.state.chapters.length;
  if (count == 0) {
    notify?.call('This track has no chapters');
    return;
  }
  final target = (player.state.currentChapter ?? -1) + delta;
  if (target >= count) {
    notify?.call('Last chapter');
    return;
  }
  final index = target < 0 ? 0 : target;
  await guard(() => player.setChapter(index));
}

/// The playback speeds the speed shortcuts step through.
const double minRate = 0.25;
const double maxRate = 4;

/// Changes the speed by [delta] (or back to normal with [reset]), and
/// says the new speed.
Future<void> stepRate(
  PlayerApi player,
  CallGuard guard, {
  double delta = 0,
  bool reset = false,
  Notify? notify,
}) async {
  final raw = reset ? 1.0 : player.state.rate + delta;
  final rate = (raw.clamp(minRate, maxRate) * 100).roundToDouble() / 100;
  final done = await guard(() async {
    await player.setRate(rate);
    return true;
  });
  if (done == true) notify?.call('Speed ${formatRate(rate)}');
}

/// A speed as the UI shows it: "1x", "1.25x".
String formatRate(double rate) {
  final s = rate.toStringAsFixed(2);
  final trimmed = s.replaceFirst(RegExp(r'\.?0+$'), '');
  return '${trimmed}x';
}

/// Changes the volume by [delta] percent, within the player's maximum.
Future<void> stepVolume(PlayerApi player, CallGuard guard, double delta) {
  final max = player.state.volumeMax < 100 ? 100.0 : player.state.volumeMax;
  final next = (player.state.volume + delta).clamp(0.0, max);
  return guard(() => player.setVolume(next.roundToDouble()));
}
