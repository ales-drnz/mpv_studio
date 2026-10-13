import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../effects/rack_controller.dart';
import '../../studio/player_scope.dart';
import '../../ui/layout/layout.dart';
import 'engine_snapshot.dart';
import 'widgets/analysis_view.dart';
import 'widgets/cache_view.dart';
import 'widgets/chain_view.dart';
import 'widgets/output_view.dart';
import 'widgets/prefetch_view.dart';
import 'widgets/status_view.dart';

/// The Engine section. Builds the live [EnginePanel] only while the
/// section is on screen: the sections stay mounted in the shell's
/// IndexedStack, and the panel's subscriptions (the loudness scan among
/// them) should not run in the background.
class EnginePage extends StatelessWidget {
  const EnginePage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Visibility.of(context)) return const SizedBox.shrink();
    return EnginePanel(
      player: PlayerScope.of(context),
      rack: PlayerScope.rackOf(context),
    );
  }
}

/// A live diagnostic view of the engine: playback state, cache, prefetch,
/// analysis, audio output and the effects chain.
///
/// The player's snapshot is sampled a few times a second (it also feeds
/// the history charts); the streams with no snapshot counterpart
/// (`playbackState`, `prefetchState`, `prefetchCacheDuration`, `waveform`,
/// `loudnessScan`) are followed directly.
class EnginePanel extends StatefulWidget {
  final PlayerApi player;

  /// The effects rack: while its bypass is on, the chain view shows the
  /// user's chain rather than the muted copy the engine plays.
  final RackController? rack;

  /// How often the snapshot is sampled.
  final Duration interval;

  const EnginePanel({
    super.key,
    required this.player,
    this.rack,
    this.interval = const Duration(milliseconds: 200),
  });

  @override
  State<EnginePanel> createState() => _EnginePanelState();
}

class _EnginePanelState extends State<EnginePanel> {
  final Stopwatch _clock = Stopwatch()..start();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _timer;

  MpvPlaybackState _playbackState = MpvPlaybackState.idle;
  PrefetchState _prefetch = PrefetchState.idle;
  Duration _prefetchCached = Duration.zero;
  WaveformData? _waveform;
  LoudnessScan? _scan;
  final List<CacheSample> _cacheHistory = [];
  final List<PrefetchMark> _prefetchHistory = [];

  double get _now => _clock.elapsedMicroseconds / 1e6;

  @override
  void initState() {
    super.initState();
    final s = widget.player.stream;
    _prefetchHistory.add((t: 0, state: _prefetch));
    _subs.addAll([
      s.playbackState.listen((v) => _update(() => _playbackState = v)),
      s.prefetchState.listen(
        (v) => _update(() {
          if (v != _prefetch) _prefetchHistory.add((t: _now, state: v));
          _prefetch = v;
        }),
      ),
      s.prefetchCacheDuration.listen((v) => _update(() => _prefetchCached = v)),
      s.waveform.listen((v) => _update(() => _waveform = v)),
      s.loudnessScan.listen((v) => _update(() => _scan = v)),
    ]);
    widget.rack?.addListener(_onRack);
    _sample();
    _timer = Timer.periodic(widget.interval, (_) => _update(_sample));
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  void _onRack() => _update(() {});

  void _sample() {
    final st = widget.player.state;
    final now = _now;
    _cacheHistory.add((
      t: now,
      ahead: secondsOf(st.bufferDuration),
      paused: st.pausedForCache,
    ));
    _cacheHistory.removeWhere((c) => c.t < now - 65);
    // Keep the last mark before the window so the first band starts at
    // the window's edge.
    while (_prefetchHistory.length > 1 && _prefetchHistory[1].t < now - 125) {
      _prefetchHistory.removeAt(0);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    widget.rack?.removeListener(_onRack);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rack = widget.rack;
    final snap = EngineSnapshot(
      state: widget.player.state,
      playbackState: _playbackState,
      prefetchState: _prefetch,
      prefetchCacheDuration: _prefetchCached,
      waveform: _waveform,
      loudnessScan: _scan,
      cacheHistory: List.unmodifiable(_cacheHistory),
      prefetchHistory: List.unmodifiable(_prefetchHistory),
      now: _now,
      bypassedChain: rack != null && rack.bypass ? rack.chain.effects : null,
    );

    final status = StatusView(snapshot: snap);
    final cache = CacheView(snapshot: snap);
    final prefetch = PrefetchView(snapshot: snap);
    final analysis = AnalysisView(snapshot: snap);
    final output = OutputView(snapshot: snap);
    final chain = ChainView(snapshot: snap);

    final layout = context.layout;
    return PageFrame(
      title: 'Engine',
      maxWidth: Breakpoints.wide,
      body: LayoutBuilder(
        builder: (context, c) {
          // One column on phones, two up to desktop, three on big screens;
          // never narrower than a card reads well.
          final wanted = switch (layout.width) {
            WidthClass.compact => 1,
            WidthClass.xlarge => 3,
            _ => 2,
          };
          final columns = math.min(
            wanted,
            ResponsiveGrid.columnsFor(
              c.maxWidth,
              minTileWidth: _minCardWidth,
              spacing: layout.gap,
            ),
          );
          // Cards of unequal height stack per column, balanced by hand so
          // the columns end near each other.
          final List<List<Widget>> split = switch (columns) {
            1 => [
              [status, cache, prefetch, analysis, output, chain],
            ],
            2 => [
              [status, cache, prefetch],
              [output, analysis, chain],
            ],
            _ => [
              [status, output],
              [cache, chain],
              [analysis, prefetch],
            ],
          };
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, cards) in split.indexed) ...[
                if (i > 0) SizedBox(width: layout.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (k, card) in cards.indexed) ...[
                        if (k > 0) SizedBox(height: layout.gap),
                        card,
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The narrowest an Engine card reads well.
const double _minCardWidth = 300;
