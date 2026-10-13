import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Desktop keyboard shortcuts for playback, active anywhere in the app:
///
/// * Space: play and pause (on `playWhenReady`)
/// * Left and Right: seek 5 s back and forward (repeats while held)
/// * M: mute, N: next, P: previous
///
/// Keys are left alone while a text field has focus, when a modifier is
/// held (so system and app shortcuts keep working) and when [enabled] is
/// false. A focused button still gets its own Space: it handles the key
/// before it bubbles up here.
class PlaybackShortcuts extends StatelessWidget {
  final PlayerApi player;
  final bool enabled;
  final Widget child;

  const PlaybackShortcuts({
    super.key,
    required this.player,
    required this.child,
    this.enabled = true,
  });

  static const Duration seekStep = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    return Focus(
      // Holds the focus when nothing else does, so the keys arrive.
      autofocus: true,
      debugLabel: 'PlaybackShortcuts',
      onKeyEvent: (node, event) =>
          enabled ? handlePlaybackKey(player, event) : KeyEventResult.ignored,
      child: child,
    );
  }
}

/// Applies the [PlaybackShortcuts] binding for [event] to [player].
KeyEventResult handlePlaybackKey(PlayerApi player, KeyEvent event) {
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
    player.seek(-PlaybackShortcuts.seekStep, relative: true);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    player.seek(PlaybackShortcuts.seekStep, relative: true);
    return KeyEventResult.handled;
  }
  // The other keys act once per press, not on auto-repeat.
  if (repeat) {
    return _bound(key) ? KeyEventResult.handled : KeyEventResult.ignored;
  }
  if (key == LogicalKeyboardKey.space) {
    player.state.playWhenReady ? player.pause() : player.play();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyM) {
    player.setMute(!player.state.mute);
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyN) {
    player.next();
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyP) {
    player.previous();
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
