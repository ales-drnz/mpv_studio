import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';
import '../../../studio/app_settings.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/section_body.dart';
import '../../../ui/widgets/section_header.dart';

/// The Session settings page: customise which controls MPV Studio advertises
/// to the OS media session (lock screen / Control Center / SMTC / MPRIS /
/// Bluetooth). The shown set is reorderable by drag; actions are added /
/// removed with chips; the skip-interval actions carry their own interval
/// slider inline. How many controls actually appear and where is up to each
/// OS — we only advertise the capability set.
class SessionGroup extends StatefulWidget {
  final Player player;
  final AppSettings settings;
  const SessionGroup(this.player, this.settings, {super.key});

  @override
  State<SessionGroup> createState() => _SessionGroupState();
}

class _SessionGroupState extends State<SessionGroup> {
  Player get player => widget.player;
  AppSettings get settings => widget.settings;

  late bool _on = settings.sessionOn;
  late List<MediaAction> _shown = settings.sessionActions;
  late int _ffSecs = settings.sessionFastForwardSecs;
  late int _rwSecs = settings.sessionRewindSecs;
  late InterruptionPolicy _interruption = settings.sessionInterruption;

  // Actions the running OS's native media UI won't render (dimmed below).
  final Set<MediaAction> _unsupported = _unsupportedForPlatform();
  final String _platform = _currentPlatformLabel();

  // Interruption handling is a real audio-session behaviour only on mobile.
  static final bool _interruptionSupported =
      Platform.isIOS || Platform.isAndroid;

  /// Advertised actions the running OS actually renders — the only ones in the
  /// reorderable "Shown controls" list (advertised order preserved).
  List<MediaAction> get _shownSupported => [
    for (final a in _shown)
      if (!_unsupported.contains(a)) a,
  ];

  /// Not-yet-advertised actions the OS renders — the "More actions" pool.
  List<MediaAction> get _availableSupported => [
    for (final a in MediaAction.values)
      if (!_shown.contains(a) && !_unsupported.contains(a)) a,
  ];

  /// Every action the OS won't render here, advertised or not — grouped on its
  /// own (toggling one just adds/removes it from the advertised set).
  List<MediaAction> get _allUnsupported => [
    for (final a in MediaAction.values)
      if (_unsupported.contains(a)) a,
  ];

  /// Push the current selection to the live player and persist it.
  void _apply() {
    unawaited(
      player.setMediaSession(
        _on
            ? settings.composeMediaSession(
                _shown,
                fastForwardSecs: _ffSecs,
                rewindSecs: _rwSecs,
                interruptionPolicy: _interruption,
              )
            : null,
      ),
    );
    settings.recordSessionOn(_on);
    settings.recordSessionActions(_shown);
    settings.recordSessionFastForward(_ffSecs);
    settings.recordSessionRewind(_rwSecs);
    settings.recordSessionInterruption(_interruption);
  }

  void _setOn(bool v) {
    setState(() => _on = v);
    _apply();
  }

  void _enable(MediaAction a) {
    setState(() => _shown = [..._shown, a]);
    _apply();
  }

  void _disable(MediaAction a) {
    setState(() => _shown = [..._shown]..remove(a));
    _apply();
  }

  void _toggle(MediaAction a) => _shown.contains(a) ? _disable(a) : _enable(a);

  // The reorderable list shows only [_shownSupported], so its indices are into
  // that subset. Reorder them, then rebuild [_shown] as the reordered supported
  // actions followed by the (un-rendered, order-irrelevant) unsupported ones.
  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final sup = _shownSupported;
      sup.insert(newIndex, sup.removeAt(oldIndex));
      _shown = [
        ...sup,
        for (final a in _shown)
          if (_unsupported.contains(a)) a,
      ];
    });
    _apply();
  }

  void _setFf(int secs) {
    setState(() => _ffSecs = secs);
    _apply();
  }

  void _setRw(int secs) {
    setState(() => _rwSecs = secs);
    _apply();
  }

  void _setInterruption(InterruptionPolicy p) {
    setState(() => _interruption = p);
    _apply();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsGroup(
          label: 'Media session',
          children: [
            SwitchRow(
              label: 'Publish to the OS',
              subtitle:
                  'Lock screen, Control Center, Bluetooth, headset and MPRIS',
              value: _on,
              onChanged: _setOn,
            ),
          ],
        ),
        // Editing the set while the session is off is meaningless — dim it.
        Opacity(
          opacity: _on ? 1 : 0.4,
          child: IgnorePointer(
            ignoring: !_on,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Interruption sits directly under "Publish to the OS".
                SettingsGroup(
                  label: 'Interruption',
                  children: [
                    SettingTile(
                      title: 'When interrupted',
                      description: _interruptionSupported
                          ? 'How playback reacts to a call, Siri or an alarm'
                          : 'Only on iOS and Android. $_platform leaves audio '
                                'routing to the OS',
                      below: AppDropdown<InterruptionPolicy>(
                        enabled: _interruptionSupported,
                        value: _interruption,
                        items: const [
                          DropdownMenuItem(
                            value: InterruptionPolicy.pauseAndResume,
                            child: Text('Pause and resume'),
                          ),
                          DropdownMenuItem(
                            value: InterruptionPolicy.pauseOnly,
                            child: Text('Pause only'),
                          ),
                          DropdownMenuItem(
                            value: InterruptionPolicy.keepPlaying,
                            child: Text('Keep playing'),
                          ),
                        ],
                        onChanged: (p) {
                          if (p != null) _setInterruption(p);
                        },
                      ),
                    ),
                  ],
                ),
                const SectionHeader('Shown controls'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Tokens.s4,
                    0,
                    Tokens.s4,
                    Tokens.s12,
                  ),
                  child: Text(
                    'Capabilities advertised to the system. Drag to reorder; '
                    'each OS decides how many to show and where.',
                    style: Tokens.caption,
                  ),
                ),
                _shownList(),
                if (_availableSupported.isNotEmpty) ...[
                  const SizedBox(height: Tokens.s16),
                  const SectionHeader('More actions'),
                  Wrap(
                    spacing: Tokens.s8,
                    runSpacing: Tokens.s8,
                    children: [
                      for (final a in _availableSupported)
                        _AddChip(
                          action: a,
                          onTap: () => _enable(a),
                          unsupported: false,
                          platform: _platform,
                        ),
                    ],
                  ),
                ],
                if (_allUnsupported.isNotEmpty) ...[
                  const SizedBox(height: Tokens.s16),
                  SectionHeader("Not shown on $_platform"),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Tokens.s4,
                      0,
                      Tokens.s4,
                      Tokens.s12,
                    ),
                    child: Text(
                      "$_platform's media UI won't draw these, but you can still "
                      'advertise them anyway; they may appear on your other '
                      'devices. Tap to toggle.',
                      style: Tokens.caption,
                    ),
                  ),
                  Wrap(
                    spacing: Tokens.s8,
                    runSpacing: Tokens.s8,
                    children: [
                      for (final a in _allUnsupported)
                        _AddChip(
                          action: a,
                          onTap: () => _toggle(a),
                          unsupported: true,
                          advertised: _shown.contains(a),
                          platform: _platform,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shownList() {
    final shown = _shownSupported;
    if (shown.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: Tokens.s20),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: Tokens.surface,
          shape: Tokens.squircle(Tokens.rMd),
        ),
        child: const Text(
          'No controls yet. Add some below.',
          style: Tokens.caption,
        ),
      );
    }
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      padding: EdgeInsets.zero,
      onReorderItem: _reorder,
      children: [
        for (var i = 0; i < shown.length; i++)
          _ShownTile(
            key: ValueKey(shown[i]),
            index: i,
            action: shown[i],
            onRemove: () => _disable(shown[i]),
            intervalSecs: switch (shown[i]) {
              MediaAction.fastForward => _ffSecs,
              MediaAction.rewind => _rwSecs,
              _ => null,
            },
            onInterval: switch (shown[i]) {
              MediaAction.fastForward => _setFf,
              MediaAction.rewind => _setRw,
              _ => null,
            },
          ),
      ],
    );
  }
}

/// Actions the running platform's native media UI will NOT render as a usable
/// control, so the Session page dims them. From the verified per-OS support
/// matrix (official docs + on-device checks). The advertised set is shared
/// across devices, so an action dimmed here may still render on another OS.
/// 'partial' actions that render on at least one common desktop (e.g. Linux
/// KDE seek/repeat/shuffle/rate) are treated as supported and left enabled.
Set<MediaAction> _unsupportedForPlatform() {
  if (Platform.isMacOS) {
    return const {
      MediaAction.stop,
      MediaAction.setRepeatMode,
      MediaAction.setShuffle,
      MediaAction.setPlaybackRate,
      MediaAction.like,
    };
  }
  if (Platform.isIOS) {
    // like DOES render on the iOS lock screen (confirmed on-device).
    return const {
      MediaAction.stop,
      MediaAction.setRepeatMode,
      MediaAction.setShuffle,
      MediaAction.setPlaybackRate,
    };
  }
  if (Platform.isAndroid) {
    // On top of Media3's play-pause / prev-next / seek bar the plugin ships
    // custom notification buttons for the skip intervals, repeat, shuffle and
    // the favourite heart. Only stop and the rate picker have no rendered
    // control.
    return const {MediaAction.stop, MediaAction.setPlaybackRate};
  }
  if (Platform.isWindows) {
    // SMTC draws transport + seek; repeat/shuffle are properties the native
    // flyout does not render as toggles, and there's no rate or like button.
    return const {
      MediaAction.setRepeatMode,
      MediaAction.setShuffle,
      MediaAction.setPlaybackRate,
      MediaAction.like,
    };
  }
  if (Platform.isLinux) {
    // MPRIS: no stop / skip-interval / like control. seek, repeat, shuffle and
    // rate render on KDE Plasma (not GNOME's built-in popup) — left enabled.
    return const {
      MediaAction.stop,
      MediaAction.fastForward,
      MediaAction.rewind,
      MediaAction.like,
    };
  }
  return const {};
}

String _currentPlatformLabel() {
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isLinux) return 'Linux';
  return 'this platform';
}

/// Skip-interval values (seconds) that Apple's media controls can actually
/// render — the OS only ships `goforward.N` / `gobackward.N` glyphs for these,
/// so an in-between value (e.g. 20s) leaves the button with no icon and it
/// won't show. The slider snaps to these instead of a free range.
const _skipIntervals = <int>[10, 15, 30, 45, 60];

/// Index of the supported interval nearest to [secs].
int _nearestSkipIndex(int secs) {
  var best = 0;
  for (var i = 1; i < _skipIntervals.length; i++) {
    if ((_skipIntervals[i] - secs).abs() <
        (_skipIntervals[best] - secs).abs()) {
      best = i;
    }
  }
  return best;
}

/// Icon + label for a [MediaAction] as shown in the editor.
({IconData icon, String label}) _meta(MediaAction a) => switch (a) {
  MediaAction.play => (icon: Icons.play_arrow_rounded, label: 'Play'),
  MediaAction.pause => (icon: Icons.pause_rounded, label: 'Pause'),
  MediaAction.playPause => (
    icon: Icons.play_circle_outline_rounded,
    label: 'Play-pause',
  ),
  MediaAction.stop => (icon: Icons.stop_rounded, label: 'Stop'),
  MediaAction.next => (icon: Icons.skip_next_rounded, label: 'Next'),
  MediaAction.previous => (
    icon: Icons.skip_previous_rounded,
    label: 'Previous',
  ),
  MediaAction.seek => (icon: Icons.linear_scale_rounded, label: 'Scrubber'),
  MediaAction.fastForward => (
    icon: Icons.fast_forward_rounded,
    label: 'Skip forward',
  ),
  MediaAction.rewind => (icon: Icons.fast_rewind_rounded, label: 'Skip back'),
  MediaAction.setRepeatMode => (icon: Icons.repeat_rounded, label: 'Repeat'),
  MediaAction.setShuffle => (icon: Icons.shuffle_rounded, label: 'Shuffle'),
  MediaAction.setPlaybackRate => (
    icon: Icons.speed_rounded,
    label: 'Playback speed',
  ),
  MediaAction.like => (icon: Icons.star_rounded, label: 'Favorite'),
};

/// One draggable row in the "Shown controls" list. For the skip-interval
/// actions it carries an inline interval slider beneath the row.
class _ShownTile extends StatelessWidget {
  final int index;
  final MediaAction action;
  final VoidCallback onRemove;
  final int? intervalSecs;
  final ValueChanged<int>? onInterval;
  const _ShownTile({
    super.key,
    required this.index,
    required this.action,
    required this.onRemove,
    this.intervalSecs,
    this.onInterval,
  });

  @override
  Widget build(BuildContext context) {
    final m = _meta(action);
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s8),
      child: Container(
        decoration: ShapeDecoration(
          color: Tokens.surface2,
          shape: Tokens.squircle(Tokens.rSm),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(Tokens.s12),
                    child: Icon(
                      Icons.drag_indicator_rounded,
                      size: 18,
                      color: Tokens.fgFaint,
                    ),
                  ),
                ),
                Icon(m.icon, size: 18, color: Tokens.accent),
                const SizedBox(width: Tokens.s12),
                Expanded(child: Text(m.label, style: Tokens.body)),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 18,
                  ),
                  color: Tokens.fgDim,
                  splashRadius: 18,
                  tooltip: 'Remove',
                ),
              ],
            ),
            if (intervalSecs != null && onInterval != null)
              Builder(
                builder: (context) {
                  // Snap to the OS-renderable values: the slider scrubs an index
                  // into [_skipIntervals], not a free second count.
                  final idx = _nearestSkipIndex(intervalSecs!);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Tokens.s12,
                      0,
                      Tokens.s12,
                      Tokens.s8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppSlider(
                            value: idx.toDouble(),
                            min: 0,
                            max: (_skipIntervals.length - 1).toDouble(),
                            divisions: _skipIntervals.length - 1,
                            onChanged: (v) =>
                                onInterval!(_skipIntervals[v.round()]),
                          ),
                        ),
                        const SizedBox(width: Tokens.s12),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '${_skipIntervals[idx]}s',
                            textAlign: TextAlign.end,
                            style: Tokens.numeric.copyWith(
                              color: Tokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// A tappable action chip. In "More actions" it enables a supported action; in
/// "Not shown on $platform" it toggles an unsupported action's advertised state
/// ([advertised] — a filled chip with a check when on).
class _AddChip extends StatelessWidget {
  final MediaAction action;
  final VoidCallback onTap;
  final bool unsupported;
  final bool advertised;
  final String platform;
  const _AddChip({
    required this.action,
    required this.onTap,
    required this.unsupported,
    required this.platform,
    this.advertised = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = _meta(action);
    final dim = unsupported && !advertised;
    final chip = Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: Tokens.squircle(Tokens.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: Tokens.s8,
          ),
          decoration: ShapeDecoration(
            color: advertised ? Tokens.surface3 : Tokens.surface2,
            shape: Tokens.squircle(Tokens.rSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                m.icon,
                size: 16,
                color: dim ? Tokens.fgFaint : Tokens.fgDim,
              ),
              const SizedBox(width: Tokens.s8),
              Text(
                m.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: dim ? Tokens.fgFaint : Tokens.fg,
                ),
              ),
              const SizedBox(width: Tokens.s8),
              Icon(
                advertised
                    ? Icons.check_rounded
                    : (unsupported ? Icons.block_rounded : Icons.add_rounded),
                size: 16,
                color: dim ? Tokens.fgFaint : Tokens.accent,
              ),
            ],
          ),
        ),
      ),
    );
    if (!unsupported) return chip;
    return Tooltip(
      message: advertised
          ? "Advertised but won't render on $platform; tap to remove"
          : "Not drawn by $platform's media controls; tap to advertise anyway",
      child: chip,
    );
  }
}
