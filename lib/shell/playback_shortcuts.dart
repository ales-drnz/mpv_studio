import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../features/now_playing/transport_actions.dart';
import '../features/effects/rack_controller.dart';
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
/// The speed keys match the character the key types, so [ and ] work on
/// layouts that reach them with AltGr or Option (Italian, German), and
/// - and + (or =) do the same for layouts with no brackets at hand; the
/// modifiers that type those characters are allowed there.
/// Space goes to a focused button, switch or other control that
/// activates (it has an enabled `ActivateIntent`), and plays or pauses
/// only otherwise. The player calls run through [guard]; what the
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
    this.rack,
  });

  /// The effects rack B bypasses; no B without.
  final RackController? rack;

  static const Duration seekStep = Duration(seconds: 5);

  /// The volume step of Up and Down, in percent.
  static const double volumeStep = 5;

  /// The speed step of [ and ] (also - and +).
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
          rack: rack,
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
  ('Shift+Page Up', 'Previous chapter (Page Up where nothing scrolls)'),
  ('Shift+Page Down', 'Next chapter (Page Down where nothing scrolls)'),
  ('L', 'A-B loop: set A, then B, then clear'),
  ('[ and ]', 'Slower or faster'),
  ('- and +', 'Also slower or faster (= too)'),
  ('Backspace', 'Normal speed'),
  ('B', 'Bypass the effects, or play them again'),
  ('? or F1', 'Show these shortcuts'),
];

/// How the help names the section keys: a browser keeps Ctrl+1 to 8 for
/// its own tabs, so there they work in the installed app only.
String sectionKeysLabel({bool web = kIsWeb}) =>
    web ? 'Ctrl+1 to 7 (in the app, not a browser)' : 'Ctrl+1 to 7';

/// The keys of the shell and the pages, by where they work, as the help
/// lists them after [playbackShortcutList].
final List<(String, List<(String, String)>)> pageShortcutList = [
  (
    'Anywhere',
    [
      (
        sectionKeysLabel(),
        'Go to Playback, Queue, Stream, Effects, Engine, Settings or Console',
      ),
      ('Escape', 'Close a detail, a menu or a dialog'),
      ('Menu, Shift+F10', 'The menu of the focused row'),
    ],
  ),
  (
    'Queue',
    [
      ('Enter', 'Play the selected track'),
      ('Delete', 'Remove it (with Undo)'),
      ('Alt+Up, Alt+Down', 'Move it one place'),
      ('Home, End', 'Select the first or the last'),
    ],
  ),
  (
    'Effects',
    [
      ('Alt+Up, Alt+Down', 'Move the focused stage'),
      ('Delete', 'Remove it (with Undo)'),
    ],
  ),
  ('Settings', [('Ctrl+F', 'Search the settings')]),
  (
    'Console',
    [
      ('Up, Down', 'Earlier commands'),
      ('Tab, Ctrl+Space', 'Complete, or list the commands'),
      ('Ctrl+L', 'Clear the log'),
    ],
  ),
  ('Sliders', [('Shift with an arrow', 'A finer step')]),
];

/// Whether [event] asks for the shortcut help: a press of F1, or of the
/// key that types ?, outside a text field.
bool isShortcutHelpKey(KeyEvent event) {
  if (event is! KeyDownEvent || _focusElsewhere()) return false;
  return event.logicalKey == LogicalKeyboardKey.f1 || event.character == '?';
}

/// Shows the list of keyboard shortcuts in a dialog.
Future<void> showShortcutHelp(BuildContext context) {
  Widget row((String, String) entry) => Padding(
    padding: const EdgeInsets.symmetric(vertical: Tokens.s8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 128,
          child: Text(
            entry.$1,
            style: Tokens.numeric.copyWith(color: Tokens.fg),
          ),
        ),
        Expanded(child: Text(entry.$2, style: Tokens.body)),
      ],
    ),
  );
  return showStudioDialog<void>(
    context,
    title: 'Keyboard shortcuts',
    maxWidth: 520,
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in playbackShortcutList) row(entry),
        for (final (where, entries) in pageShortcutList) ...[
          Padding(
            padding: const EdgeInsets.only(top: Tokens.s16, bottom: Tokens.s4),
            child: Semantics(
              header: true,
              child: Text(where, style: Tokens.label),
            ),
          ),
          for (final entry in entries) row(entry),
        ],
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
  RackController? rack,
}) {
  if (event is KeyUpEvent) return KeyEventResult.ignored;
  if (_focusElsewhere()) return KeyEventResult.ignored;
  final keys = HardwareKeyboard.instance;

  // The speed keys go by the character typed, before the modifier check:
  // AltGr (Ctrl and Alt on Windows), Option or Shift may be what types it.
  final rate = _rateDelta(event);
  if (rate != null) {
    final typedWith =
        !keys.isMetaPressed && (!keys.isControlPressed || keys.isAltPressed);
    if (!typedWith) return KeyEventResult.ignored;
    if (event is! KeyRepeatEvent) {
      stepRate(player, guard, delta: rate, notify: notify);
    }
    return KeyEventResult.handled;
  }
  final key = event.logicalKey;
  final page = switch (key) {
    LogicalKeyboardKey.pageUp => -1,
    LogicalKeyboardKey.pageDown => 1,
    _ => 0,
  };
  // The chapters: Shift+Page Up and Down anywhere; Page Up and Down only
  // where they would not scroll anything.
  if (page != 0 &&
      !keys.isControlPressed &&
      !keys.isMetaPressed &&
      !keys.isAltPressed &&
      (keys.isShiftPressed || !_focusScrolls())) {
    if (event is! KeyRepeatEvent) {
      stepChapter(player, guard, page, notify: notify);
    }
    return KeyEventResult.handled;
  }
  if (keys.isControlPressed ||
      keys.isMetaPressed ||
      keys.isAltPressed ||
      keys.isShiftPressed) {
    return KeyEventResult.ignored;
  }

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

  if (key == LogicalKeyboardKey.keyB && rack != null) {
    if (event is! KeyRepeatEvent && rack.canBypass) {
      final on = !rack.bypass;
      rack.setBypass(on);
      notify?.call(on ? 'Effects bypassed' : 'Effects on');
    }
    return KeyEventResult.handled;
  }
  final action = _pressActions[key];
  if (action == null) return KeyEventResult.ignored;
  // The app's Shortcuts map Space to ActivateIntent above this handler,
  // so a focused control would never see it: leave it to the control.
  if (key == LogicalKeyboardKey.space && _focusActivates()) {
    return KeyEventResult.ignored;
  }
  // The other keys act once per press, not on auto-repeat.
  if (event is! KeyRepeatEvent) action(player, guard, notify);
  return KeyEventResult.handled;
}

typedef _Action =
    void Function(PlayerApi player, CallGuard guard, Notify? notify);

final Map<LogicalKeyboardKey, _Action> _pressActions = {
  LogicalKeyboardKey.space: (p, g, n) {
    // The play button says it on screen; a screen reader hears it, once
    // the player took it.
    final playing = !p.state.playWhenReady;
    togglePlay(p, g).then((_) {
      if (p.state.playWhenReady == playing) {
        _announce(playing ? 'Playing' : 'Paused');
      }
    });
  },
  LogicalKeyboardKey.keyM: (p, g, n) {
    final mute = !p.state.mute;
    _announce(mute ? 'Muted' : 'Sound on');
    g(() => p.setMute(mute));
  },
  LogicalKeyboardKey.keyN: (p, g, n) =>
      skipTrack(p, g, forward: true, notify: n),
  LogicalKeyboardKey.keyP: (p, g, n) =>
      skipTrack(p, g, forward: false, notify: n),
  LogicalKeyboardKey.keyL: (p, g, n) => cycleAbLoop(p, g, notify: n),
  LogicalKeyboardKey.backspace: (p, g, n) =>
      stepRate(p, g, reset: true, notify: n),
};

/// The speed step [event] asks for, or `null`. The character typed
/// decides when there is one: the key that types [ on one layout types
/// something else on another, and Shift with [ types {. Without a
/// character, the logical key does.
double? _rateDelta(KeyEvent event) {
  const step = PlaybackShortcuts.rateStep;
  final c = event.character;
  if (c != null && c.isNotEmpty) {
    return switch (c) {
      '[' || '-' => -step,
      ']' || '+' || '=' => step,
      _ => null,
    };
  }
  return switch (event.logicalKey) {
    LogicalKeyboardKey.bracketLeft ||
    LogicalKeyboardKey.minus ||
    LogicalKeyboardKey.numpadSubtract => -step,
    LogicalKeyboardKey.bracketRight ||
    LogicalKeyboardKey.equal ||
    LogicalKeyboardKey.add ||
    LogicalKeyboardKey.numpadAdd => step,
    _ => null,
  };
}

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

/// Says [message] to a screen reader.
void _announce(String message) {
  final view = WidgetsBinding.instance.platformDispatcher.implicitView;
  if (view == null) return;
  SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
}

/// Whether the focus is inside something Page Up and Down scroll.
bool _focusScrolls() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  // Page Up and Down scroll up and down: a sideways list is not theirs.
  final scrollable = Scrollable.maybeOf(focused, axis: Axis.vertical);
  return scrollable != null &&
      scrollable.position.maxScrollExtent > scrollable.position.minScrollExtent;
}

/// Whether the focused widget is a control that Space activates.
bool _focusActivates() {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  const intent = ActivateIntent();
  final action = Actions.maybeFind<ActivateIntent>(focused, intent: intent);
  return action != null && action.isEnabled(intent);
}
