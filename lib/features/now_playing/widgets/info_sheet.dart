import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mpv_audio_kit/mpv_audio_kit.dart';

import '../../../ui/layout/layout.dart';
import '../../../ui/tokens.dart';
import '../../../ui/widgets/section_header.dart';
import '../../../util/reactive.dart';
import '../playback_scope.dart';
import '../track_identity.dart';

/// Shows the read-only diagnostics of the current track and playback:
/// container, codec, bitrate, bit depth, channels, loudness, the output
/// format, the source paths and the timing. The signal facts are a grid
/// of small stat cells; paths and timing are dense key and value rows. A
/// bottom sheet on touch and phones, a dialog with a pointer.
Future<void> showInfoSheet(BuildContext context) {
  final scope = PlaybackScope.of(context);
  final body = _InfoBody(
    player: scope.player,
    loudnessSeed: scope.loudnessSeed?.call(),
  );
  if (context.layout.prefersSheets) {
    return showStudioSheet<void>(context, builder: (_) => body);
  }
  return showStudioDialog<void>(
    context,
    title: 'Track info',
    maxWidth: 560,
    builder: (_) => body,
    actions: (context) => [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ],
  );
}

class _InfoBody extends StatelessWidget {
  final PlayerApi player;
  final LoudnessScan? loudnessSeed;
  const _InfoBody({required this.player, this.loudnessSeed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Tokens.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: Tokens.s16),
            child: _identity(),
          ),
          _source(),
          // `stream.loudnessScan` replays the current result to every
          // listener, but only after the first frame, and `player.state`
          // has no loudness field: the seed fills that first frame.
          _loudness(loudnessSeed),
          _output(),
          _stream(),
          _playback(),
        ],
      ),
    );
  }

  // ── Header: title, artist and album ─────────────────────────────────

  Widget _identity() {
    return LiveTrackIdentity(
      player: player,
      builder: (context, id) {
        final sub = id.subtitle(separator: '  ·  ');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              id.displayTitle,
              style: Tokens.heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(
                sub,
                style: Tokens.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );
      },
    );
  }

  // ── Source signal: stat grid ───────────────────────────────────────

  Widget _source() {
    return Live<AudioParams>(
      stream: player.stream.audioParams,
      initial: player.state.audioParams,
      builder: (context, p) => Live<String>(
        stream: player.stream.fileFormat,
        initial: player.state.fileFormat,
        builder: (context, container) => Live<double?>(
          stream: player.stream.audioBitrate,
          initial: player.state.audioBitrate,
          builder: (context, bitrate) {
            // `file-format` is the protocol for adaptive streams (hls/dash);
            // the true segment container (fMP4) is something only the app
            // knows, passed through the queue item's extras.
            final segment = _currentExtra('segment');
            return _section(
              'Source',
              _statGrid([
                ('Container', _friendlyContainer(container)),
                if (segment != null) ('Segment', segment),
                ('Codec', _codec(p)),
                ('Bitrate', _bitrate(bitrate)),
                ('Sample rate', _sampleRate(p.sampleRate)),
                ('Bit depth', _bitDepth(p.format)),
                ('Channels', _channels(p)),
              ]),
            );
          },
        ),
      ),
    );
  }

  // ── Loudness (offline EBU R128 scan of the whole track) ─────────────

  Widget _loudness(LoudnessScan? initialScan) {
    return Live<LoudnessScan?>(
      stream: player.stream.loudnessScan,
      initial: initialScan,
      builder: (context, scan) {
        // Always render the section so the sheet height is stable: it used to
        // pop in only once the scan landed, reflowing the list mid-scroll.
        // Real values when ready, a placeholder until the measurement exists.
        final s = scan?.state == LoudnessScanState.ready ? scan : null;
        return _section(
          'Loudness (EBU R128)',
          _statGrid([
            (
              'Integrated',
              s?.integrated != null
                  ? '${s!.integrated!.toStringAsFixed(1)} LUFS'
                  : '-',
            ),
            (
              'Range',
              s?.range != null ? '${s!.range!.toStringAsFixed(1)} LU' : '-',
            ),
            ('True peak', s?.truePeak != null ? _peakDb(s!.truePeak!) : '-'),
            (
              'Sample peak',
              s?.samplePeak != null ? _peakDb(s!.samplePeak!) : '-',
            ),
          ]),
        );
      },
    );
  }

  String _peakDb(double linear) {
    if (linear <= 0) return '-';
    final db = 20 * math.log(linear) / math.ln10;
    return '${db.toStringAsFixed(1)} dBFS';
  }

  // ── Output (device side): stat grid ────────────────────────────────

  Widget _output() {
    return Live<AudioParams>(
      stream: player.stream.audioOutParams,
      initial: player.state.audioOutParams,
      builder: (context, p) => Live<double>(
        stream: player.stream.volumeGain,
        initial: player.state.volumeGain,
        builder: (context, gain) => _section(
          'Output',
          _statGrid([
            ('Format', _bitDepth(p.format)),
            ('Sample rate', _sampleRate(p.sampleRate)),
            ('Channels', _channels(p)),
            ('Gain', '${gain.toStringAsFixed(1)} dB'),
          ]),
        ),
      ),
    );
  }

  // ── Open pipeline: dense rows ──────────────────────────────────────

  Widget _stream() {
    return _section(
      'Stream',
      _card([
        _kvLive(
          player.stream.streamPath,
          player.state.streamPath,
          'Requested',
          _orDash,
        ),
        _kvLive(player.stream.path, player.state.path, 'Resolved', _orDash),
        _kvLive(
          player.stream.filename,
          player.state.filename,
          'Filename',
          _orDash,
        ),
        _kvLive<int>(
          player.stream.fileSize,
          player.state.fileSize,
          'Size',
          _bytes,
        ),
      ]),
    );
  }

  // ── Lifecycle and timing: dense rows ─────────────────────────────────

  Widget _playback() {
    return _section(
      'Playback',
      _card([
        StreamBuilder<MpvPlaybackState>(
          stream: player.stream.playbackState,
          builder: (c, s) =>
              _kv('State', (s.data ?? MpvPlaybackState.idle).name),
        ),
        _kvLive<Duration>(
          player.stream.audioPts,
          player.state.audioPts,
          'Position',
          _secs,
        ),
        _kvLive<Duration>(
          player.stream.timeRemaining,
          player.state.timeRemaining,
          'Remaining',
          _secs,
        ),
        _kvLive<bool>(
          player.stream.seekable,
          player.state.seekable,
          'Seekable',
          _yn,
        ),
        _kvLive<bool>(
          player.stream.partiallySeekable,
          player.state.partiallySeekable,
          'Partial seek',
          _yn,
        ),
        _kvLive<bool>(
          player.stream.eofReached,
          player.state.eofReached,
          'EOF',
          _yn,
        ),
      ]),
    );
  }

  // ── Building blocks ─────────────────────────────────────────────────

  Widget _section(String label, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: Tokens.s16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [SectionHeader(label), child],
    ),
  );

  /// Two-column grid of small stat cells.
  Widget _statGrid(List<(String, String)> stats) {
    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(
            bottom: i + 2 < stats.length ? Tokens.s6 : 0,
          ),
          child: Row(
            children: [
              Expanded(child: _StatCell(stats[i].$1, stats[i].$2)),
              const SizedBox(width: Tokens.s6),
              if (i + 1 < stats.length)
                Expanded(child: _StatCell(stats[i + 1].$1, stats[i + 1].$2))
              else
                const Spacer(),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  /// A flat card holding dense key/value rows.
  Widget _card(List<Widget> rows) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: Tokens.s12,
      vertical: Tokens.s4,
    ),
    decoration: ShapeDecoration(
      color: Tokens.surface2,
      shape: Tokens.shape(Tokens.rSm),
    ),
    child: Column(children: rows),
  );

  static Widget _kv(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label, style: Tokens.caption),
        const SizedBox(width: Tokens.s12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Tokens.numeric.copyWith(color: Tokens.fg),
          ),
        ),
      ],
    ),
  );

  static Widget _kvLive<T>(
    Stream<T> stream,
    T initial,
    String label,
    String Function(T) format,
  ) => Live<T>(
    stream: stream,
    initial: initial,
    builder: (c, v) => _kv(label, format(v)),
  );

  // ── Formatters ──────────────────────────────────────────────────────

  String? _currentExtra(String key) => currentExtra(player.state.playlist, key);

  /// Friendly label for mpv's `file-format` (the demuxer name). For
  /// adaptive streams this is the protocol (HLS/DASH); for direct files
  /// it's the real container.
  static String _friendlyContainer(String f) {
    if (f.isEmpty) return '-';
    final l = f.toLowerCase();
    if (l.startsWith('hls')) return 'HLS';
    if (l.startsWith('dash')) return 'DASH';
    if (l.contains('mov,mp4') || l == 'mp4' || l == 'm4a') return 'MP4';
    if (l.startsWith('matroska') || l.contains('webm')) return 'Matroska';
    if (l == 'ogg') return 'Ogg';
    if (l == 'flac') return 'FLAC';
    if (l == 'wav') return 'WAV';
    if (l == 'aac') return 'ADTS';
    if (l == 'mp3') return 'MP3';
    return f.split(',').first;
  }

  static String _orDash(String v) => v.isEmpty ? '-' : v;
  static String _yn(bool v) => v ? 'yes' : 'no';
  static String _secs(Duration d) =>
      '${(d.inMicroseconds / 1e6).toStringAsFixed(3)} s';
  static String _bitrate(double? v) =>
      v == null || v <= 0 ? '-' : '${(v / 1000).toStringAsFixed(0)} kbps';

  static String _bytes(int b) {
    if (b <= 0) return '-';
    final mib = b / (1024 * 1024);
    return mib >= 1 ? '${mib.toStringAsFixed(2)} MiB' : '$b B';
  }

  static String _sampleRate(int? hz) =>
      hz == null || hz <= 0 ? '-' : '${(hz / 1000).toStringAsFixed(1)} kHz';

  static String _codec(AudioParams p) {
    final c = p.codec ?? p.codecName;
    return (c == null || c.isEmpty) ? '-' : c;
  }

  static String _channels(AudioParams p) {
    if (p.hrChannels != null && p.hrChannels!.isNotEmpty) return p.hrChannels!;
    if (p.channelCount != null && p.channelCount! > 0) {
      return '${p.channelCount} ch';
    }
    return '-';
  }

  static String _bitDepth(Format? f) {
    switch (f) {
      case Format.u8:
      case Format.u8Planar:
        return '8-bit int';
      case Format.s16:
      case Format.s16Planar:
        return '16-bit int';
      case Format.s32:
      case Format.s32Planar:
        return '32-bit int';
      case Format.s64:
      case Format.s64Planar:
        return '64-bit int';
      case Format.float32:
      case Format.float32Planar:
        return '32-bit float';
      case Format.float64:
      case Format.float64Planar:
        return '64-bit float';
      case Format.auto:
      case null:
        return '-';
    }
  }
}

/// A small stat cell: dim label over a mono value, on a raised rounded.
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Tokens.s12,
        vertical: Tokens.s8,
      ),
      decoration: ShapeDecoration(
        color: Tokens.surface2,
        shape: Tokens.shape(Tokens.rSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Tokens.caption.copyWith(fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: Tokens.mono,
              fontSize: 13,
              color: Tokens.fg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
