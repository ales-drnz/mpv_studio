import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets/resize_handle.dart';
import 'widgets/cover_art.dart';
import 'widgets/spectrum_curve.dart';
import 'widgets/track_info.dart';
import 'widgets/transport_controls.dart';
import 'widgets/vu_meter.dart';
import 'widgets/volume_control.dart';
import 'widgets/waveform_meter.dart';

/// The home surface, laid out like a DAW: a full-bleed waveform meter
/// (Reaper-style ruler + playhead) on top — resizable — then a control
/// block (centred title over the transport, artwork left, vertical VU
/// meters right, volume) and finally the curved spectrum filling all the
/// remaining space, anchored to the bottom edge.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key});

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage> {
  double _meterHeight = 200;

  // Stable identity for the waveform meter so crossing the mobile/desktop
  // layout boundary REPARENTS its element (keeping the State and its waveform
  // subscription alive) instead of disposing and recreating it. A recreate
  // drops the stream's only listener, which restarts the native analysis and
  // wipes a progressive (streaming) waveform.
  final GlobalKey _waveformKey = GlobalKey();

  /// Below this surface width the controls stack into the mobile column.
  static const double _narrowBelow = 600;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // One width decision for the whole surface, so the meter sizing and
        // the control layout never disagree — an earlier split check let the
        // meter reserve row-space while the body rendered the taller column,
        // overflowing the bottom and crushing the visualizer to zero height.
        if (c.maxWidth < _narrowBelow) {
          // The meter is resizable on mobile too. The controls below adapt
          // (they scale down as one cluster — see [_MobileLayout]), so the
          // meter is free to take most of the surface; the bounds here are
          // just a usable floor and a "don't swallow everything" ceiling.
          final h = c.maxHeight;
          final w = c.maxWidth;
          final maxMeter = (h * 0.62).clamp(160.0, 520.0);
          final meterH = _meterHeight.clamp(110.0, maxMeter);
          final cover = math
              .min(w * 0.5, h * 0.26)
              .clamp(120.0, 200.0)
              .toDouble();
          return _MobileLayout(
            waveformKey: _waveformKey,
            meterHeight: meterH,
            coverSize: cover,
            onResize: (dy) => setState(
              () => _meterHeight = (meterH + dy).clamp(110.0, maxMeter),
            ),
          );
        }

        final maxMeter = (c.maxHeight - 320).clamp(120.0, 600.0);
        final meterH = _meterHeight.clamp(120.0, maxMeter);
        // Meter and the controls area touch flush; the resize line is
        // overlaid on the seam, so there are no gap pixels between them.
        return Stack(
          children: [
            Column(
              children: [
                SizedBox(
                  height: meterH,
                  child: ColoredBox(
                    color: Tokens.surface,
                    child: WaveformMeter(key: _waveformKey),
                  ),
                ),
                const Expanded(child: _RowBottom()),
              ],
            ),
            Positioned(
              top: meterH - 6,
              left: 0,
              right: 0,
              height: 12,
              child: ResizeHandle(
                axis: Axis.horizontal,
                hitThickness: 12,
                onDelta: (dy) => setState(
                  () => _meterHeight = (meterH + dy).clamp(120.0, maxMeter),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Desktop bottom: the control row over the full-bleed spectrum.
class _RowBottom extends StatelessWidget {
  const _RowBottom();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Control block — full width, no lateral cap.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            Tokens.s20,
            Tokens.s16,
            Tokens.s20,
            Tokens.s12,
          ),
          child: LayoutBuilder(
            builder: (context, c) => _RowControls(maxWidth: c.maxWidth),
          ),
        ),
        // Visualizer fills the rest, full-bleed, anchored to the bottom.
        const Expanded(child: SpectrumCurve()),
      ],
    );
  }
}

/// Mobile surface: a resizable meter up top, then the stacked controls over
/// the spectrum, which fills whatever height is left. The meter height is the
/// shared [_meterHeight] (drag the grip on its bottom seam); the artwork
/// scales with the available height, so the column always fits a portrait
/// viewport without overflowing — and the visualizer keeps a real, non-zero
/// height instead of being squeezed out.
class _MobileLayout extends StatelessWidget {
  final Key waveformKey;
  final double meterHeight;
  final double coverSize;
  final ValueChanged<double> onResize;
  const _MobileLayout({
    required this.waveformKey,
    required this.meterHeight,
    required this.coverSize,
    required this.onResize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            SizedBox(
              height: meterHeight,
              child: ColoredBox(
                color: Tokens.surface,
                child: WaveformMeter(key: waveformKey),
              ),
            ),
            Expanded(
              // The control block adapts to whatever height the meter leaves
              // it: at natural size when there's room, scaled down as a single
              // cluster (the [FittedBox]) once the meter is dragged large — so
              // the meter can grow freely without the fixed-height transport
              // ever overflowing. The visualizer keeps the remainder.
              child: LayoutBuilder(
                builder: (context, cc) {
                  final avail = cc.maxHeight;
                  const spectrumMin = 28.0;
                  // Approx. natural height of the stacked controls (cover plus
                  // the fixed transport/volume/VU rows and gaps). It only
                  // steers where scaling begins and the controls/visualizer
                  // split; FittedBox guarantees no overflow even if it's off.
                  final naturalControls = coverSize + 304;
                  final upper = math.max(0.0, avail - spectrumMin);
                  final controlsBudget = naturalControls.clamp(0.0, upper);
                  final spectrumH = avail - controlsBudget;
                  return Column(
                    children: [
                      SizedBox(
                        height: controlsBudget,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: cc.maxWidth,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                Tokens.s20,
                                Tokens.s16,
                                Tokens.s20,
                                Tokens.s12,
                              ),
                              child: _StackedControls(coverSize: coverSize),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: spectrumH, child: const SpectrumCurve()),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        // Resize grip on the meter's bottom seam — a tall band so it's an easy
        // touch target on a phone.
        Positioned(
          top: meterHeight - 11,
          left: 0,
          right: 0,
          height: 22,
          child: ResizeHandle(
            axis: Axis.horizontal,
            hitThickness: 22,
            onDelta: onResize,
          ),
        ),
      ],
    );
  }
}

/// Wide layout: artwork + info on the left, transport in the middle, the
/// volume and VU meters as slim vertical strips on the right.
class _RowControls extends StatelessWidget {
  final double maxWidth;
  const _RowControls({required this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final coverSize = (maxWidth * 0.14).clamp(120.0, 168.0).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: coverSize + 48,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CoverArtView(size: coverSize),
              const SizedBox(height: Tokens.s12),
              const TrackInfo(),
            ],
          ),
        ),
        const SizedBox(width: Tokens.s32),
        const Expanded(child: TransportControls()),
        const SizedBox(width: Tokens.s32),
        SizedBox(
          width: 40,
          height: coverSize,
          child: const VolumeControl(axis: Axis.vertical),
        ),
        const SizedBox(width: Tokens.s16),
        SizedBox(
          width: 44,
          height: coverSize,
          child: const VuMeter(axis: Axis.vertical),
        ),
      ],
    );
  }
}

/// Narrow (mobile) layout: everything stacks under the artwork in a
/// column — cover, title, the full-size transport, then the volume slider
/// and a horizontal VU meter — so the transport keeps its real size
/// instead of being squeezed into a sliver of a row.
class _StackedControls extends StatelessWidget {
  final double coverSize;
  const _StackedControls({required this.coverSize});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: CoverArtView(size: coverSize)),
        const SizedBox(height: Tokens.s12),
        const TrackInfo(),
        const SizedBox(height: Tokens.s16),
        const TransportControls(),
        const SizedBox(height: Tokens.s12),
        const VolumeControl(axis: Axis.horizontal),
        const SizedBox(height: Tokens.s8),
        const VuMeter(axis: Axis.horizontal),
      ],
    );
  }
}
