import 'dart:async';

import 'package:mpv_audio_kit/mpv_audio_kit.dart';

/// One hook the [HookMonitor] saw.
class HookReport {
  const HookReport(this.event, {required this.continued});

  final MpvHookEvent event;

  /// Whether the continue reached mpv; false when it failed and mpv waits
  /// for its own timeout.
  final bool continued;
}

/// Watches mpv's file lifecycle hooks for the Console `hooks` command:
/// registers every [Hook], lets mpv continue each event at once and then
/// reports it.
///
/// mpv cannot unregister a hook, so once started the monitor keeps
/// continuing them for the player's lifetime; `hooks off` only stops the
/// reports. One monitor per player, see [of].
///
/// The library keeps one timeout per hook name, shared with the source
/// resolver, which runs inside `on_load` and `on_load_fail` before the
/// event reaches the monitor. Those two are registered without a timeout
/// so the resolver's own (15 s by default) stays in force; the others get
/// [timeout] as a safety net should a continue get lost.
class HookMonitor {
  HookMonitor._(this._player);

  static final _monitors = Expando<HookMonitor>('hook monitor');

  /// The monitor of [player].
  static HookMonitor of(PlayerApi player) =>
      _monitors[player] ??= HookMonitor._(player);

  static const timeout = Duration(seconds: 2);

  /// The hooks the source resolver also runs in.
  static const resolverHooks = {Hook.load, Hook.loadFail};

  final PlayerApi _player;
  StreamSubscription<MpvHookEvent>? _sub;
  final _reports = StreamController<HookReport>.broadcast();
  final _registered = <Hook>{};

  /// Whether events are being reported.
  bool get reporting => _reporting;
  bool _reporting = false;

  /// The hooks registered so far.
  Set<Hook> get registered => Set.unmodifiable(_registered);

  /// Each hook event while [reporting], once it has been continued.
  Stream<HookReport> get reports => _reports.stream;

  /// Registers the hooks not registered yet and starts reporting when at
  /// least one is. Returns the hooks that could not be registered.
  Future<List<Hook>> start() async {
    _sub ??= _player.stream.hook.listen(_onHook);
    final failed = <Hook>[];
    for (final hook in Hook.values) {
      if (_registered.contains(hook)) continue;
      try {
        await _player.registerHook(
          hook,
          timeout: resolverHooks.contains(hook) ? null : timeout,
        );
        _registered.add(hook);
      } on PlayerException {
        failed.add(hook);
      }
    }
    _reporting = _registered.isNotEmpty;
    return failed;
  }

  /// Stops reporting; the hooks keep being continued.
  void stop() => _reporting = false;

  Future<void> _onHook(MpvHookEvent event) async {
    var continued = true;
    try {
      await _player.continueHook(event.id);
    } on PlayerException {
      continued = false;
    }
    if (_reporting) _reports.add(HookReport(event, continued: continued));
  }
}
