import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../studio/fx_bypass.dart';
import '../../studio/player_scope.dart';
import '../../ui/tokens.dart';
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
      bypass: PlayerScope.fxBypassOf(context),
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
  final FxBypass? bypass;

  /// How often the snapshot is sampled.
  final Duration interval;

  const EnginePanel({
    super.key,
    required this.player,
    this.bypass,
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
      s.prefetchState.listen((v) => _update(() {
            if (v != _prefetch) _prefetchHistory.add((t: _now, state: v));
            _prefetch = v;
          })),
      s.prefetchCacheDuration.listen((v) => _update(() => _prefetchCached = v)),
      s.waveform.listen((v) => _update(() => _waveform = v)),
      s.loudnessScan.listen((v) => _update(() => _scan = v)),
    ]);
    widget.bypass?.addListener(_onBypass);
    _sample();
    _timer = Timer.periodic(widget.interval, (_) => _update(_sample));
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
  }

  void _onBypass() => _update(() {});

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
    widget.bypass?.removeListener(_onBypass);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bypass = widget.bypass;
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
      bypassedChain: bypass != null && bypass.active ? bypass.savedChain : null,
    );

    final status = StatusView(snapshot: snap);
    final cache = CacheView(snapshot: snap);
    final prefetch = PrefetchView(snapshot: snap);
    final analysis = AnalysisView(snapshot: snap);
    final output = OutputView(snapshot: snap);
    final chain = ChainView(snapshot: snap);

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 960;
        const gap = SizedBox(height: Tokens.s12, width: Tokens.s12);
        final Widget body;
        if (wide) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [status, gap, cache, gap, prefetch],
                ),
              ),
              gap,
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [output, gap, analysis, gap, chain],
                ),
              ),
            ],
          );
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              status,
              gap,
              cache,
              gap,
              prefetch,
              gap,
              analysis,
              gap,
              output,
              gap,
              chain,
            ],
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            wide ? Tokens.s20 : Tokens.s12,
            Tokens.s16,
            wide ? Tokens.s20 : Tokens.s12,
            Tokens.s32,
          ),
          child: body,
        );
      },
    );
  }
}
