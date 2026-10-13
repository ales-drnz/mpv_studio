import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../studio/playback_issues.dart';
import '../ui/layout/layout.dart';
import '../ui/tokens.dart';

/// Desktop keyboard shortcuts for playback, active anywhere in the app:
///
/// * Space: play and pause (on `playWhenReady`)
/// * Left and Right: seek 5 s back and forward (repeats while held)
/// * M: mute, N: next, P: previous
/// * ? or F1: the list of shortcuts ([showShortcutHelp])
///
/// Keys are left alone while a text field has focus, when a modifier is
/// held (so system and app shortcuts keep working; Shift is allowed for
/// the ?) and when [enabled] is false. A focused button still gets its own Space: it handles the key
/// before it bubbles up here. The player calls run through [guard].
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
        return handlePlaybackKey(player, event, guard: guard);
      },
      child: child,
    );
  }
}

/// The keyboard shortcuts, as (keys, action) pairs, in the order the help
/// lists them.
const List<(String, String)> playbackShortcutList = [
  ('Space', 'Play or pause'),
  ('Left', 'Seek 5 s back (hold to repeat)'),
  ('Right', 'Seek 5 s forward (hold to repeat)'),
  ('M', 'Mute or unmute'),
  ('N', 'Next track'),
  ('P', 'Previous track'),
  ('? or F1', 'Show these shortcuts'),
];

/// Whether [event] asks for the shortcut help: a press of F1, or of the
/// key that types ?, outside a text field.
bool isShortcutHelpKey(KeyEvent event) {
  if (event is! KeyDownEvent || _typingInTextField()) return false;
  return event.logicalKey == LogicalKeyboardKey.f1 || event.character == '?';
}

/// Shows the list of keyboard shortcuts in a dialog.
Future<void> showShortcutHelp(BuildContext context) {
  return showStudioDialog<void>(
    context,
    title: 'Keyboard shortcuts',
    maxWidth: 420,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (keys, action) in playbackShortcutList)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Tokens.s6),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
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

/// Applies the [PlaybackShortcuts] binding for [event] to [player].
KeyEventResult handlePlaybackKey(
  PlayerApi player,
  KeyEvent event, {
  CallGuard guard = unguarded,
}) {
  if (event is KeyUpEvent) return KeyEventResult.ignored;
  if (_typingInTextField()) return KeyEventResult.ignored;
  final keys = HardwareKeyboard.instance;
  if (keys.isControlPressed ||
      keys.isMetaPressed ||
      keys.isAltPressed ||
      keys.isShiftPressed) {
    return KeyEventResult.ignored;
  }

  final key = event.logicalKey;
  final repeat = event is KeyRepeatEvent;

  if (key == LogicalKeyboardKey.arrowLeft) {
    guard(() => player.seek(-PlaybackShortcuts.seekStep, relative: true));
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    guard(() => player.seek(PlaybackShortcuts.seekStep, relative: true));
    return KeyEventResult.handled;
  }
  // The other keys act once per press, not on auto-repeat.
  if (repeat) {
    return _bound(key) ? KeyEventResult.handled : KeyEventResult.ignored;
  }
  if (key == LogicalKeyboardKey.space) {
    guard(player.state.playWhenReady ? player.pause : player.play);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyM) {
    guard(() => player.setMute(!player.state.mute));
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyN) {
    guard(player.next);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyP) {
    guard(player.previous);
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

bool _bound(LogicalKeyboardKey key) =>
    key == LogicalKeyboardKey.space ||
    key == LogicalKeyboardKey.keyM ||
    key == LogicalKeyboardKey.keyN ||
    key == LogicalKeyboardKey.keyP;

/// Whether the focused widget is (inside) an editable text field.
bool _typingInTextField() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  if (focused.widget is EditableText) return true;
  return focused.findAncestorWidgetOfExactType<EditableText>() != null;
}
