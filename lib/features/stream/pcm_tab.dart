import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../audio/tone_generator.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/controls.dart';
import '../../ui/widgets/section_body.dart';
import '../../ui/widgets/state_pill.dart';
import 'stream_actions.dart';
import 'widgets/reference_list.dart';

/// A live PCM input as the Live PCM tab drives it: the part of a
/// [PcmSource] it uses, so a test can stand in for the engine.
abstract class LivePcm {
  /// Completes when the input can take more audio (see [PcmSource.ready]).
  Future<void> get ready;

  /// Queues a chunk of samples.
  void add(Uint8List chunk);

  /// Ends the input once the buffered audio has played.
  Future<void> close();

  /// Stops it at once.
  void abort();

  /// The audio waiting for the player.
  Duration get buffered;

  /// Whether the player is through with it (it stopped, or it drained).
  bool get isDone;
}

/// Opens a live input of [format] as the player's only entry.
typedef OpenLivePcm =
    Future<LivePcm> Function(
      PcmFormat format, {
      required bool lowLatency,
      required Map<String, Object?> extras,
    });

class _KitPcm implements LivePcm {
  _KitPcm(this._source);
  final PcmSource _source;

  @override
  Future<void> get ready => _source.ready;
  @override
  void add(Uint8List chunk) => _source.add(chunk);
  @override
  Future<void> close() => _source.close();
  @override
  void abort() => _source.abort();
  @override
  Duration get buffered => _source.buffered;
  @override
  bool get isDone => _source.isDone;
}

/// The Live PCM tab: test signals made in Dart and played as they are
/// made, through `openPcmStream`. Nothing is a file: the samples go to the
/// engine chunk by chunk, so the effects, the spectrum, the VU and the
/// loudness meter see a signal whose every value is known. Change the
/// signal while it plays: the next chunk follows within a quarter of a
/// second.
class PcmTab extends StatefulWidget {
  const PcmTab({super.key, required this.actions, this.open});

  final StreamActions actions;

  /// Opens the input; the player's `openPcmStream` by default.
  final OpenLivePcm? open;

  /// The format of the samples.
  static const PcmFormat format = PcmFormat(sampleRate: 48000, channels: 2);

  /// The audio made per chunk.
  static const Duration chunk = Duration(milliseconds: 20);

  /// How far ahead of the player the tab makes audio: changes are heard
  /// within it.
  static const Duration ahead = Duration(milliseconds: 250);

  @override
  State<PcmTab> createState() => _PcmTabState();
}

class _PcmTabState extends State<PcmTab> {
  final _generator = ToneGenerator(sampleRate: PcmTab.format.sampleRate);
  LivePcm? _source;
  bool _lowLatency = false;
  bool _starting = false;
  Timer? _refresh;

  PlayerApi get _player => widget.actions.player;

  Future<LivePcm> _open(
    PcmFormat format, {
    required bool lowLatency,
    required Map<String, Object?> extras,
  }) async => _KitPcm(
    await _player.openPcmStream(
      format,
      lowLatency: lowLatency,
      maxBuffered: PcmTab.ahead,
      extras: extras,
    ),
  );

  static String _hz(double hz) => hz >= 1000
      ? '${(hz / 1000).toStringAsFixed(hz >= 10000 ? 0 : 1)} kHz'
      : '${hz.round()} Hz';

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      final open = widget.open ?? _open;
      final source = await widget.actions.guard(
        () => open(
          PcmTab.format,
          lowLatency: _lowLatency,
          // The signal changes while it plays: the entry names the kind
          // of source, not the first signal.
          extras: {'title': 'Live PCM', 'artist': 'Test signal'},
        ),
      );
      if (source == null) return;
      if (!mounted) {
        // Gone while the input opened (on the web it waits for the
        // engine's module): nobody would feed it.
        source.abort();
        return;
      }
      setState(() => _source = source);
      // The buffered readout, while the tab is the one on screen.
      _refresh = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted && TickerMode.valuesOf(context).enabled) setState(() {});
      });
      unawaited(_feed(source));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Makes audio while [source] is the tab's and the player reads it,
  /// staying [PcmTab.ahead] in front of the player.
  Future<void> _feed(LivePcm source) async {
    while (identical(_source, source) && !source.isDone) {
      await source.ready;
      if (!identical(_source, source) || source.isDone) break;
      source.add(_generator.next(PcmTab.chunk));
    }
    if (identical(_source, source) && mounted) _stopped();
  }

  void _stopped() {
    _refresh?.cancel();
    setState(() => _source = null);
  }

  void _stop() {
    final source = _source;
    if (source == null) return;
    _source = null;
    source.abort();
    _stopped();
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _source?.abort();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = _source;
    final playing = source != null && !source.isDone;
    final g = _generator;
    final tone = g.kind == ToneKind.sine || g.kind == ToneKind.pulses;
    return StreamTabBody(
      children: [
        Text(
          'Samples made in Dart and played as they are made, through '
          'openPcmStream: no file, no URL. The effects and the meters see a '
          'signal whose every value is known.',
          style: Tokens.body.copyWith(color: Tokens.fgDim),
        ),
        const SizedBox(height: Tokens.s16),
        SettingsGroup(
          label: 'Signal',
          children: [
            SettingTile(
              title: 'Waveform',
              below: SegmentedControl<ToneKind>(
                options: [
                  for (final k in ToneKind.values) SegmentOption(k, k.label),
                ],
                selected: g.kind,
                onSelect: (k) => setState(() => g.kind = k),
              ),
            ),
            SliderRow(
              label: 'Frequency',
              value: g.frequency,
              min: 20,
              max: 20000,
              scale: SliderScale.log,
              resetTo: 440,
              format: _hz,
              enabled: tone,
              onChanged: (v) => setState(() => g.frequency = v),
            ),
            SliderRow(
              label: 'Level',
              value: g.levelDb,
              min: -48,
              max: 0,
              step: 1,
              resetTo: -12,
              format: (v) => '${v.round()} dBFS',
              onChanged: (v) => setState(() => g.levelDb = v),
            ),
            SwitchRow(
              label: 'Low latency',
              subtitle:
                  'A 100 ms output buffer instead of 200 ms; set when '
                  'the input opens',
              value: _lowLatency,
              enabled: !playing,
              onChanged: (v) => setState(() => _lowLatency = v),
            ),
          ],
        ),
        const SizedBox(height: Tokens.s16),
        Wrap(
          spacing: Tokens.s16,
          runSpacing: Tokens.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            playing
                ? FilledButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('Stop'),
                  )
                : FilledButton.icon(
                    onPressed: _starting ? null : _start,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play live'),
                  ),
            StatePill(
              !playing
                  ? 'Not playing'
                  : _player.state.playback.playing
                  ? 'Feeding the engine'
                  : 'Paused, the input waits',
              on: playing && _player.state.playback.playing,
              color: Tokens.green,
              tooltip: 'PcmSource',
            ),
            if (playing)
              Text(
                'Buffered ${source.buffered.inMilliseconds} ms',
                style: Tokens.numeric,
              ),
          ],
        ),
      ],
    );
  }
}
