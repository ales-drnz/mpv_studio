import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/now_playing/transport_actions.dart';
import '../studio/playback_issues.dart';
import '../ui/layout/layout.dart';
import '../ui/tokens.dart';

/// Desktop keyboard shortcuts for playback, active anywhere in the app;
/// [playbackShortcutList] lists them and [showShortcutHelp] shows that
/// list (on ? or F1).
///
/// Keys are left alone while a text field has focus, while a menu, dialog
/// or sheet is open, when a modifier is held (so system and app shortcuts
/// keep working; Shift is allowed for the ?) and when [enabled] is false.
/// A focused button still gets its own Space: it handles the key before
/// it bubbles up here. The player calls run through [guard]; what the
/// user should know (the end of the queue, a new speed) shows as a toast.
class PlaybackShortcuts extends StatelessWidget {
  final PlayerApi player;
  final bool enabled;
  final CallGuard guard;
  final Widget child;

  const PlaybackShortcuts({
    super.key,
    required this.player,
    required this.child,
    this.enabled = true,
    this.guard = unguarded,
  });

  static const Duration seekStep = Duration(seconds: 5);

  /// The volume step of Up and Down, in percent.
  static const double volumeStep = 5;

  /// The speed step of [ and ].
  static const double rateStep = 0.1;

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Holds the focus when nothing else does, so the keys arrive.
      autofocus: true,
      debugLabel: 'PlaybackShortcuts',
      onKeyEvent: (node, event) {
        if (!enabled) return KeyEventResult.ignored;
        if (isShortcutHelpKey(event)) {
          showShortcutHelp(context);
          return KeyEventResult.handled;
        }
        return handlePlaybackKey(
          player,
          event,
          guard: guard,
          notify: feedbackFor(context),
        );
      },
      child: child,
    );
  }
}

/// The keyboard shortcuts, as (keys, action) pairs, in the order the help
/// lists them.
const List<(String, String)> playbackShortcutList = [
  ('Space', 'Play or pause'),
  ('Left, Right', 'Seek 5 s back or forward (hold to repeat)'),
  ('Up, Down', 'Volume up or down'),
  ('M', 'Mute or unmute'),
  ('N', 'Next track'),
  ('P', 'Previous track'),
  ('Page Up', 'Previous chapter'),
  ('Page Down', 'Next chapter'),
  ('L', 'A-B loop: set A, then B, then clear'),
  ('[ and ]', 'Slower or faster'),
  ('Backspace', 'Normal speed'),
  ('? or F1', 'Show these shortcuts'),
];

/// Whether [event] asks for the shortcut help: a press of F1, or of the
/// key that types ?, outside a text field.
bool isShortcutHelpKey(KeyEvent event) {
  if (event is! KeyDownEvent || _focusElsewhere()) return false;
  return event.logicalKey == LogicalKeyboardKey.f1 || event.character == '?';
}

/// Shows the list of keyboard shortcuts in a dialog.
Future<void> showShortcutHelp(BuildContext context) {
  return showStudioDialog<void>(
    context,
    title: 'Keyboard shortcuts',
    maxWidth: 460,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (keys, action) in playbackShortcutList)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 112,
                  child: Text(
                    keys,
                    style: Tokens.numeric.copyWith(color: Tokens.fg),
                  ),
                ),
                Expanded(child: Text(action, style: Tokens.body)),
              ],
            ),
          ),
      ],
    ),
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

/// Applies the [PlaybackShortcuts] binding for [event] to [player]. What
/// the user should know about the result goes to [notify].
KeyEventResult handlePlaybackKey(
  PlayerApi player,
  KeyEvent event, {
  CallGuard guard = unguarded,
  Notify? notify,
}) {
  if (event is KeyUpEvent) return KeyEventResult.ignored;
  if (_focusElsewhere()) return KeyEventResult.ignored;
  final keys = HardwareKeyboard.instance;
  if (keys.isControlPressed ||
      keys.isMetaPressed ||
      keys.isAltPressed ||
      keys.isShiftPressed) {
    return KeyEventResult.ignored;
  }

  final key = event.logicalKey;
  // Seeking and the volume repeat while the key is held.
  final held = switch (key) {
    LogicalKeyboardKey.arrowLeft => () => guard(
      () => player.seek(-PlaybackShortcuts.seekStep, relative: true),
    ),
    LogicalKeyboardKey.arrowRight => () => guard(
      () => player.seek(PlaybackShortcuts.seekStep, relative: true),
    ),
    LogicalKeyboardKey.arrowUp => () => stepVolume(
      player,
      guard,
      PlaybackShortcuts.volumeStep,
    ),
    LogicalKeyboardKey.arrowDown => () => stepVolume(
      player,
      guard,
      -PlaybackShortcuts.volumeStep,
    ),
    _ => null,
  };
  if (held != null) {
    held();
    return KeyEventResult.handled;
  }

  final action = _pressActions[key];
  if (action == null) return KeyEventResult.ignored;
  // The other keys act once per press, not on auto-repeat.
  if (event is! KeyRepeatEvent) action(player, guard, notify);
  return KeyEventResult.handled;
}

typedef _Action =
    void Function(PlayerApi player, CallGuard guard, Notify? notify);

final Map<LogicalKeyboardKey, _Action> _pressActions = {
  LogicalKeyboardKey.space: (p, g, n) => togglePlay(p, g),
  LogicalKeyboardKey.keyM: (p, g, n) => g(() => p.setMute(!p.state.mute)),
  LogicalKeyboardKey.keyN: (p, g, n) =>
      skipTrack(p, g, forward: true, notify: n),
  LogicalKeyboardKey.keyP: (p, g, n) =>
      skipTrack(p, g, forward: false, notify: n),
  LogicalKeyboardKey.pageUp: (p, g, n) => stepChapter(p, g, -1, notify: n),
  LogicalKeyboardKey.pageDown: (p, g, n) => stepChapter(p, g, 1, notify: n),
  LogicalKeyboardKey.keyL: (p, g, n) => cycleAbLoop(p, g, notify: n),
  LogicalKeyboardKey.bracketLeft: (p, g, n) =>
      stepRate(p, g, delta: -PlaybackShortcuts.rateStep, notify: n),
  LogicalKeyboardKey.bracketRight: (p, g, n) =>
      stepRate(p, g, delta: PlaybackShortcuts.rateStep, notify: n),
  LogicalKeyboardKey.backspace: (p, g, n) =>
      stepRate(p, g, reset: true, notify: n),
};

/// Whether the keys belong to something else: a text field has the
/// focus, or the focus is in a menu, dialog or sheet (which use the
/// arrows and Space themselves).
bool _focusElsewhere() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  if (focused.widget is EditableText ||
      focused.findAncestorWidgetOfExactType<EditableText>() != null) {
    return true;
  }
  return ModalRoute.of(focused) is PopupRoute;
}
