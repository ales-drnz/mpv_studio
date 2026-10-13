import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../../../ui/widgets/controls.dart';
import '../../../ui/widgets/round_icon_button.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';
import '../transport_actions.dart';

/// Mute toggle and volume slider, bound to `player.stream.volume` and
/// `player.stream.mute`. Range tracks `volumeMax`. [axis] picks a
/// horizontal slider (default) or a vertical one (slim, fills its
/// parent's height, for a column beside the meters).
///
/// The slider is the app's [AppSlider] (turned upright for the vertical
/// axis). Muting fades it instead of disabling it, so you can still drag
/// while muted; the mute circle takes the secondary selection fill. The
/// calls run through the page's guard.
class VolumeControl extends StatelessWidget {
  final Axis axis;
  const VolumeControl({super.key, this.axis = Axis.horizontal});

  IconData _icon(bool muted, double vol, double max) => muted
      ? Icons.volume_off_rounded
      : vol <= 0
      ? Icons.volume_mute_rounded
      : vol < max * 0.5
      ? Icons.volume_down_rounded
      : Icons.volume_up_rounded;

  @override
  Widget build(BuildContext context) {
    final scope = PlaybackScope.of(context);
    final player = scope.player;
    final guard = scope.guard;
    return Live<bool>(
      stream: player.stream.mute,
      initial: player.state.mute,
      builder: (context, muted) => Live<double>(
        stream: player.stream.volumeMax,
        initial: player.state.volumeMax,
        builder: (context, vmax) => Live<double>(
          stream: player.stream.volume,
          initial: player.state.volume,
          builder: (context, vol) {
            final max = vmax < 100 ? 100.0 : vmax;
            final value = vol.clamp(0.0, max).toDouble();
            final readout = Text(
              vol.round().toString(),
              style: Tokens.numeric.copyWith(
                color: muted ? Tokens.fgFaint : Tokens.fgDim,
              ),
              textAlign: TextAlign.end,
            );
            final muteButton = RoundIconButton(
              icon: _icon(muted, vol, max),
              size: 20,
              tooltip: muted ? 'Unmute' : 'Mute',
              label: 'Mute',
              toggled: muted,
              active: muted,
              onTap: () => guard(() => player.setMute(!muted)),
            );
            Widget slider = Opacity(
              opacity: muted ? 0.45 : 1,
              child: AppSlider(
                value: value,
                min: 0,
                max: max,
                onChanged: (v) => guard(() => player.setVolume(v)),
              ),
            );
            if (axis == Axis.vertical) {
              slider = RotatedBox(quarterTurns: 3, child: slider);
            }
            slider = Semantics(
              slider: true,
              label: 'Volume',
              value: muted
                  ? '${vol.round()} percent, muted'
                  : '${vol.round()} percent',
              increasedValue: '${(vol + 5).clamp(0, max).round()} percent',
              decreasedValue: '${(vol - 5).clamp(0, max).round()} percent',
              onIncrease: () => stepVolume(player, guard, 5),
              onDecrease: () => stepVolume(player, guard, -5),
              excludeSemantics: true,
              child: slider,
            );

            if (axis == Axis.vertical) {
              return Column(
                children: [
                  readout,
                  const SizedBox(height: Tokens.s8),
                  Expanded(child: Center(child: slider)),
                  const SizedBox(height: Tokens.s8),
                  muteButton,
                ],
              );
            }
            return Row(
              children: [
                muteButton,
                const SizedBox(width: Tokens.s8),
                Expanded(child: slider),
                const SizedBox(width: Tokens.s12),
                SizedBox(width: 32, child: readout),
              ],
            );
          },
        ),
      ),
    );
  }
}
