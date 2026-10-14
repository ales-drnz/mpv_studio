import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/round_icon_button.dart';

/// Actions the running platform's native media UI will NOT render as a usable
/// control, so the Session settings dim them. From the verified per-OS
/// support matrix (official docs and on-device checks). The advertised set is
/// shared across devices, so an action dimmed here may still render on
/// another OS. Partly supported actions that render on at least one common
/// desktop (Linux KDE seek, repeat, shuffle and rate) are treated as
/// supported and left enabled.
Set<MediaAction> unsupportedSessionActions() {
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
    // On top of Media3's play-pause, previous, next and seek bar the plugin
    // ships custom notification buttons for the skip intervals, repeat,
    // shuffle and the favourite heart. Only stop and the rate picker have no
    // rendered control.
    return const {MediaAction.stop, MediaAction.setPlaybackRate};
  }
  if (Platform.isWindows) {
    // SMTC draws transport and seek; repeat and shuffle are properties the
    // native flyout does not render as toggles, and there's no rate or like
    // button.
    return const {
      MediaAction.setRepeatMode,
      MediaAction.setShuffle,
      MediaAction.setPlaybackRate,
      MediaAction.like,
    };
  }
  if (Platform.isLinux) {
    // MPRIS: no stop, skip-interval or like control. Seek, repeat, shuffle
    // and rate render on KDE Plasma (not GNOME's built-in popup), so they
    // are left enabled.
    return const {
      MediaAction.stop,
      MediaAction.fastForward,
      MediaAction.rewind,
      MediaAction.like,
    };
  }
  return const {};
}

/// The running platform's name, for the Session settings' captions.
String sessionPlatformLabel() {
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isLinux) return 'Linux';
  return 'this platform';
}

/// Skip-interval values (seconds) that Apple's media controls can actually
/// render: the OS only ships `goforward.N` and `gobackward.N` glyphs for
/// these, so an in-between value (20 s, say) leaves the button with no icon
/// and it won't show. The slider snaps to these instead of a free range.
const skipIntervals = <int>[10, 15, 30, 45, 60];

/// Index of the supported interval nearest to [secs].
int nearestSkipIndex(int secs) {
  var best = 0;
  for (var i = 1; i < skipIntervals.length; i++) {
    if ((skipIntervals[i] - secs).abs() < (skipIntervals[best] - secs).abs()) {
      best = i;
    }
  }
  return best;
}

/// Icon and label of a [MediaAction] as the editor shows it.
({IconData icon, String label}) sessionActionMeta(MediaAction a) => switch (a) {
  MediaAction.play => (icon: Icons.play_arrow_rounded, label: 'Play'),
  MediaAction.pause => (icon: Icons.pause_rounded, label: 'Pause'),
  MediaAction.playPause => (
    icon: Icons.play_circle_outline_rounded,
    label: 'Play and pause',
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

/// One draggable row in the "Shown controls" list. The skip-interval
/// actions carry an interval slider beneath the row.
class ShownActionTile extends StatelessWidget {
  final int index;
  final MediaAction action;
  final VoidCallback onRemove;
  final int? intervalSecs;
  final ValueChanged<int>? onInterval;
  const ShownActionTile({
    super.key,
    required this.index,
    required this.action,
    required this.onRemove,
    this.intervalSecs,
    this.onInterval,
  });

  @override
  Widget build(BuildContext context) {
    final m = sessionActionMeta(action);
    final tap = context.layout.minTap;
    final interval = intervalSecs;
    final onInterval = this.onInterval;
    return Padding(
      padding: const EdgeInsets.only(bottom: Tokens.s8),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Tokens.surface3,
          shape: Tokens.shape(Tokens.rMd),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: 'Drag to reorder',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: SizedBox.square(
                        dimension: tap,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 18,
                          color: Tokens.fgFaint,
                        ),
                      ),
                    ),
                  ),
                ),
                Icon(m.icon, size: 18, color: Tokens.accent),
                const SizedBox(width: Tokens.s12),
                Expanded(child: Text(m.label, style: Tokens.body)),
                RoundIconButton(
                  icon: Icons.remove_circle_outline_rounded,
                  size: 20,
                  color: Tokens.fgDim,
                  tooltip: 'Remove ${m.label}',
                  onTap: onRemove,
                ),
              ],
            ),
            if (interval != null && onInterval != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.s12,
                  0,
                  Tokens.s12,
                  Tokens.s8,
                ),
                child: Row(
                  children: [
                    // Snaps to the OS-renderable values: the slider scrubs
                    // an index into [skipIntervals], not a free count.
                    Expanded(
                      child: AppSlider(
                        value: nearestSkipIndex(interval).toDouble(),
                        min: 0,
                        max: (skipIntervals.length - 1).toDouble(),
                        divisions: skipIntervals.length - 1,
                        semanticLabel: '${m.label} interval',
                        semanticValue: (v) =>
                            '${skipIntervals[v.round()]} seconds',
                        onChanged: (v) => onInterval(skipIntervals[v.round()]),
                      ),
                    ),
                    const SizedBox(width: Tokens.s12),
                    Text(
                      '${skipIntervals[nearestSkipIndex(interval)]} s',
                      textAlign: TextAlign.end,
                      style: Tokens.numeric.copyWith(color: Tokens.accent),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A tappable action chip. In "More actions" it adds a supported action; in
/// "Not shown on" it toggles an unsupported action's advertised state
/// ([advertised]: a filled chip with a check when on).
class SessionActionChip extends StatelessWidget {
  final MediaAction action;
  final VoidCallback onTap;
  final bool unsupported;
  final bool advertised;
  final String platform;
  const SessionActionChip({
    super.key,
    required this.action,
    required this.onTap,
    required this.unsupported,
    required this.platform,
    this.advertised = false,
  });

  @override
  Widget build(BuildContext context) {
    final m = sessionActionMeta(action);
    final dim = unsupported && !advertised;
    final tip = !unsupported
        ? 'Add ${m.label}'
        : advertised
        ? "Advertised but not drawn on $platform; tap to remove"
        : "Not drawn by $platform's media controls; tap to advertise anyway";
    return Tooltip(
      message: tip,
      child: Semantics(
        button: true,
        toggled: unsupported ? advertised : null,
        label: m.label,
        hint: tip,
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: Tokens.pill,
            child: Ink(
              height: context.layout.minTap,
              padding: const EdgeInsets.fromLTRB(Tokens.s12, 0, Tokens.s16, 0),
              decoration: ShapeDecoration(
                color: advertised ? Tokens.accent : Tokens.surface3,
                shape: Tokens.pill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    m.icon,
                    size: 16,
                    color: advertised
                        ? Tokens.onAccent
                        : dim
                        ? Tokens.fgFaint
                        : Tokens.fgDim,
                  ),
                  const SizedBox(width: Tokens.s8),
                  Text(
                    m.label,
                    style: Tokens.label.copyWith(
                      fontWeight: FontWeight.w600,
                      color: advertised
                          ? Tokens.onAccent
                          : dim
                          ? Tokens.fgFaint
                          : Tokens.fg,
                    ),
                  ),
                  const SizedBox(width: Tokens.s8),
                  Icon(
                    advertised
                        ? Icons.check_rounded
                        : (unsupported
                              ? Icons.block_rounded
                              : Icons.add_rounded),
                    size: 16,
                    color: advertised
                        ? Tokens.onAccent
                        : dim
                        ? Tokens.fgFaint
                        : Tokens.fg,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dropdown of interruption policies.
class InterruptionDropdown extends StatelessWidget {
  const InterruptionDropdown({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final InterruptionPolicy value;
  final bool enabled;
  final ValueChanged<InterruptionPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppDropdown<InterruptionPolicy>(
      enabled: enabled,
      value: value,
      label: 'When interrupted',
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
        if (p != null) onChanged(p);
      },
    );
  }
}
