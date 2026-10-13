import 'package:flutter/material.dart';

import '../../../studio/player_scope.dart';
import '../../../ui/tokens.dart';
import '../../../util/reactive.dart';

/// Mute toggle + volume slider, bound to `player.stream.volume` and
/// `player.stream.mute`. Range tracks `volumeMax`. [axis] picks a
/// horizontal slider (default) or a vertical one (slim, fills its
/// parent's height — for a column beside the meters).
///
/// The slider is the app's flat house style ([_FlatSlider]): a squircle
/// pill track, an accent fill, and a squircle thumb — matching the
/// settings/effects sliders. Muting dims the fill and thumb instead of
/// disabling interaction, so you can still drag while muted.
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
    final player = PlayerScope.of(context);
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
              onTap: () => player.setMute(!muted),
            );
            final slider = _FlatSlider(
              value: value,
              max: max,
              axis: axis,
              enabled: !muted,
              onChanged: player.setVolume,
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
  static const double _cross = 24; // cross-axis extent (tap target)

  @override
  Widget build(BuildContext context) {
    final m = max <= 0 ? 1.0 : max;
    final frac = (value / m).clamp(0.0, 1.0);
    final fillColor = enabled ? Tokens.accent : Tokens.fgFaint;
    final thumbColor = enabled ? Tokens.fg : Tokens.fgFaint;

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
              height: _cross,
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
            width: _cross,
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

/// Flat speaker/mute toggle — a bare tappable icon (no Material ripple),
/// dimmed when muted, sized to sit cleanly in both layouts.
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
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(Tokens.s6),
          child: Icon(
            icon,
            size: 20,
            color: muted ? Tokens.fgFaint : Tokens.fgDim,
          ),
        ),
      ),
    );
  }
}
