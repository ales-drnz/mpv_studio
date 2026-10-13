import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../generated/filter_catalog.dart';
import '../../../ui/tokens.dart';
import '../engine_snapshot.dart';
import 'engine_parts.dart';

/// The effects chain as the engine runs it, read only: the stages switched
/// on, in order, between the decoder and the output.
class ChainView extends StatelessWidget {
  final EngineSnapshot snapshot;
  const ChainView({super.key, required this.snapshot});

  static final Map<AudioFilter, String> _titles = {
    for (final d in kFilterCatalog) d.filter: d.title,
  };

  /// A readable name for [stage]: the catalog title, else the lavfi name.
  static String nameOf(AudioEffect stage) =>
      _titles[stage.filter] ?? stage.filterName;

  @override
  Widget build(BuildContext context) {
    final bypassed = snapshot.bypassedChain;
    final chain = bypassed ?? snapshot.state.audioEffects;
    final active = [
      for (final e in chain)
        if (e.enabled) e,
    ];
    final off = chain.length - active.length;

    return EngineCard(
      title: 'Effects chain',
      caption: bypassed != null
          ? 'Bypassed: the audio plays dry until the bypass is released.'
          : (off > 0
                ? '$off more stage${off == 1 ? '' : 's'} switched off.'
                : null),
      trailing: bypassed != null
          ? StatePill('Bypass', color: Tokens.amber)
          : StatePill(
              '${active.length} active',
              color: Tokens.accent,
              strong: active.isNotEmpty,
            ),
      child: Opacity(
        opacity: bypassed != null ? 0.45 : 1,
        child: Wrap(
          spacing: Tokens.s4,
          runSpacing: Tokens.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const _End('decoder'),
            for (final (i, e) in active.indexed) ...[
              const _Arrow(),
              _Stage(index: i + 1, title: nameOf(e), wire: e.filterName),
            ],
            const _Arrow(),
            const _End('output'),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  final int index;
  final String title;
  final String wire;
  const _Stage({required this.index, required this.title, required this.wire});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: wire,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.s8,
          vertical: Tokens.s6,
        ),
        decoration: ShapeDecoration(
          color: Tokens.accentWash,
          shape: Tokens.squircle(Tokens.rSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$index',
              style: Tokens.numeric.copyWith(color: Tokens.accent),
            ),
            const SizedBox(width: Tokens.s6),
            Text(title, style: Tokens.body.copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class _End extends StatelessWidget {
  final String label;
  const _End(this.label);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Tokens.s8,
      vertical: Tokens.s6,
    ),
    decoration: ShapeDecoration(
      color: Tokens.surface2,
      shape: Tokens.squircle(Tokens.rSm),
    ),
    child: Text(label, style: Tokens.numeric),
  );
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.arrow_forward_rounded, size: 14, color: Tokens.fgFaint);
}
