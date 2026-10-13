import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// Watches mpv's file lifecycle hooks for the Console `hooks` command:
/// registers every [Hook], reports each event and lets mpv continue at
/// once.
///
/// mpv cannot unregister a hook, so once started the monitor keeps
/// continuing them for the player's lifetime; `hooks off` only stops the
/// reports. A [timeout] still bounds the wait should a continue get lost.
/// One monitor per player, see [of].
class HookMonitor {
  HookMonitor._(this._player);

  static final _monitors = Expando<HookMonitor>('hook monitor');

  /// The monitor of [player].
  static HookMonitor of(PlayerApi player) =>
      _monitors[player] ??= HookMonitor._(player);

  static const timeout = Duration(seconds: 2);

  final PlayerApi _player;
  StreamSubscription<MpvHookEvent>? _sub;
  final _events = StreamController<MpvHookEvent>.broadcast();

  /// Whether events are being reported.
  bool get reporting => _reporting;
  bool _reporting = false;

  /// Each hook event while [reporting].
  Stream<MpvHookEvent> get events => _events.stream;

  /// Registers the hooks (once) and starts reporting.
  Future<void> start() async {
    _reporting = true;
    if (_sub != null) return;
    _sub = _player.stream.hook.listen(_onHook);
    for (final hook in Hook.values) {
      await _player.registerHook(hook, timeout: timeout);
    }
  }

  /// Stops reporting; the hooks keep being continued.
  void stop() => _reporting = false;

  Future<void> _onHook(MpvHookEvent event) async {
    if (_reporting) _events.add(event);
    try {
      await _player.continueHook(event.id);
    } on PlayerException {
      // The hook times out on mpv's side; nothing else to do.
    }
  }
}
