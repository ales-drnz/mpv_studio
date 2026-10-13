import 'package:flutter/material.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';
import '../transport_actions.dart';

/// Mute toggle + volume slider, bound to `player.stream.volume` and
/// `player.stream.mute`. Range tracks `volumeMax`. [axis] picks a
/// horizontal slider (default) or a vertical one (slim, fills its
/// parent's height — for a column beside the meters).
///
/// The slider is the app's flat house style ([_FlatSlider]): a squircle
/// pill track, an accent fill, and a squircle thumb — matching the
/// settings/effects sliders. Muting dims the fill and thumb instead of
/// disabling interaction, so you can still drag while muted. The calls run
/// through the page's guard.
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
            final value = vol.clamp(0.0, max);
            final readout = Text(
              vol.round().toString(),
              style: Tokens.numeric.copyWith(
                color: muted ? Tokens.fgFaint : Tokens.fgDim,
              ),
              textAlign: TextAlign.end,
            );
            final muteButton = _MuteButton(
              icon: _icon(muted, vol, max),
              muted: muted,
              onTap: () => guard(() => player.setMute(!muted)),
            );
            final slider = Semantics(
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
              child: _FlatSlider(
                value: value,
                max: max,
                axis: axis,
                enabled: !muted,
                onChanged: (v) => guard(() => player.setVolume(v)),
              ),
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
                const SizedBox(width: Tokens.s8),
                SizedBox(width: 32, child: readout),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A flat slider — squircle pill track, accent fill, squircle thumb — that
/// works horizontally or vertically. Tap or drag to set; reports through
/// [onChanged]. Mirrors the look of `AppSlider`; [enabled] = false dims it
/// (used for the muted state) without blocking the gesture.
class _FlatSlider extends StatelessWidget {
  final double value;
  final double max;
  final Axis axis;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _FlatSlider({
    required this.value,
    required this.max,
    required this.axis,
    required this.onChanged,
    this.enabled = true,
  });

  static const double _thumb = 16;
  static const double _track = 6;

  @override
  Widget build(BuildContext context) {
    final m = max <= 0 ? 1.0 : max;
    final frac = (value / m).clamp(0.0, 1.0);
    final fillColor = enabled ? Tokens.accent : Tokens.fgFaint;
    final thumbColor = enabled ? Tokens.fg : Tokens.fgFaint;
    // The cross-axis extent is the tap target.
    final cross = context.layout.isTouch ? context.layout.minTap : 24.0;

    final emptyShape = ShapeDecoration(
      color: Tokens.surface3,
      shape: Tokens.squircle(Tokens.rPill),
    );
    final fillShape = ShapeDecoration(
      color: fillColor,
      shape: Tokens.squircle(Tokens.rPill),
    );
    final thumb = Container(
      width: _thumb,
      height: _thumb,
      decoration: ShapeDecoration(color: thumbColor, shape: Tokens.squircle(8)),
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (axis == Axis.horizontal) {
          final span = (c.maxWidth - _thumb).clamp(1.0, double.infinity);
          double valueAt(double dx) =>
              (((dx - _thumb / 2) / span).clamp(0.0, 1.0)) * m;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onChanged(valueAt(d.localPosition.dx)),
            onHorizontalDragUpdate: (d) =>
                onChanged(valueAt(d.localPosition.dx)),
            child: SizedBox(
              height: cross,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // Container with only the cross-axis size set fills the
                  // main axis (the long dimension).
                  Container(height: _track, decoration: emptyShape),
                  Container(
                    width: _thumb / 2 + frac * span,
                    height: _track,
                    decoration: fillShape,
                  ),
                  Positioned(left: frac * span, child: thumb),
                ],
              ),
            ),
          );
        }
        // Vertical: 0 at the bottom, max at the top.
        final span = (c.maxHeight - _thumb).clamp(1.0, double.infinity);
        double valueAt(double dy) =>
            (1 - (((dy - _thumb / 2) / span).clamp(0.0, 1.0))) * m;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => onChanged(valueAt(d.localPosition.dy)),
          onVerticalDragUpdate: (d) => onChanged(valueAt(d.localPosition.dy)),
          child: SizedBox(
            width: cross,
            height: double.infinity,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(width: _track, decoration: emptyShape),
                Container(
                  width: _track,
                  height: _thumb / 2 + frac * span,
                  decoration: fillShape,
                ),
                Positioned(bottom: frac * span, child: thumb),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The speaker and mute toggle: an icon dimmed when muted, a full tap
/// target on touch.
class _MuteButton extends StatelessWidget {
  final IconData icon;
  final bool muted;
  final VoidCallback onTap;

  const _MuteButton({
    required this.icon,
    required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = muted ? 'Unmute' : 'Mute';
    final minTap = context.layout.minTap;
    return Semantics(
      button: true,
      toggled: muted,
      label: 'Mute',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: minTap, minHeight: minTap),
              child: Icon(
                icon,
                size: 20,
                color: muted ? Tokens.fgFaint : Tokens.fgDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
