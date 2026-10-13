import 'dart:async';

import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';

/// Double tap on the left half of [child] to go back [step], on the right
/// half to go forward, like a phone video player. A short "10 s" badge
/// flashes on the side that was tapped. [onSeek] gets the signed offset.
class DoubleTapSeek extends StatefulWidget {
  const DoubleTapSeek({
    super.key,
    required this.onSeek,
    required this.child,
    this.step = const Duration(seconds: 10),
    this.enabled = true,
  });

  final ValueChanged<Duration> onSeek;
  final Duration step;
  final bool enabled;
  final Widget child;

  @override
  State<DoubleTapSeek> createState() => _DoubleTapSeekState();
}

class _DoubleTapSeekState extends State<DoubleTapSeek> {
  bool _forward = true;

  /// The side of the last double tap while its badge shows.
  bool? _flash;
  Timer? _hide;

  void _seek() {
    widget.onSeek(_forward ? widget.step : -widget.step);
    _hide?.cancel();
    setState(() => _flash = _forward);
    _hide = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  void dispose() {
    _hide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final flash = _flash;
    return LayoutBuilder(
      builder: (context, c) => GestureDetector(
        onDoubleTapDown: (d) => _forward = d.localPosition.dx >= c.maxWidth / 2,
        onDoubleTap: _seek,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (flash != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: flash
                        ? const Alignment(0.7, 0)
                        : const Alignment(-0.7, 0),
                    child: _Badge(
                      forward: flash,
                      seconds: widget.step.inSeconds,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.forward, required this.seconds});

  final bool forward;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.s12,
        vertical: Tokens.s6,
      ),
      decoration: ShapeDecoration(
        color: Tokens.surface3.withValues(alpha: 0.92),
        shape: Tokens.shape(Tokens.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            size: 18,
            color: Tokens.fg,
          ),
          const SizedBox(width: Tokens.s4),
          Text('$seconds s', style: Tokens.label.copyWith(color: Tokens.fg)),
        ],
      ),
    );
  }
}
