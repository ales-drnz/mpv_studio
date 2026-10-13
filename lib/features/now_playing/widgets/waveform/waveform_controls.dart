import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../ui/tokens.dart';
import '../../../../ui/widgets/round_icon_button.dart';

/// The zoom pill (out and in) over the waveform meter: two bare round
/// buttons on a field-tone pill, each a full tap target on touch.
class WaveformZoomControls extends StatelessWidget {
  const WaveformZoomControls({
    super.key,
    required this.canZoomIn,
    required this.canZoomOut,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final bool canZoomIn;
  final bool canZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(color: Tokens.surface3, shape: Tokens.pill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoundIconButton(
            icon: Icons.zoom_out_rounded,
            size: 20,
            tooltip: 'Zoom out',
            onTap: canZoomOut ? onZoomOut : null,
          ),
          RoundIconButton(
            icon: Icons.zoom_in_rounded,
            size: 20,
            tooltip: 'Zoom in',
            onTap: canZoomIn ? onZoomIn : null,
          ),
        ],
      ),
    );
  }
}

/// The progress of the audio scan (the waveform decode, which the loudness
/// scan rides) as a chip over the meter: determinate when the fraction is
/// known, indeterminate otherwise. Fades out when no scan runs; the percent
/// has a fixed width so the chip never jitters.
class WaveformScanIndicator extends StatelessWidget {
  const WaveformScanIndicator({
    super.key,
    required this.visible,
    this.fraction,
  });

  final bool visible;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final f = visible ? fraction : 0.0;
    final bar = f == null
        ? LinearProgressIndicator(
            minHeight: 4,
            color: Tokens.accent,
            backgroundColor: Tokens.surface4,
          )
        : TweenAnimationBuilder<double>(
            tween: Tween(end: f.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 4,
              color: Tokens.accent,
              backgroundColor: Tokens.surface4,
            ),
          );
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Tokens.s12,
            vertical: Tokens.s4,
          ),
          decoration: ShapeDecoration(
            color: Tokens.surface3,
            shape: Tokens.pill,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Scanning audio', style: Tokens.caption),
              const SizedBox(width: Tokens.s8),
              SizedBox(
                width: 60,
                child: ClipPath(
                  clipper: const ShapeBorderClipper(shape: StadiumBorder()),
                  child: visible ? bar : null,
                ),
              ),
              if (f != null) ...[
                const SizedBox(width: Tokens.s8),
                SizedBox(
                  width: 38,
                  child: Text(
                    '${(f * 100).round()}%',
                    style: Tokens.numeric,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The horizontal scrollbar under the meter: a strip [height] tall (the
/// hit area) whose pill thumb, [thickness] thick and centred in it, is
/// the visible part of the timeline. Tap or drag to move the view; the
/// thumb lights up in the accent on hover.
class WaveformScrollBar extends StatefulWidget {
  const WaveformScrollBar({
    super.key,
    required this.enabled,
    required this.viewStart,
    required this.visibleSecs,
    required this.maxStart,
    required this.timelineSecs,
    required this.onChanged,
    required this.height,
    this.thickness = 8,
  });

  final bool enabled;
  final double viewStart;
  final double visibleSecs;
  final double maxStart;
  final double timelineSecs;
  final ValueChanged<double> onChanged;
  final double height;

  /// The thumb's thickness, at most [height].
  final double thickness;

  @override
  State<WaveformScrollBar> createState() => _WaveformScrollBarState();
}

class _WaveformScrollBarState extends State<WaveformScrollBar> {
  bool _hoverThumb = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final frac =
              (widget.timelineSecs <= 0
                      ? 1.0
                      : widget.visibleSecs / widget.timelineSecs)
                  .clamp(0.06, 1.0);
          // A strip narrower than the thumb's minimum gets a full-width thumb.
          final thumbW = (w * frac).clamp(math.min(28.0, w), w).toDouble();
          final avail = w - thumbW;
          final thumbX = widget.maxStart > 0
              ? (widget.viewStart / widget.maxStart) * avail
              : 0.0;

          void setFromX(double x) {
            if (!widget.enabled || avail <= 0) return;
            final tx = (x - thumbW / 2).clamp(0.0, avail);
            widget.onChanged((tx / avail) * widget.maxStart);
          }

          final thumbColour = !widget.enabled
              ? Tokens.surface3
              : _hoverThumb
              ? Tokens.accent
              : Tokens.surface4;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => setFromX(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => setFromX(d.localPosition.dx),
            child: Padding(
              padding: EdgeInsets.symmetric(
                vertical: math.max(0, widget.height - widget.thickness) / 2,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: thumbX,
                    top: 0,
                    bottom: 0,
                    width: thumbW,
                    child: MouseRegion(
                      cursor: widget.enabled
                          ? SystemMouseCursors.click
                          : MouseCursor.defer,
                      onEnter: widget.enabled
                          ? (_) => setState(() => _hoverThumb = true)
                          : null,
                      onExit: (_) => setState(() => _hoverThumb = false),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: thumbColour,
                          shape: Tokens.pill,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
