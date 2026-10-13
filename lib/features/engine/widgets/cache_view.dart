import 'package:flutter/material.dart';

import '../../../ui/tokens.dart';
import '../engine_format.dart';
import '../engine_snapshot.dart';
import 'cache_painters.dart';
import 'engine_parts.dart';

/// The demuxer cache, drawn like the `demuxer_cache` diagram: the part read
/// so far around the playhead (behind and ahead), the cache-secs limit,
/// and below it how much was cached ahead over the last minute, with the
/// stretches where playback paused for an empty cache.
class CacheView extends StatelessWidget {
  final EngineSnapshot snapshot;
  const CacheView({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final s = snapshot.state;
    final cache = s.demuxerCacheState;
    final geometry = CacheGeometry.of(s);
    final local = cache.seekableRanges.isEmpty && !s.demuxerViaNetwork;
    final pauseOn = s.cache.pause;
    final flags = [
      if (cache.bofCached) 'start cached',
      if (cache.eofCached) 'end cached',
      if (cache.underrun) 'underrun',
    ];

    return EngineCard(
      title: 'Cache',
      caption: local
          ? 'Local source: the demuxer reads the file directly.'
          : 'What the demuxer holds around the playhead.',
      trailing: s.pausedForCache
          ? StatePill('Paused for cache', color: Tokens.amber)
          : StatePill(
              s.demuxerViaNetwork ? 'Network' : 'Local',
              color: Tokens.accent,
              strong: s.demuxerViaNetwork,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                'Cache: ${EngineFormat.seconds(geometry.behind)} behind '
                'and ${EngineFormat.seconds(geometry.ahead)} ahead of the '
                'playhead',
            excludeSemantics: true,
            child: SizedBox(
              height: 112,
              child: CustomPaint(
                painter: CacheBarPainter(
                  geometry: geometry,
                  waveform: snapshot.waveform,
                ),
              ),
            ),
          ),
          const SizedBox(height: Tokens.s12),
          ReadoutGrid(
            children: [
              Readout('Cached ahead', EngineFormat.seconds(s.bufferDuration)),
              Readout('Buffered to', EngineFormat.seconds(s.buffer)),
              Readout('Behind', EngineFormat.seconds(geometry.behind)),
              Readout('Speed', EngineFormat.rate(s.cacheSpeed)),
              Readout(
                'Cache secs',
                geometry.cacheSecs == null
                    ? 'unbounded'
                    : EngineFormat.seconds(geometry.cacheSecs!),
              ),
              Readout(
                'Flags',
                flags.isEmpty ? 'none' : flags.join(', '),
                color: cache.underrun ? Tokens.amber : null,
              ),
            ],
          ),
          const SizedBox(height: Tokens.s16),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: Tokens.s8,
            children: [
              Text('Cached ahead, last minute', style: Tokens.caption),
              Text(
                pauseOn
                    ? 'pause on, resumes at '
                          '${EngineFormat.seconds(s.cache.pauseWait)}'
                    : 'pause off',
                style: Tokens.caption,
              ),
            ],
          ),
          const SizedBox(height: Tokens.s6),
          Semantics(
            label: 'Cached ahead over the last minute',
            value: EngineFormat.seconds(s.bufferDuration),
            excludeSemantics: true,
            child: SizedBox(
              height: 72,
              child: CustomPaint(
                painter: CacheHistoryPainter(
                  samples: snapshot.cacheHistory,
                  now: snapshot.now,
                  pauseWait: pauseOn ? secondsOf(s.cache.pauseWait) : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
